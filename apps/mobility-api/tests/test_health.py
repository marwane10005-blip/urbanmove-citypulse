from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz() -> None:
    r = client.get("/healthz")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["service"] == "mobility-api"


def test_metrics_exposed() -> None:
    r = client.get("/metrics")
    assert r.status_code == 200
    assert b"mobility_api_requests_total" in r.content
