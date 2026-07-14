# Metro Lisboa AR — Planning

Mobile AR app that overlays live Lisbon Metro trains in 3D space through the phone camera, using the official Metro Lisboa `EstadoServicoML` API.

## 1. The API

Base: `https://api.metrolisboa.pt:8243/estadoServicoML/1.0.1`
Auth: OAuth2 bearer token (client-credentials against the WSO2 store subscription).

| Endpoint | Data |
|---|---|
| `GET /tempoEspera/Estacao/{id}` / `/Linha/{linha}` / `/Estacao/todos` | Next-train wait times per platform: train IDs (`comboio`, `comboio2`, `comboio3`), arrival countdowns, platform (`cais`), `destino` |
| `GET /infoEstacao/todos` | All stations with GPS coordinates and IDs |
| `GET /estadoLinha/{linha}` / `/todos` | Line operational status (Amarela, Azul, Verde, Vermelha) |
| `GET /infoIntervalos/{linha}/{dia}/{hora}` | Scheduled headways by day type and time |
| `GET /infoDestinos/todos` | Destination catalog |

**No train-position endpoint exists.** Positions are derived: the same physical train ID
appears in the wait lists of multiple stations down the line with increasing ETAs.

**No track geometry in the API** — only station points. Tunnel polylines come from
OpenStreetMap (one-time Overpass export → baked GeoJSON in `data/`), cross-checked
against `infoEstacao` GPS coords.

**Reliability warning:** store comments report the wait-time endpoints going down for
long stretches. Design degrades to schedule-based simulation (`infoIntervalos`) when
real-time data is missing.

## 2. Position interpolation

1. Poll `/tempoEspera/Linha/{linha}` for all 4 lines every 15–30 s.
2. Group entries by train ID → each train yields a sorted list of (station, ETA) pairs.
3. Next station = min-ETA station; direction disambiguated by `destino` + platform.
4. Position = arc-length interpolation along the track polyline between previous and
   next station, scaled by ETA vs. learned segment travel time.
5. Constant-velocity smoothing so trains never jump backward between polls.
6. Observed station-to-station times continuously refine the travel-time table.
7. Fallback: if `tempoEspera` is down but `estadoLinha` says the line runs, spawn
   simulated trains at scheduled headways.

## 3. Architecture

```
Metro Lisboa API ──poll 15–30s──> Interpolation service ──WebSocket/SSE──> Mobile AR client
                                  (FastAPI)                 {trainId, line, lat, lng,
                                  - holds the API secret     depth, bearing, speedMps}
                                  - single poller, cache     snapshots ~every 2 s;
                                  - train registry +         client animates between them
                                    estimator + smoothing
```

Backend proxy is mandatory: the OAuth secret can't ship in a mobile binary, one poller
serves all users under unknown rate limits, and the interpolation state machine belongs
in one place.

## 4. Mobile client

**Recommended: Unity + AR Foundation + Google ARCore Geospatial API.**
- Geospatial API = VPS-grade (~1 m) world anchoring, works in Lisbon, Android + iOS.
- Native ARKit geo-tracking is NOT available in Lisbon; RN/Flutter AR plugins immature.

### AR UX ("x-ray view")
- Trains rendered 20–40 m below street level: darkened ground plane, glowing
  line-colored tunnel tubes, moving train models, depth-fog (deeper = dimmer).
- Station pins with name + live "next train in m:ss".
- 2D top-down live map as fallback/debug mode (usable indoors, non-ARCore devices).
- Tap a train → line, destination, next station, ETA.

## 5. Roadmap

- **Phase 0 — Feasibility spike (1–2 days).** Subscribe on the API store, capture an
  hour of `tempoEspera` data (`spike/capture.py`), run `spike/analyze.py`. Validates:
  train ID stability across polls/stations, ETA granularity, whether data is live at
  all. Also export OSM track geometry and sanity-check against station coords.
  **This validates or kills the interpolation premise.**
- **Phase 1 — Interpolation service + 2D live map (~1 week).** FastAPI poller, train
  registry, position estimator, SSE feed; Mapbox debug page with live train dots.
  Ground truth for accuracy: stand on a platform, watch the dot arrive with the train.
- **Phase 2 — AR client MVP (~2–3 weeks).** Unity + ARCore Geospatial. Static content
  first (pins, tunnel tubes), then live feed, then x-ray polish. Android first.
- **Phase 3 — Polish.** Schedule-fallback simulation, wait-time panels, onboarding,
  battery management, offline track data.

## 6. Risks (ranked)

1. **API reliability** — historically flaky wait times. Phase 0 answers this.
2. **Train ID stability** — if `comboio` IDs aren't consistent across stations/polls,
   interpolation degrades to headway guessing. Phase 0 answers this.
3. **AR alignment** — VPS degrades in narrow streets; underground x-ray rendering is
   forgiving of a few meters of error.
4. **Rate limits** — undisclosed; single-poller proxy contains the blast radius.

## 7. Repo layout (target)

```
metro-lisboa-ar/
├── PLANNING.md      # this file
├── spike/           # Phase 0: data capture + analysis
├── server/          # Phase 1: FastAPI interpolation service
├── data/            # baked track GeoJSON, station catalog
└── app/             # Phase 2: Unity AR client
```
