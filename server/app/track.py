"""Track geometry: arc-length interpolation along baked OSM polylines.

Loads data/track_geometry.geojson (one LineString per line+direction), projects
stations onto the right directional polyline, and returns a point a given fraction
along the real curved track between two stations — replacing straight-line segments.

Direction is chosen from the train's own motion (prev -> next), so it works even
for short-turn destinos that aren't full-line termini.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from pathlib import Path

Pt = tuple[float, float]  # (lat, lon)


def _haversine_m(a: Pt, b: Pt) -> float:
    (la1, lo1), (la2, lo2) = a, b
    p1, p2 = math.radians(la1), math.radians(la2)
    dp, dl = math.radians(la2 - la1), math.radians(lo2 - lo1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6_371_000 * math.asin(math.sqrt(h))


def _bearing(a: Pt, b: Pt) -> float:
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dl = math.radians(b[1] - a[1])
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


@dataclass
class Polyline:
    line: str
    to: str
    pts: list[Pt]
    cum: list[float] = field(default_factory=list)  # cumulative metres

    def __post_init__(self) -> None:
        self.cum = [0.0]
        for a, b in zip(self.pts, self.pts[1:]):
            self.cum.append(self.cum[-1] + _haversine_m(a, b))

    @property
    def length(self) -> float:
        return self.cum[-1]

    def project(self, p: Pt) -> float:
        """Arc-length (metres) of the point on this polyline nearest to p."""
        best_s, best_d = 0.0, float("inf")
        # local equirectangular scale for fast planar distance
        coslat = math.cos(math.radians(p[0]))
        for i in range(len(self.pts) - 1):
            a, b = self.pts[i], self.pts[i + 1]
            ax, ay = (a[1] - p[1]) * coslat, a[0] - p[0]
            bx, by = (b[1] - p[1]) * coslat, b[0] - p[0]
            dx, dy = bx - ax, by - ay
            seg2 = dx * dx + dy * dy
            t = 0.0 if seg2 == 0 else max(0.0, min(1.0, -(ax * dx + ay * dy) / seg2))
            cx, cy = ax + t * dx, ay + t * dy
            d = cx * cx + cy * cy
            if d < best_d:
                best_d = d
                best_s = self.cum[i] + t * (self.cum[i + 1] - self.cum[i])
        return best_s

    def point_at(self, s: float) -> tuple[float, float, float]:
        """(lat, lon, bearing) at arc-length s."""
        s = max(0.0, min(self.length, s))
        lo, hi = 0, len(self.cum) - 1
        while lo < hi - 1:
            mid = (lo + hi) // 2
            if self.cum[mid] <= s:
                lo = mid
            else:
                hi = mid
        seg = self.cum[hi] - self.cum[lo]
        t = 0.0 if seg == 0 else (s - self.cum[lo]) / seg
        a, b = self.pts[lo], self.pts[hi]
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, _bearing(a, b))


class TrackGeometry:
    def __init__(self) -> None:
        self.by_line: dict[str, list[Polyline]] = {}
        self._station_s: dict[tuple[int, str], float] = {}  # (id(poly), stop_id) -> s

    @classmethod
    def load(cls, path: Path) -> "TrackGeometry":
        tg = cls()
        if not path.exists():
            return tg
        data = json.loads(path.read_text())
        for feat in data.get("features", []):
            props = feat["properties"]
            pts = [(lat, lon) for lon, lat in feat["geometry"]["coordinates"]]
            poly = Polyline(props["line"], props.get("to", ""), pts)
            tg.by_line.setdefault(props["line"], []).append(poly)
        return tg

    def _station_arc(self, poly: Polyline, stop_id: str, pt: Pt) -> float:
        key = (id(poly), stop_id)
        s = self._station_s.get(key)
        if s is None:
            s = poly.project(pt)
            self._station_s[key] = s
        return s

    def segment_point(
        self, line: str, prev_id: str, prev_pt: Pt, next_id: str, next_pt: Pt, frac: float
    ) -> tuple[float, float, float, float] | None:
        """(lat, lon, bearing, segment_len_m) `frac` of the way prev->next along track."""
        polys = self.by_line.get(line)
        if not polys:
            return None
        # pick the directional polyline where next is further along than prev
        best = None
        for poly in polys:
            s_prev = self._station_arc(poly, prev_id, prev_pt)
            s_next = self._station_arc(poly, next_id, next_pt)
            delta = s_next - s_prev
            if delta > 0 and (best is None or delta > best[0]):
                best = (delta, poly, s_prev, s_next)
        if best is None:
            return None
        delta, poly, s_prev, s_next = best
        s = s_prev + max(0.0, min(1.0, frac)) * delta
        lat, lon, brg = poly.point_at(s)
        return lat, lon, brg, delta
