# data — baked static assets

## `track_geometry.geojson`

One `LineString` per line + direction (8 total) for the Lisbon Metro, from
OpenStreetMap. The server loads this for arc-length interpolation so trains follow
the real curved tunnels instead of straight lines between stations.

Properties per feature: `line` (Amarela/Azul/Verde/Vermelha), `from`, `to` (direction
termini), `colour`, `gaps` (way-stitch discontinuities; currently 0 on all).

### Rebuild

```bash
python3 data/build_track_geometry.py            # fetch fresh from Overpass
python3 data/build_track_geometry.py --raw dump.json   # from a cached Overpass dump
```

The script fetches the 8 `route=subway` relations for Lisbon, stitches each relation's
ordered track ways into a single oriented polyline (`from → to`), and writes the GeoJSON.
Stitched with 0 gaps; lengths match the network (Amarela 11 km, Azul 14 km, Verde 9 km,
Vermelha ~10.5 km). Stdlib-only, no dependencies.
