from __future__ import annotations

import json
import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from urllib.parse import quote_plus

import structlog
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

log = structlog.get_logger(__name__)

_engine: object | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None

def _resolve_url() -> str:
    env_url = os.environ.get("DATABASE_URL")
    if env_url:
        return env_url.replace("postgresql://", "postgresql+asyncpg://", 1)

    secret_id = os.environ.get("DB_SECRET_ID")
    host = os.environ.get("DB_HOST")
    port = os.environ.get("DB_PORT", "5432")
    db_name = os.environ.get("DB_NAME", "urbanmove")

    if not (secret_id and host):
        raise RuntimeError(
            "Set DATABASE_URL or DB_SECRET_ID + DB_HOST for mobility-api DB config."
        )

    import boto3

    blob = json.loads(
        boto3.client("secretsmanager").get_secret_value(SecretId=secret_id)["SecretString"]
    )
    return (
        f"postgresql+asyncpg://{quote_plus(blob['username'])}:"
        f"{quote_plus(blob['password'])}@{host}:{port}/{db_name}"
    )

def init_engine() -> None:
    global _engine, _session_factory
    url = _resolve_url()
    _engine = create_async_engine(
        url,
        pool_size=5,
        max_overflow=5,
        pool_pre_ping=True,
        pool_recycle=300,
        echo=False,
    )
    _session_factory = async_sessionmaker(_engine, expire_on_commit=False)
    log.info("db_engine_initialised", pool_size=5)

async def dispose_engine() -> None:
    global _engine
    if _engine is not None:
        await _engine.dispose()
        _engine = None

@asynccontextmanager
async def session_scope() -> AsyncIterator[AsyncSession]:
    if _session_factory is None:
        raise RuntimeError("init_engine() must be called during FastAPI lifespan.")
    async with _session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

async def get_session() -> AsyncIterator[AsyncSession]:

    async with session_scope() as session:
        yield session
