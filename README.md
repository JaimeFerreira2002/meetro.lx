# metro-lisboa-ar

Mobile AR app that overlays live Lisbon Metro trains in 3D space through the phone
camera. Train positions are interpolated from the official Metro Lisboa
[`EstadoServicoML` API](https://api.metrolisboa.pt/store/apis/info?name=EstadoServicoML&version=1.0.1&provider=admin)
wait-time data — the API has no position endpoint, but the same train ID appears at
multiple stations with decreasing ETAs, which is enough to place it on the track.

See [PLANNING.md](PLANNING.md) for the full design, architecture, and roadmap.

## Status

The interpolation premise was validated against live data, and the Phase 1 backend
is built. To run it, see [server/README.md](server/README.md):

```bash
cd server
python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
cp .env.example .env   # then paste ML_BASIC_AUTH from the API store
./.venv/bin/uvicorn app.main:app --port 8000
```

Then open <http://localhost:8000/> for the live 2D map.

## Layout

```
server/   Phase 1 — FastAPI interpolation service + SSE feed + 2D debug map
data/     baked OSM track geometry + build script
app/      Phase 2 — Flutter client (2D map now; native iOS AR view later)
```
