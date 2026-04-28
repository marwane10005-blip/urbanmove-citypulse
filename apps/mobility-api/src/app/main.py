from __future__ import annotations

import math
import os
from contextlib import asynccontextmanager
from typing import Annotated

import structlog
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import Response

from app.auth import User, current_user
from app.db import dispose_engine, get_session, init_engine

log = structlog.get_logger(__name__)

SERVICE_NAME = "mobility-api"
BUILD_SHA = os.environ.get("BUILD_SHA", "dev")

requests_total = Counter(
    "mobility_api_requests_total",
    "Requests handled by the mobility-api, partitioned by path and status.",
    ["path", "status"],
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("starting", service=SERVICE_NAME, build=BUILD_SHA)
    init_engine()
    yield
    await dispose_engine()
    log.info("stopping", service=SERVICE_NAME)

app = FastAPI(
    title="UrbanMove — Mobility API",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("CORS_ALLOWED_ORIGINS", "*").split(","),
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["authorization", "content-type"],
)

@app.get("/healthz")
async def healthz() -> dict[str, str]:
    requests_total.labels(path="/healthz", status="200").inc()
    return {"status": "ok", "service": SERVICE_NAME, "build": BUILD_SHA}

@app.get("/metrics")
async def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

class VehicleOut(BaseModel):
    vehicle_id: str
    fleet_id: str
    model: str | None
    lat: float | None
    lon: float | None
    speed_kmh: float | None
    battery_pct: float | None
    last_seen: str | None

VEHICLE_SELECT = """
    SELECT
        vehicle_id,
        fleet_id,
        model,
        ST_Y(current_position) AS lat,
        ST_X(current_position) AS lon,
        current_speed_kmh       AS speed_kmh,
        battery_pct,
        last_seen
    FROM vehicles
"""

@app.get("/vehicles", response_model=list[VehicleOut])
async def list_vehicles(
    user: Annotated[User, Depends(current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
    fleet_id: str | None = None,
    limit: int = 200,
) -> list[dict]:
    sql = VEHICLE_SELECT
    params: dict = {"lim": max(1, min(limit, 1000))}
    if fleet_id:
        sql += " WHERE fleet_id = :fleet_id"
        params["fleet_id"] = fleet_id
    sql += " ORDER BY last_seen DESC NULLS LAST LIMIT :lim"

    rows = (await session.execute(text(sql), params)).mappings().all()
    requests_total.labels(path="/vehicles", status="200").inc()
    log.info("vehicles_listed", count=len(rows), user=user.email)
    return [dict(r) for r in rows]

@app.get("/vehicles/{vehicle_id}", response_model=VehicleOut)
async def get_vehicle(
    vehicle_id: str,
    user: Annotated[User, Depends(current_user)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict:
    sql = VEHICLE_SELECT + " WHERE vehicle_id = :vid"
    row = (
        await session.execute(text(sql), {"vid": vehicle_id})
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="vehicle not found")
    return dict(row)

class EtaRequest(BaseModel):
    origin: tuple[float, float] = Field(..., description="(lat, lon)")
    destination: tuple[float, float] = Field(..., description="(lat, lon)")
    hour_of_day: int | None = None
    day_of_week: int | None = None
    zone_congestion_index: float | None = None

class EtaResponse(BaseModel):
    eta_seconds: float
    source: str
    distance_m: float

def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))

@app.post("/eta", response_model=EtaResponse)
async def predict_eta(
    body: EtaRequest,
    user: Annotated[User, Depends(current_user)],
) -> dict:
    dist_m = _haversine_m(*body.origin, *body.destination)

    endpoint = os.environ.get("SAGEMAKER_ETA_ENDPOINT")
    if not endpoint:

        return {"eta_seconds": dist_m / 8.33, "source": "fallback", "distance_m": dist_m}

    import json

    import boto3

    payload = {
        "instances": [
            {
                "origin_lat": body.origin[0],
                "origin_lon": body.origin[1],
                "dest_lat": body.destination[0],
                "dest_lon": body.destination[1],
                "hour_of_day": body.hour_of_day or 12,
                "day_of_week": body.day_of_week or 2,
                "zone_congestion_index": body.zone_congestion_index or 0.2,
            }
        ]
    }
    try:
        client = boto3.client(
            "sagemaker-runtime",
            region_name=os.environ.get("AWS_REGION", "eu-west-3"),
        )
        resp = client.invoke_endpoint(
            EndpointName=endpoint,
            ContentType="application/json",
            Body=json.dumps(payload).encode("utf-8"),
        )
        parsed = json.loads(resp["Body"].read())
        eta_seconds = float(parsed["predictions"][0])
        return {"eta_seconds": eta_seconds, "source": "model", "distance_m": dist_m}
    except Exception as exc:
        log.warning("sagemaker_invoke_failed", error=str(exc))
        return {"eta_seconds": dist_m / 8.33, "source": "fallback", "distance_m": dist_m}
