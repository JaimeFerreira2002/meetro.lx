# server — the interpolation service

FastAPI service that polls the Metro Lisboa API, estimates live train positions from
wait times, and streams them to clients. Also serves a Leaflet debug map at `/`.

**Documentation lives in [`docs/`](../docs/README.md):**

- **[ARCHITECTURE.md](../docs/ARCHITECTURE.md)** — how positions are inferred from an
  API that never reports them, and why this server is stateful
- **[SERVER.md](../docs/SERVER.md)** — every module in `app/`, explained
- **[DEVELOPMENT.md](../docs/DEVELOPMENT.md)** — setup and troubleshooting
- **[API.md](../docs/API.md)** — Metro's upstream API
- **[DEPLOY.md](../docs/DEPLOY.md)** — Fly.io

## Run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env      # paste ML_BASIC_AUTH from api.metrolisboa.pt/store
uvicorn app.main:app --reload
```

<http://localhost:8000/> for the debug map. Without valid credentials the process
won't start — it calls Metro during startup.

## Routes

| Route | Purpose |
|---|---|
| `GET /health` | Liveness, station count, trains tracked, line statuses |
| `GET /stations` | Station catalog (id, name, lat, lon, lines) |
| `GET /lines` | Per-line operational status |
| `GET /trains` | One-shot snapshot of positioned trains |
| `GET /stream` | SSE feed, pushed every ~1.5 s |
| `GET /station/{id}/arrivals` | Upcoming trains at one stop |
| `GET /track` | Baked OSM track geometry (GeoJSON) |

`TrainPosition` is the contract, defined in [`app/models.py`](app/models.py) and
mirrored in [`app/lib/models.dart`](../app/lib/models.dart). **Changing one means
changing the other** — nothing checks that they agree.

## Docker

```bash
docker build -t metro-ar-server . && docker run --env-file .env -p 8000:8000 metro-ar-server
```

This local Dockerfile can't reach `../data`, so the image ships without track geometry
and falls back to straight-line interpolation. The **root** `Dockerfile` is the one Fly
uses; it builds from the repo root and includes `data/`.

## Known limits

Covered in full at
[ARCHITECTURE.md § Where it's wrong](../docs/ARCHITECTURE.md#where-its-wrong):
topology is learned from the feed (so a cold start is briefly dumb), trains near a
terminus can sit at their next station, depth is a hardcoded 20 m, and there's no
fallback simulator for when the API is down.
