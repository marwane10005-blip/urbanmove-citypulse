from __future__ import annotations

from alembic import op

revision = "0002_seed_paris_zones"
down_revision = "0001_initial"
branch_labels = None
depends_on = None

ZONES = {
    "paris-1er": {
        "name": "Paris 1er (Louvre)",
        "wkt": "POLYGON((2.323 48.853, 2.355 48.853, 2.355 48.868, 2.323 48.868, 2.323 48.853))",
    },
    "paris-5e": {
        "name": "Paris 5e (Latin Quarter)",
        "wkt": "POLYGON((2.340 48.840, 2.360 48.840, 2.360 48.853, 2.340 48.853, 2.340 48.840))",
    },
    "paris-11e": {
        "name": "Paris 11e (Bastille)",
        "wkt": "POLYGON((2.369 48.850, 2.400 48.850, 2.400 48.872, 2.369 48.872, 2.369 48.850))",
    },
    "paris-18e": {
        "name": "Paris 18e (Montmartre)",
        "wkt": "POLYGON((2.330 48.880, 2.365 48.880, 2.365 48.900, 2.330 48.900, 2.330 48.880))",
    },
}

def upgrade() -> None:
    for zid, data in ZONES.items():
        op.execute(
            "INSERT INTO zones (zone_id, display_name, geom) VALUES "
            f"('{zid}', '{data['name']}', ST_GeomFromText('{data['wkt']}', 4326))"
        )

def downgrade() -> None:
    op.execute(
        "DELETE FROM zones WHERE zone_id IN ("
        + ",".join(f"'{k}'" for k in ZONES)
        + ")"
    )
