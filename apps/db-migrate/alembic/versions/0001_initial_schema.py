from __future__ import annotations

from alembic import op

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None

def upgrade() -> None:

    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")

    op.execute(

    )

    op.execute(

    )
    op.execute("CREATE INDEX zones_geom_gix ON zones USING GIST (geom)")

    op.execute(

    )
    op.execute("CREATE INDEX vehicles_fleet_idx ON vehicles (fleet_id)")
    op.execute(
        "CREATE INDEX vehicles_current_position_gix "
        "ON vehicles USING GIST (current_position)"
    )
    op.execute("CREATE INDEX vehicles_last_seen_idx ON vehicles (last_seen DESC)")

    op.execute(

    )
    op.execute("CREATE INDEX trips_vehicle_started_idx ON trips (vehicle_id, started_at DESC)")
    op.execute("CREATE INDEX trips_started_idx ON trips (started_at DESC)")

    op.execute(

    )
    op.execute(
        "CREATE INDEX congestion_events_zone_detected_idx "
        "ON congestion_events (zone_id, detected_at DESC)"
    )
    op.execute(
        "CREATE INDEX congestion_events_open_idx ON congestion_events (detected_at DESC) "
        "WHERE resolved_at IS NULL"
    )

    op.execute(
        "INSERT INTO fleets (fleet_id, display_name) VALUES "
        "('paris-demo', 'Paris demo fleet')"
    )

def downgrade() -> None:
    for tbl in ("congestion_events", "trips", "vehicles", "zones", "fleets"):
        op.execute(f"DROP TABLE IF EXISTS {tbl} CASCADE")
