"""Carris parsing + source tests (no live feed needed).

SAMPLE[0] is a real entry from the live Carris Metropolitana `/v2/vehicles` feed
(2026-09-25), trimmed but with the field shape intact.
"""

from __future__ import annotations

from app.carris import CarrisSource, parse_vehicle, parse_vehicles

SAMPLE = [
    {
        "agency_id": "43",
        "bearing": 222,
        "current_status": "INCOMING_AT",
        "direction_id": 0,
        "id": "[YA15B]2270",
        "lat": 38.673836,
        "line_id": "3041",
        "lon": -9.153863,
        "pattern_id": "[ZN3JG][YA15B]3041_0_1",
        "route_id": "[YA15B]3041_0",
        "speed": 30,
        "stop_id": "020497",
        "timestamp": 1_790_343_507_000,
        "trip_id": "[ZN3JG][YA15B]3041_0_1_1400_1429_0_ESC_DU",
    },
    {  # no fix -> dropped
        "id": "[YA15B]noloc",
        "line_id": "3041",
    },
    "not-a-dict",  # ignored
]


def test_parse_vehicle_maps_fields():
    v = parse_vehicle(SAMPLE[0])
    assert v is not None
    assert v.train_id == "[YA15B]2270"
    assert v.line == "3041"
    assert v.destino == "[ZN3JG][YA15B]3041_0_1"   # pattern_id
    assert v.next_stop == "020497"                 # stop_id
    assert abs(v.lat - 38.673836) < 1e-6
    assert abs(v.lon + 9.153863) < 1e-6
    assert v.bearing == 222.0
    assert v.speed_mps == 30.0
    assert v.mode == "bus"
    assert v.operator == "Carris"
    assert v.depth_m == 0.0


def test_parse_vehicle_without_position_is_none():
    assert parse_vehicle({"id": "x", "line_id": "1"}) is None


def test_parse_vehicles_skips_bad_entries():
    vs = parse_vehicles(SAMPLE)
    assert len(vs) == 1
    assert vs[0].train_id == "[YA15B]2270"


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
