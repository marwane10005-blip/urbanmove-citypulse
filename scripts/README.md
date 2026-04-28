# scripts/

One-off and demo-day helpers. Intended contents:

- `seed-fleet.py` — pre-populate Aurora + Redis with N vehicles in a Paris
  bounding box; invoked by `make demo`.
- `trigger-congestion.py` — publish a synthetic congestion event into
  Kinesis so the dashboard can demo the alert flow on demand.
- `tail-kinesis.py` — pretty-print recent records from the telemetry stream
  for live debugging.
- `bootstrap-tfstate.sh` — create the remote state bucket + DynamoDB lock
  table; one-shot, per AWS account.

None of these are implemented yet — scaffolded placeholders only.
