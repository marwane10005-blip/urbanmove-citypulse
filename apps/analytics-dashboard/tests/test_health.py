from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz() -> None:
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["service"] == "analytics-dashboard"


def test_kpis_shape() -> None:
    r = client.get("/kpis")
    assert r.status_code == 200
    for key in ("active_vehicles", "avg_speed_kmh", "alerts_last_hour"):
        assert key in r.json()
