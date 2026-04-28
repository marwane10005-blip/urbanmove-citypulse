from __future__ import annotations

import asyncio
import json
import os
import signal
from dataclasses import dataclass, field

import structlog
from prometheus_client import Counter, Gauge, start_http_server

from worker.kinesis_client import ShardLoop

log = structlog.get_logger(__name__)

SERVICE_NAME = "stream-processor"
BUILD_SHA = os.environ.get("BUILD_SHA", "dev")
STREAM_NAME = os.environ.get("KINESIS_STREAM", "urbanmove-dev-vehicle-telemetry-v1")
METRICS_PORT = int(os.environ.get("METRICS_PORT", "9090"))
REDIS_URL = os.environ.get("REDIS_URL")
DATABASE_URL = (
    os.environ.get("DATABASE_URL")
    or os.environ.get("DB_HOST") and "assemble-from-secret"
)
CONGESTION_SPEED_KMH = float(os.environ.get("CONGESTION_SPEED_KMH", "10"))

events_total = Counter(
    "stream_processor_events_total",
    "Events consumed from the Kinesis stream.",
    ["status"],
)
congestion_emitted_total = Counter(
    "stream_processor_congestion_emitted_total",
    "Congestion events emitted downstream.",
    ["zone"],
)
iterator_age_ms = Gauge(
    "stream_processor_iterator_age_ms_max",
    "Oldest unprocessed record age (ms) — max across shards.",
)

@dataclass
class ZoneBucket:

    speeds: list[float] = field(default_factory=list)
    ts: list[float] = field(default_factory=list)

    def add(self, speed_kmh: float, ts: float) -> None:
        self.speeds.append(speed_kmh)
        self.ts.append(ts)
        self._evict(ts - 60.0)

    def _evict(self, cutoff: float) -> None:
        while self.ts and self.ts[0] < cutoff:
            self.ts.pop(0)
            self.speeds.pop(0)

    def avg_speed(self) -> float | None:
        return sum(self.speeds) / len(self.speeds) if self.speeds else None

_zones: dict[str, ZoneBucket] = {}

def _zone_for(lat: float, lon: float) -> str:

    zlat = round(lat / 0.005) * 0.005
    zlon = round(lon / 0.005) * 0.005
    return f"grid:{zlat:.3f},{zlon:.3f}"

_last_alert_ts: dict[str, float] = {}
_ALERT_COOLDOWN_SEC = 300

DEFAULT_FLEET_ID = os.environ.get("DEFAULT_FLEET_ID", "paris-demo")

UPSERT_SQL = """
    INSERT INTO vehicles (vehicle_id, fleet_id, model, current_position,
                          current_speed_kmh, battery_pct, last_seen)
    VALUES (%(vid)s, %(fleet)s, %(model)s,
            ST_SetSRID(ST_MakePoint(%(lon)s, %(lat)s), 4326),
            %(speed)s, %(bat)s, to_timestamp(%(ts)s))
    ON CONFLICT (vehicle_id) DO UPDATE SET
        current_position  = EXCLUDED.current_position,
        current_speed_kmh = EXCLUDED.current_speed_kmh,
        battery_pct       = EXCLUDED.battery_pct,
        last_seen         = EXCLUDED.last_seen
"""

def process_record_sync(record: dict, redis_client=None, db_conn=None, kinesis_client=None) -> None:

    vehicle_id = record.get("vehicle_id", "unknown")
    lat = record.get("lat")
    lon = record.get("lon")
    speed = record.get("speed_kmh")
    bat = record.get("battery_pct")
    ts = record.get("ts", 0.0)

    if lat is None or lon is None or speed is None:
        events_total.labels(status="skipped").inc()
        return

    if db_conn is not None:
        try:
            with db_conn.cursor() as cur:
                cur.execute(UPSERT_SQL, {
                    "vid":   vehicle_id,
                    "fleet": DEFAULT_FLEET_ID,
                    "model": "simulator-v1",
                    "lat":   lat,
                    "lon":   lon,
                    "speed": speed,
                    "bat":   bat,
                    "ts":    ts,
                })
            db_conn.commit()
        except Exception as exc:
            log.warning("aurora_upsert_failed", vehicle=vehicle_id, error=str(exc))
            try:
                db_conn.rollback()
            except Exception as rollback_exc:
                log.warning("aurora_rollback_failed", error=str(rollback_exc))

    if redis_client is not None:
        try:
            redis_client.setex(
                f"vehicle:{vehicle_id}:position",
                300,
                json.dumps({"lat": lat, "lon": lon, "speed_kmh": speed, "ts": ts}),
            )
        except Exception as exc:
            log.warning("redis_setex_failed", vehicle=vehicle_id, error=str(exc))

    zone_id = _zone_for(lat, lon)
    bucket = _zones.setdefault(zone_id, ZoneBucket())
    bucket.add(speed, ts)

    avg = bucket.avg_speed()
    if (
        avg is not None
        and len(bucket.speeds) >= 5
        and avg < CONGESTION_SPEED_KMH
        and (ts - _last_alert_ts.get(zone_id, 0.0)) >= _ALERT_COOLDOWN_SEC
    ):
        _last_alert_ts[zone_id] = ts
        congestion_emitted_total.labels(zone=zone_id).inc()
        log.info(
            "congestion_detected",
            zone=zone_id,
            avg_kmh=round(avg, 1),
            samples=len(bucket.speeds),
        )
        if kinesis_client is not None:
            try:
                kinesis_client.put_record(
                    StreamName=STREAM_NAME,
                    Data=json.dumps(
                        {
                            "type": "congestion",
                            "zone": zone_id,
                            "avg_speed_kmh": round(avg, 1),
                            "vehicles_in_zone": len(bucket.speeds),
                            "severity": min(5, 1 + int((CONGESTION_SPEED_KMH - avg) / 2)),
                            "ts": ts,
                        }
                    ).encode("utf-8"),
                    PartitionKey=zone_id,
                )
            except Exception as exc:
                log.exception("congestion_publish_failed", zone=zone_id, error=str(exc))

    events_total.labels(status="ok").inc()

_stop_event: asyncio.Event | None = None

def _install_signal_handlers(stop: asyncio.Event) -> None:
    def _on_signal(signum, _frame):
        log.info("shutdown_signal", signum=signum)
        stop.set()

    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)

def _build_kinesis_client():
    try:
        import boto3
        return boto3.client("kinesis", region_name=os.environ.get("AWS_REGION", "eu-west-3"))
    except Exception as exc:
        log.warning("kinesis_client_init_failed", error=str(exc))
        return None

def _build_db_conn():

    try:
        import boto3
        import psycopg2

        host = os.environ.get("DB_HOST")
        port = os.environ.get("DB_PORT", "5432")
        db = os.environ.get("DB_NAME", "urbanmove")
        secret_id = os.environ.get("DB_SECRET_ID")
        if not (host and secret_id):
            log.warning("aurora_env_missing")
            return None

        sm = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION", "eu-west-3"))
        blob = json.loads(sm.get_secret_value(SecretId=secret_id)["SecretString"])
        conn = psycopg2.connect(
            host=host, port=port, dbname=db,
            user=blob["username"], password=blob["password"],
            connect_timeout=10,
        )
        conn.autocommit = False
        log.info("aurora_connected", host=host)
        return conn
    except Exception as exc:
        log.warning("aurora_init_failed", error=str(exc))
        return None

def _build_redis():

    url = os.environ.get("REDIS_URL")
    if not url or url.endswith("<not-set>:6379"):
        log.warning("redis_env_missing")
        return None
    try:
        import redis as redis_lib
        client = redis_lib.from_url(
            url,
            socket_timeout=3,
            socket_connect_timeout=3,
            decode_responses=True,
            ssl_cert_reqs=None if url.startswith("rediss://") else "required",
        )
        client.ping()
        log.info("redis_connected", url=url.split("@")[-1])
        return client
    except Exception as exc:
        log.warning("redis_init_failed", error=str(exc))
        return None

async def run() -> None:
    global _stop_event
    _stop_event = asyncio.Event()
    _install_signal_handlers(_stop_event)

    start_http_server(METRICS_PORT)
    log.info("started", service=SERVICE_NAME, build=BUILD_SHA, stream=STREAM_NAME)

    kinesis_client = _build_kinesis_client()
    db_conn = _build_db_conn()
    redis_client = _build_redis()

    async def handle(record: dict) -> None:
        process_record_sync(
            record,
            redis_client=redis_client,
            db_conn=db_conn,
            kinesis_client=kinesis_client,
        )

    loop = ShardLoop(stream_name=STREAM_NAME, handler=handle, starting_position="LATEST")
    run_task = asyncio.create_task(loop.run())

    await _stop_event.wait()
    await loop.shutdown()
    try:
        await asyncio.wait_for(run_task, timeout=10)
    except TimeoutError:
        log.warning("consumer_shutdown_timeout")
    log.info("stopped", service=SERVICE_NAME)

def main() -> None:
    asyncio.run(run())

if __name__ == "__main__":
    main()
