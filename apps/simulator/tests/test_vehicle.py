from simulator.main import LAT_MAX, LAT_MIN, LON_MAX, LON_MIN, Vehicle, seed_fleet


def test_vehicle_stays_in_bounds() -> None:
    v = Vehicle(
        vehicle_id="veh-0000",
        lat=48.86,
        lon=2.35,
        heading_deg=0,
        speed_kmh=30,
        battery_pct=100,
    )
    for _ in range(1000):
        v.step(0.5)
        assert LAT_MIN <= v.lat <= LAT_MAX
        assert LON_MIN <= v.lon <= LON_MAX


def test_seed_fleet_count() -> None:
    fleet = seed_fleet(25)
    assert len(fleet) == 25
    assert len({v.vehicle_id for v in fleet}) == 25
