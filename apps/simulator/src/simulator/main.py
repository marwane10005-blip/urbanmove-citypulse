from __future__ import annotations

import json
import math
import os
import random
import signal
import time
from dataclasses import dataclass
from typing import Any

import boto3
import structlog
from awscrt import io, mqtt
from awsiot import mqtt_connection_builder
from prometheus_client import Counter, Gauge, start_http_server

log = structlog.get_logger(__name__)

BUILD_SHA = os.environ.get("BUILD_SHA", "dev")
FLEET_SIZE = int(os.environ.get("FLEET_SIZE", "100"))
PUBLISH_HZ = float(os.environ.get("PUBLISH_HZ", "1.0"))
METRICS_PORT = int(os.environ.get("METRICS_PORT", "9090"))
CLIENT_ID = os.environ.get("CLIENT_ID", "urbanmove-simulator")
TOPIC = os.environ.get("TOPIC", f"urbanmove/fleet/{CLIENT_ID}/telemetry")
SECRET_ID = os.environ.get("IOT_CERT_SECRET_ID")

LAT_MIN, LAT_MAX = 48.815, 48.905
LON_MIN, LON_MAX = 2.260, 2.420

publishes_total = Counter(
    "simulator_publishes_total",
    "Total MQTT publishes attempted.",
    ["status"],
)
connected = Gauge("simulator_mqtt_connected", "1 when the MQTT connection is up.")

_running = True

def _shutdown(signum: int, frame: Any) -> None:
    global _running
    log.info("shutdown_signal", signum=signum)
    _running = False

@dataclass
class Vehicle:
    vehicle_id: str
    lat: float
    lon: float
    heading_deg: float
    speed_kmh: float
    battery_pct: float

    def step(self, dt_s: float) -> None:
        speed_mps = self.speed_kmh * 1000 / 3600
        dlat = (speed_mps * math.cos(math.radians(self.heading_deg)) * dt_s) / 111_000
        dlon = (speed_mps * math.sin(math.radians(self.heading_deg)) * dt_s) / (
            111_000 * math.cos(math.radians(self.lat))
        )
        self.lat = max(LAT_MIN, min(LAT_MAX, self.lat + dlat))
        self.lon = max(LON_MIN, min(LON_MAX, self.lon + dlon))
        if random.random() < 0.05:
            self.heading_deg = (self.heading_deg + random.uniform(-45, 45)) % 360
        self.speed_kmh = max(0.0, min(50.0, self.speed_kmh + random.uniform(-2, 2)))
        self.battery_pct = max(0.0, self.battery_pct - 0.001 * dt_s)

def seed_fleet(n: int) -> list[Vehicle]:
    return [
        Vehicle(
            vehicle_id=f"veh-{i:04d}",
            lat=random.uniform(LAT_MIN, LAT_MAX),
            lon=random.uniform(LON_MIN, LON_MAX),
            heading_deg=random.uniform(0, 360),
            speed_kmh=random.uniform(5, 30),
            battery_pct=random.uniform(40, 100),
        )
        for i in range(n)
    ]

def _load_credentials() -> dict[str, str]:
    if not SECRET_ID:
        raise RuntimeError(
            "IOT_CERT_SECRET_ID is not set. Run scripts/bootstrap-device-cert.py first."
        )
    sm = boto3.client("secretsmanager")
    payload = json.loads(sm.get_secret_value(SecretId=SECRET_ID)["SecretString"])
    required = ("certificatePem", "privateKeyPem", "endpoint")
    missing = [k for k in required if k not in payload]
    if missing:
        raise RuntimeError(f"secret {SECRET_ID} missing keys: {missing}")
    return payload

def _build_connection(creds: dict[str, str]) -> mqtt.Connection:
    event_loop_group = io.EventLoopGroup(1)
    host_resolver = io.DefaultHostResolver(event_loop_group)
    client_bootstrap = io.ClientBootstrap(event_loop_group, host_resolver)
    return mqtt_connection_builder.mtls_from_bytes(
        endpoint=creds["endpoint"],
        cert_bytes=creds["certificatePem"].encode("utf-8"),
        pri_key_bytes=creds["privateKeyPem"].encode("utf-8"),
        client_bootstrap=client_bootstrap,
        client_id=CLIENT_ID,
        clean_session=True,
        keep_alive_secs=30,
        on_connection_interrupted=_on_interrupted,
        on_connection_resumed=_on_resumed,
    )

def _on_interrupted(connection, error, **_kwargs):
    log.warning("mqtt_connection_interrupted", error=str(error))
    connected.set(0)

def _on_resumed(connection, return_code, session_present, **_kwargs):
    log.info("mqtt_connection_resumed", session_present=session_present)
    connected.set(1)

def publish(conn: mqtt.Connection, vehicle: Vehicle) -> None:
    payload = {
        "vehicle_id": vehicle.vehicle_id,
        "ts": time.time(),
        "lat": vehicle.lat,
        "lon": vehicle.lon,
        "heading_deg": round(vehicle.heading_deg, 1),
        "speed_kmh": round(vehicle.speed_kmh, 1),
        "battery_pct": round(vehicle.battery_pct, 2),
    }
    try:
        conn.publish(
            topic=TOPIC,
            payload=json.dumps(payload).encode("utf-8"),
            qos=mqtt.QoS.AT_MOST_ONCE,
        )
        publishes_total.labels(status="ok").inc()
    except Exception as exc:
        publishes_total.labels(status="error").inc()
        log.exception("publish_failed", vehicle=vehicle.vehicle_id, error=str(exc))

def main() -> None:
    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    start_http_server(METRICS_PORT)

    creds = _load_credentials()
    log.info("connecting", endpoint=creds["endpoint"], client_id=CLIENT_ID, fleet_size=FLEET_SIZE)
    conn = _build_connection(creds)
    future = conn.connect()
    future.result(timeout=15)
    connected.set(1)
    log.info("connected", topic=TOPIC)

    fleet = seed_fleet(FLEET_SIZE)
    interval = 1.0 / PUBLISH_HZ
    log.info("publishing", hz=PUBLISH_HZ, build=BUILD_SHA)

    try:
        while _running:
            t0 = time.time()
            for v in fleet:
                v.step(interval)
                publish(conn, v)
            elapsed = time.time() - t0
            time.sleep(max(0.0, interval - elapsed))
    finally:
        log.info("disconnecting")
        try:
            conn.disconnect().result(timeout=10)
        except Exception:
            pass
        connected.set(0)

    log.info("stopped")

if __name__ == "__main__":
    main()
