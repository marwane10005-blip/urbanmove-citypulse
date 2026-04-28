# db-migrate

Alembic-driven schema migrations for Aurora PostgreSQL. Packaged as a
container so we can run it as a Helm pre-install/pre-upgrade Job.

## Running locally

```bash
docker compose up -d postgres
export DATABASE_URL=postgresql+psycopg2://urbanmove:urbanmove@localhost:5432/urbanmove
pip install -r requirements.txt
alembic upgrade head
```

Expected tables after migrations `0001` + `0002`:

```
 fleets
 vehicles
 trips
 zones               (PostGIS polygons for Paris arrondissements)
 congestion_events
```

## Running against Aurora (cluster must exist)

The container assembles the database URL from:

- `DB_SECRET_ID` — Secrets Manager ARN holding `{username, password}`
- `DB_HOST` — Aurora writer endpoint
- `DB_PORT` — default `5432`
- `DB_NAME` — default `urbanmove`

All of those come from the Terraform outputs; the Helm values in
`deploy/helm/values-db-migrate.yaml` reference a ConfigMap (`urbanmove-config`)
that maps them.

## Authoring new migrations

```bash
cd apps/db-migrate
alembic revision -m "your descriptive name"
```

Prefer raw SQL (`op.execute`) over the declarative layer — keeps the schema
explicit and matches how the services read it (they use `text()` queries,
not declarative models).
