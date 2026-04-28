from __future__ import annotations

import os
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest
from starlette.responses import Response

log = structlog.get_logger(__name__)

SERVICE_NAME = "identity-fleet"
BUILD_SHA = os.environ.get("BUILD_SHA", "dev")

requests_total = Counter(
    "identity_fleet_requests_total",
    "Requests handled by identity-fleet.",
    ["path", "status"],
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("starting", service=SERVICE_NAME, build=BUILD_SHA)

    yield
    log.info("stopping", service=SERVICE_NAME)

app = FastAPI(title="UrbanMove — Identity & Fleet", version="0.1.0", lifespan=lifespan)

@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok", "service": SERVICE_NAME, "build": BUILD_SHA}

@app.get("/metrics")
async def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/users")
async def list_users() -> dict[str, list]:

    return {"users": []}

@app.get("/fleets")
async def list_fleets() -> dict[str, list]:
    return {"fleets": []}
