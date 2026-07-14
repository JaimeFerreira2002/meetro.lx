# metro-lisboa-ar

Mobile AR app that overlays live Lisbon Metro trains in 3D space through the phone
camera. Train positions are interpolated from the official Metro Lisboa
[`EstadoServicoML` API](https://api.metrolisboa.pt/store/apis/info?name=EstadoServicoML&version=1.0.1&provider=admin)
wait-time data — the API has no position endpoint, but the same train ID appears at
multiple stations with decreasing ETAs, which is enough to place it on the track.

See [PLANNING.md](PLANNING.md) for the full design, architecture, and roadmap.

## Status: Phase 0 — feasibility spike

Before building anything, validate the interpolation premise against real data:

1. Subscribe to `EstadoServicoML` at the [API store](https://api.metrolisboa.pt/store/)
   and generate credentials.
2. `cp spike/.env.example spike/.env` and fill in the credentials.
3. Capture at least an hour of live data (during metro operating hours):

   ```bash
   python3 spike/capture.py --interval 20 --duration 3600
   ```

4. Analyze it:

   ```bash
   python3 spike/analyze.py spike/captures/tempo_espera_*.jsonl
   ```

The analysis reports API liveness, train-ID stability, multi-station visibility
(the interpolation prerequisite), and ETA countdown quality — and gives a
viable / at-risk verdict.

## Planned layout

```
spike/    Phase 0 — data capture + analysis (no dependencies, stdlib only)
server/   Phase 1 — FastAPI interpolation service + 2D live map
data/     baked OSM track geometry, station catalog
app/      Phase 2 — Unity AR client (ARCore Geospatial)
```
