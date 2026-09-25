"""Track projection tests — the arc-length interpolation in app/track.py.

Focus on issue #59 part 2: a station must not snap to the wrong lobe / the
parallel opposite direction and teleport the train. These use hand-built
geometry (no live feed needed); ranges are generous so they don't depend on
exact metres.
"""

from __future__ import annotations

from app.track import Polyline, TrackGeometry


def _tg(*polys: Polyline) -> TrackGeometry:
    tg = TrackGeometry()
    for p in polys:
        tg.by_line.setdefault(p.line, []).append(p)
    return tg


def _straight_line() -> Polyline:
    # East-west along a constant latitude; ~434 m per 0.005° lon step at Lisbon.
    return Polyline("L", "east", [(38.700, -9.160 + i * 0.005) for i in range(9)])


def test_project_returns_arclength_and_offset():
    line = Polyline("L", "east", [(38.70, -9.16), (38.70, -9.15), (38.70, -9.14)])

    s_on, off_on = line.project((38.70, -9.15))  # a point sitting on the line
    assert off_on < 1.0
    assert abs(s_on - line.cum[1]) < 1.0

    s_off, off_off = line.project((38.701, -9.15))  # ~111 m north of that vertex
    assert 90.0 < off_off < 130.0
    assert abs(s_off - line.cum[1]) < 5.0


def test_segment_point_interpolates_forward():
    tg = _tg(_straight_line())
    r = tg.segment_point("L", "A", (38.700, -9.150), "B", (38.700, -9.140), 0.5)
    assert r is not None
    lat, lon, _brg, delta = r
    assert abs(lat - 38.700) < 1e-4
    assert -9.150 < lon < -9.140          # halfway between the two stations
    assert 820.0 < delta < 910.0          # two ~434 m segments


def test_picks_forward_direction_not_reverse():
    pts = [(38.700, -9.160 + i * 0.005) for i in range(9)]
    fwd = Polyline("L", "east", pts)
    rev = Polyline("L", "west", list(reversed(pts)))
    tg = _tg(fwd, rev)

    r = tg.segment_point("L", "A", (38.700, -9.150), "B", (38.700, -9.140), 0.5)
    assert r is not None
    _lat, lon, _brg, delta = r
    assert -9.150 < lon < -9.140          # forward hop, not the reverse polyline
    assert 820.0 < delta < 910.0


def test_rejects_teleport_to_far_lobe():
    """A hairpin polyline (east, then back west just north) means a station can
    snap to the return lobe far along the arc. The old 'largest positive delta'
    rule teleported there; now that implausible jump is rejected (None -> the
    caller falls back to a straight line)."""
    east = [(38.700, -9.160 + i * 0.005) for i in range(13)]   # -9.160 .. -9.100
    west = [(38.701, -9.100 - i * 0.005) for i in range(13)]   # back -9.100 .. -9.160
    tg = _tg(Polyline("L", "loop", east + west))

    a = (38.700, -9.155)      # on the outbound lobe
    b = (38.7008, -9.150)     # nudged north -> nearest point is the RETURN lobe
    assert tg.segment_point("L", "A", a, "B", b, 0.5) is None

    # A genuine adjacent hop on the outbound lobe is still interpolated.
    r = tg.segment_point("L", "A", a, "A2", (38.700, -9.150), 0.5)
    assert r is not None
    _lat, _lon, _brg, delta = r
    assert 300.0 < delta < 700.0


def test_missing_line_returns_none():
    tg = _tg(_straight_line())
    assert tg.segment_point("Nope", "A", (38.70, -9.15), "B", (38.70, -9.14), 0.5) is None
