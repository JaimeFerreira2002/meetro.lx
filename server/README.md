# server — interpolation service (Phase 1)

FastAPI service that polls the Metro Lisboa API, interpolates live train positions
from wait times, and serves them to clients + a 2D debug map.

## Run locally

```bash
cd server
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then paste ML_BASIC_AUTH
uvicorn app.main:app --reload
```

Then open <http://localhost:8000/> for the live debug map, or hit the API:

| Route | Purpose |
|---|---|
| `GET /health` | liveness, station count, trains tracked, line statuses |
| `GET /stations` | station catalog (id, name, lat, lon, lines) |
| `GET /lines` | per-line operational status |
| `GET /trains` | one-shot snapshot of positioned trains |
| `GET /stream` | SSE feed pushing the snapshot every ~1.5 s |

Snapshot item: `{train_id, line, destino, destino_name, next_stop, next_stop_name,
eta_seconds, lat, lon, bearing, speed_mps, depth_m, progress}`.

## Docker

```bash
docker build -t metro-ar-server . && docker run --env-file .env -p 8000:8000 metro-ar-server
```

## v0 limitations (tracked for later)

- **Geometry:** trains now follow the real curved track via arc-length interpolation
  along baked OSM polylines (`app/track.py`, `data/track_geometry.geojson`). `app/geo.py`
  straight-line interpolation remains the fallback when a line's geometry is missing.
- **Topology (station-behind) is learned from the feed**, so a train can briefly sit at
  its next station until a train behind it reveals the predecessor. A static per-line
  ordering in `data/` would remove the warm-up.
- **Depth is a constant 20 m**; per-station depths later.
- Schedule-based fallback simulator (API-down case) not yet wired.
