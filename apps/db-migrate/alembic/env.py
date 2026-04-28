from __future__ import annotations

import json
import os
from logging.config import fileConfig
from typing import Any

from alembic import context
from sqlalchemy import engine_from_config, pool

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = None

def _db_url_from_env_or_secret() -> str:
    env_url = os.environ.get("DATABASE_URL")
    if env_url:
        return env_url

    secret_id = os.environ.get("DB_SECRET_ID")
    host = os.environ.get("DB_HOST")
    port = os.environ.get("DB_PORT", "5432")
    db_name = os.environ.get("DB_NAME", "urbanmove")

    if not (secret_id and host):
        raise RuntimeError(
            "Set DATABASE_URL, or DB_SECRET_ID + DB_HOST (+ optional "
            "DB_PORT/DB_NAME) so env.py can assemble a URL."
        )

    import boto3

    sm = boto3.client("secretsmanager")
    blob: dict[str, Any] = json.loads(sm.get_secret_value(SecretId=secret_id)["SecretString"])
    username = blob["username"]
    password = blob["password"]

    from urllib.parse import quote_plus

    return f"postgresql+psycopg2://{quote_plus(username)}:{quote_plus(password)}@{host}:{port}/{db_name}"

def run_migrations_offline() -> None:

    context.configure(
        url=_db_url_from_env_or_secret(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    section = config.get_section(config.config_ini_section, {})
    section["sqlalchemy.url"] = _db_url_from_env_or_secret()
    connectable = engine_from_config(
        section,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
