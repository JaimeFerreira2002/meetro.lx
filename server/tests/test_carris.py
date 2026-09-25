"""Carris parsing + source tests (no live feed needed).

Uses a representative Carris Metropolitana `/vehicles` payload; the exact schema
should still be confirmed against the live endpoint before enabling (#64).
"""

from __future__ import annotations

from app.carris import CarrisSource, parse_vehicle, parse_vehicles

SAMPLE = [
    {
        "id": "44|12345",
        "timestamp": 1_700_000_000,
        "lat": 38.7071,
        "lon": -9.1355,
        "bearing": 210,
        "speed": 8.3,
        "line_id": "1523",
        "route_id": "1523_0",
        "pattern_id": "1523_0_1",
        "trip_id": "trip-1",
        "stop_id": "160123",
        "current_status": "IN_TRANSIT_TO",
    },
    {  # no fix -> dropped
        "id": "44|noloc",
        "line_id": "1523",
    },
    "not-a-dict",  # ignored
]


def test_parse_vehicle_maps_fields():
    v = parse_vehicle(SAMPLE[0])
    assert v is not None
    assert v.train_id == "44|12345"
    assert v.line == "1523"
    assert v.destino == "1523_0_1"          # pattern_id
    assert v.next_stop == "160123"          # stop_id
    assert abs(v.lat - 38.7071) < 1e-6
    assert abs(v.lon + 9.1355) < 1e-6
    assert v.bearing == 210.0
    assert v.speed_mps == 8.3
    assert v.mode == "bus"
    assert v.operator == "Carris"
    assert v.depth_m == 0.0


def test_parse_vehicle_without_position_is_none():
    assert parse_vehicle({"id": "x", "line_id": "1"}) is None


def test_parse_vehicles_skips_bad_entries():
    vs = parse_vehicles(SAMPLE)
    assert len(vs) == 1
    assert vs[0].train_id == "44|12345"


def test_parse_vehicles_handles_empty():
    assert parse_vehicles(None) == []
    assert parse_vehicles([]) == []


def test_source_prunes_stale_snapshot():
    src = CarrisSource()
    vs = parse_vehicles(SAMPLE)
    src.update(vs, now=1000.0)
    assert len(src.snapshot(now=1000.0)) == 1     # fresh
    assert len(src.snapshot(now=1030.0)) == 1     # still within window
    assert src.snapshot(now=1000.0 + 120.0) == []  # gone stale -> empty
