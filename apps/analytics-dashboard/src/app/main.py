from __future__ import annotations

import asyncio
import os
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, generate_latest
from starlette.responses import Response

log = structlog.get_logger(__name__)

SERVICE_NAME = "analytics-dashboard"
BUILD_SHA = os.environ.get("BUILD_SHA", "dev")
KINESIS_STREAM = os.environ.get("KINESIS_STREAM", "urbanmove-dev-vehicle-telemetry-v1")

requests_total = Counter(
    "analytics_dashboard_requests_total",
    "Requests handled by analytics-dashboard.",
    ["path", "status"],
)
ws_connected = Gauge(
    "analytics_dashboard_ws_connected",
    "Currently connected WebSocket clients.",
)
events_broadcast = Counter(
    "analytics_dashboard_events_broadcast_total",
    "Events broadcast to WebSocket clients.",
    ["type"],
)

class Hub:

    def __init__(self) -> None:
        self._clients: set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def join(self, ws: WebSocket) -> None:
        async with self._lock:
            self._clients.add(ws)
            ws_connected.set(len(self._clients))

    async def leave(self, ws: WebSocket) -> None:
        async with self._lock:
            self._clients.discard(ws)
            ws_connected.set(len(self._clients))

    async def broadcast(self, message: dict) -> None:
        msg_type = message.get("type", "telemetry")
        dead: list[WebSocket] = []
        for ws in list(self._clients):
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.leave(ws)
        events_broadcast.labels(type=msg_type).inc()

hub = Hub()

async def _kinesis_consumer(stop: asyncio.Event) -> None:

    try:
        from app.kinesis_client import ShardLoop
    except ImportError:
        log.warning("kinesis_client_unavailable_running_ws_only")
        await stop.wait()
        return

    async def handle(record: dict) -> None:
        event_type = record.get("type", "telemetry")
        await hub.broadcast({"type": event_type, **record})

    loop = ShardLoop(stream_name=KINESIS_STREAM, handler=handle, starting_position="LATEST")
    run_task = asyncio.create_task(loop.run())
    await stop.wait()
    await loop.shutdown()
    await run_task

@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("starting", service=SERVICE_NAME, build=BUILD_SHA, stream=KINESIS_STREAM)
    stop = asyncio.Event()
    consumer = asyncio.create_task(_kinesis_consumer(stop))
    try:
        yield
    finally:
        stop.set()
        try:
            await asyncio.wait_for(consumer, timeout=10)
        except TimeoutError:
            log.warning("consumer_shutdown_timeout")
        log.info("stopping", service=SERVICE_NAME)

app = FastAPI(title="UrbanMove — Analytics Dashboard", version="0.1.0", lifespan=lifespan)

@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok", "service": SERVICE_NAME, "build": BUILD_SHA}

@app.get("/metrics")
async def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/kpis")
async def kpis() -> dict[str, float | int]:

    return {"active_vehicles": 0, "avg_speed_kmh": 0.0, "alerts_last_hour": 0}

@app.websocket("/ws/alerts")
async def ws_alerts(ws: WebSocket) -> None:
    await ws.accept()
    await hub.join(ws)
    try:
        await ws.send_json({"type": "hello", "service": SERVICE_NAME, "build": BUILD_SHA})
        while True:

            msg = await ws.receive_text()
            if msg == "ping":
                await ws.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        await hub.leave(ws)

@app.post("/broadcast")
async def broadcast_test(message: dict) -> dict[str, int]:

    await hub.broadcast(message)
    return {"delivered_to": int(ws_connected._value.get())}
