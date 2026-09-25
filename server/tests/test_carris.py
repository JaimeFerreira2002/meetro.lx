"""Carris parsing + source tests (no live feed needed).

SAMPLE[0] is a real entry from the live Carris Metropolitana `/v2/vehicles` feed
(2026-09-25), trimmed but with the field shape intact.
"""

from __future__ import annotations

from app.carris import CarrisSource, bbox_from_points, parse_vehicle, parse_vehicles

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


# --- bounding-box filter (#64: keep Carris near the Metro, not region-wide) ---

# SAMPLE[0] sits at (38.673836, -9.153863) — inside this Lisbon-ish box.
LISBON_BBOX = (38.66, 38.80, -9.25, -9.08)


def test_bbox_from_points_pads_around_points():
    bb = bbox_from_points([(38.70, -9.15), (38.75, -9.10)], pad_km=1.0)
    assert bb is not None
    lat_min, lat_max, lon_min, lon_max = bb
    assert lat_min < 38.70 and lat_max > 38.75
    assert lon_min < -9.15 and lon_max > -9.10
    assert abs(lat_min - (38.70 - 1.0 / 111.0)) < 2e-3  # ~1 km of latitude pad


def test_bbox_from_points_empty_is_none():
    assert bbox_from_points([], pad_km=3.0) is None


def test_parse_vehicles_filters_outside_bbox():
    far = dict(SAMPLE[0], id="[FAR]1", lat=39.5, lon=-8.0)  # well outside Lisbon
    payload = [SAMPLE[0], far]
    assert len(parse_vehicles(payload)) == 2                       # no bbox -> both
    inside = parse_vehicles(payload, bbox=LISBON_BBOX)
    assert [v.train_id for v in inside] == ["[YA15B]2270"]         # far one dropped
