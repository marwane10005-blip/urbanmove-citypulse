from worker.main import ZoneBucket, _zone_for, events_total, process_record_sync

def test_zone_for_is_grid_aligned() -> None:

    assert _zone_for(48.8621, 2.3522) == _zone_for(48.8623, 2.3520)
    assert _zone_for(48.8621, 2.3522) != _zone_for(48.8700, 2.3600)

def test_zone_bucket_evicts_old_samples() -> None:
    b = ZoneBucket()
    b.add(30.0, ts=0.0)
    b.add(20.0, ts=30.0)
    b.add(10.0, ts=120.0)
    assert b.speeds == [10.0]
    assert b.avg_speed() == 10.0

def test_process_record_increments_counter() -> None:
    before = events_total.labels(status="ok")._value.get()
    process_record_sync(
        {"vehicle_id": "veh-0001", "lat": 48.86, "lon": 2.35, "speed_kmh": 25.0, "ts": 0.0},
        redis_client=None,
        db_conn=None,
    )
    after = events_total.labels(status="ok")._value.get()
    assert after == before + 1

def test_process_record_skips_missing_fields() -> None:
    before_skipped = events_total.labels(status="skipped")._value.get()
    process_record_sync({"vehicle_id": "veh-bad"}, redis_client=None, db_conn=None)
    after_skipped = events_total.labels(status="skipped")._value.get()
    assert after_skipped == before_skipped + 1
