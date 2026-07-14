#!/usr/bin/env python3
"""Build baked track geometry for the Lisbon Metro from OpenStreetMap.

Fetches the 8 subway route relations (4 lines x 2 directions) via Overpass,
stitches each relation's ordered track ways into a single oriented polyline
(from -> to), and writes data/track_geometry.geojson (one LineString per
direction). The server consumes this for arc-length interpolation instead of
straight lines between stations.

Usage:
  python3 build_track_geometry.py                 # fetch from Overpass
  python3 build_track_geometry.py --raw osm.json  # use a cached Overpass dump
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import urllib.parse
import urllib.request
from pathlib import Path

OVERPASS = "https://overpass-api.de/api/interpreter"
BBOX = "38.68,-9.26,38.82,-9.08"
QUERY = f'[out:json][timeout:150];relation["route"="subway"]({BBOX});out geom;'
CONNECT_TOL_M = 8.0  # ways sharing a node are identical coords; larger => real gap
OUT = Path(__file__).parent / "track_geometry.geojson"


def haversine_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    (la1, lo1), (la2, lo2) = a, b
    p1, p2 = math.radians(la1), math.radians(la2)
    dp, dl = math.radians(la2 - la1), math.radians(lo2 - lo1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6_371_000 * math.asin(math.sqrt(h))


def fetch() -> dict:
    req = urllib.request.Request(
        OVERPASS,
        data=urllib.parse.urlencode({"data": QUERY}).encode(),
        headers={"User-Agent": "metro-lisboa-ar/0.1 (track geometry build)"},
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.load(resp)


def stitch(ways: list[list[tuple[float, float]]], first_stop, last_stop):
    """Chain ordered ways into one polyline oriented first_stop -> last_stop."""
    poly = list(ways[0])
    # orient the first way so its tail connects to the second way
    if len(ways) > 1:
        nxt = ways[1]
        d_tail = min(haversine_m(poly[-1], nxt[0]), haversine_m(poly[-1], nxt[-1]))
        d_head = min(haversine_m(poly[0], nxt[0]), haversine_m(poly[0], nxt[-1]))
        if d_head < d_tail:
            poly.reverse()

    gaps = 0
    for w in ways[1:]:
        tail = poly[-1]
        if haversine_m(tail, w[-1]) < haversine_m(tail, w[0]):
            w = list(reversed(w))
        if haversine_m(tail, w[0]) > CONNECT_TOL_M:
            gaps += 1
        poly.extend(w[1:])

    # ensure overall direction matches from -> to (using terminal stops)
    if first_stop and last_stop:
        if haversine_m(poly[0], first_stop) > haversine_m(poly[0], last_stop):
            poly.reverse()
    return poly, gaps


def length_km(poly) -> float:
    return sum(haversine_m(a, b) for a, b in zip(poly, poly[1:])) / 1000


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", help="cached Overpass JSON dump")
    args = ap.parse_args()

    data = json.load(open(args.raw)) if args.raw else fetch()
    rels = [e for e in data["elements"] if e["type"] == "relation"]
    if not rels:
        sys.exit("no route relations returned")

    features = []
    for r in rels:
        t = r["tags"]
        ways = [
            [(p["lat"], p["lon"]) for p in m["geometry"]]
            for m in r["members"]
            if m["type"] == "way" and m.get("geometry")
        ]
        stops = [(m["lat"], m["lon"]) for m in r["members"] if m["type"] == "node"]
        if not ways:
            continue
        poly, gaps = stitch(ways, stops[0] if stops else None, stops[-1] if stops else None)
        features.append({
            "type": "Feature",
            "properties": {
                "line": t.get("ref"),
                "from": t.get("from"),
                "to": t.get("to"),
                "colour": t.get("colour"),
                "gaps": gaps,
            },
            "geometry": {"type": "LineString", "coordinates": [[lon, lat] for lat, lon in poly]},
        })
        print(f"  {t.get('ref'):9} -> {t.get('to')[:16]:16} pts={len(poly):4} "
              f"len={length_km(poly):5.1f}km gaps={gaps}")

    OUT.write_text(json.dumps({"type": "FeatureCollection", "features": features}))
    print(f"wrote {len(features)} directional polylines -> {OUT}")


if __name__ == "__main__":
    main()
