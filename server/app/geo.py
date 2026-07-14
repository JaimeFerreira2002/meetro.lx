"""Geometry helpers.

v0 uses straight great-circle segments between stations. This is a visible
approximation (real trains follow curved tunnels). Swap `interpolate` for
arc-length lookup along baked OSM polylines (data/) when they land — the
call site in registry.py doesn't need to change.
"""

from __future__ import annotations

import math

EARTH_R = 6_371_000.0  # metres


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_R * math.asin(math.sqrt(a))


def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


def interpolate(
    lat1: float, lon1: float, lat2: float, lon2: float, frac: float
) -> tuple[float, float]:
    """Point a fraction `frac` (0..1) of the way from station 1 to station 2."""
    frac = max(0.0, min(1.0, frac))
    return (lat1 + (lat2 - lat1) * frac, lon1 + (lon2 - lon1) * frac)
