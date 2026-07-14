# Metro Lisboa AR — Planning

Mobile AR app that overlays live Lisbon Metro trains in 3D space through the phone camera, using the official Metro Lisboa `EstadoServicoML` API.

**Status:** Phase 0 spike PASSED against the live API (2026-07-14). Interpolation
premise confirmed. See §8 for locked decisions (Flutter / iOS-first / monorepo).

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
*Spike-confirmed:* the feed effectively hands each train's full forward itinerary — one
`comboio` seen at up to 15 consecutive stations with monotonic `tempoChegada` (seconds
to arrival). Measured 100% multi-station visibility, no ID flicker, real-time countdown.

Confirmed response schema (per platform entry): `stop_id`, `cais`, `hora`
(`YYYYMMDDhhmmss`), `destino` (numeric code → resolve via `infoDestinos`), `sairServico`,
and up to three upcoming trains `comboio{,2,3}` / `tempoChegada{1,2,3}` (seconds; `--` when
empty). Auth: `client_credentials` → `https://api.metrolisboa.pt:8243/token`. TLS cert is
valid but some Python trust stores need `certifi`/`--insecure` (curl works without `-k`).

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

### Backend (Phase 1) components — FastAPI

The client does zero interpolation; it just renders positions from the stream.

1. **Poller** — single background task. Holds/refreshes the OAuth token (~1 h expiry),
   polls `/tempoEspera/Linha/{4 lines}` every ~10–15 s, handles the TLS quirk.
2. **Static reference** (loaded once, refreshed rarely): station catalog + GPS from
   `/infoEstacao/todos`; OSM track polylines per line/direction (baked GeoJSON in
   `data/`); line station-order; `destino` code map from `/infoDestinos/todos`.
3. **Train registry** — per-`comboio` state across polls (itinerary, line, direction,
   destino, last-seen); handles appear/vanish and terminus turnarounds.
4. **Position estimator** — next station = min ETA; consecutive ETAs give forward
   segment times; station-behind from line topology; position = Shapely arc-length
   interpolation along the polyline by `1 − eta_next/segment_time`; outputs
   `lat, lng, bearing, speed`; learns segment times over time. Depth ≈ constant offset.
5. **Motion smoother** — advances trains by `speed × elapsed` between polls, re-syncs
   with a constant-velocity filter so they glide and never jump backward.
6. **Fallback simulator** — when `tempoEspera` is down but `estadoLinha` is Ok, spawn
   synthetic trains at scheduled `infoIntervalos` headways.

**Client API:** `GET /health`, `GET /stations`, `GET /lines`, `GET /trains`,
`WS /stream` (or SSE) pushing `{trainId, line, lat, lng, depth, bearing, speedMps,
nextStation, etaSeconds}` ~every 1–2 s, `GET /track/{line}`.
**Stack:** FastAPI + uvicorn, `httpx` async polling, Pydantic, Shapely for geometry;
in-memory state (no DB for MVP); Dockerized, runs 24/7 as one instance.

## 4. Mobile client — Flutter, iOS-first

**Flutter/Dart shell + a native AR platform view.** The one hard requirement is
VPS-grade geospatial anchoring (pin a train to a real lat/lng through the camera); plain
GPS+compass drifts too much. That capability is **not** available as a pure-Dart plugin:

- ARKit's own geo-anchors (`ARGeoTrackingConfiguration`) do **not** cover Lisbon
  (US-cities + London list). Google's **ARCore Geospatial API** (Street View VPS, ~1 m)
  does, and runs on iOS via the *ARCore SDK for iOS*, but no Flutter plugin exposes it.
- So: Dart owns the app shell, 2D map, feed client, and UI; the **camera viewport is a
  native `UiKitView`** (ARKit + `ARCore/Geospatial` pod, SceneKit/RealityKit render)
  bridged via a Method/EventChannel. iOS-first ⇒ write the Swift module first; the
  Android ARCore module (Kotlin) comes later behind the same Dart interface.
- Tradeoff: Flutter's single-codebase benefit covers ~80% of the app but **not** the AR
  view (native Swift now, native Kotlin later). Testing AR needs a physical A12+ iPhone.

### AR UX ("x-ray view")
- Trains rendered 20–40 m below street level: darkened ground plane, glowing
  line-colored tunnel tubes, moving train models, depth-fog (deeper = dimmer).
- Station pins with name + live "next train in m:ss".
- 2D top-down live map as fallback/debug mode (usable indoors, non-ARCore devices).
- Tap a train → line, destination, next station, ETA.

## 5. Roadmap

- **Phase 0 — Feasibility spike. ✅ DONE (2026-07-14).** `spike/capture.py` +
  `analyze.py` validated the interpolation premise against live data (see §1/§8).
  Remaining sub-task: export OSM track geometry and sanity-check against station coords.
- **Phase 1 — Interpolation service + 2D live map (~1 week).** FastAPI backend (§3) +
  Flutter 2D Mapbox map with live train dots (pure Dart, shared feed client, doubles as
  fallback/indoor mode). Ground truth: stand on a platform, watch the dot arrive.
- **Phase 2 — AR client MVP (~2–3 weeks).** Flutter shell + native iOS Geospatial AR
  module. Static content first (station pins, tunnel tubes), then live feed, then x-ray
  polish. iOS first; Android ARCore module later.
- **Phase 3 — Polish.** Schedule-fallback simulation, wait-time panels, onboarding,
  battery management, offline track data.

## 6. Risks (ranked)

1. **API reliability** — historically flaky wait times. Phase 0 answers this.
2. **Train ID stability** — if `comboio` IDs aren't consistent across stations/polls,
   interpolation degrades to headway guessing. Phase 0 answers this.
3. **AR alignment** — VPS degrades in narrow streets; underground x-ray rendering is
   forgiving of a few meters of error.
4. **Rate limits** — undisclosed; single-poller proxy contains the blast radius.

## 7. Repo layout — single monorepo

One repo, folder per component. Each folder keeps its own toolchain and deploys
independently (monorepo ≠ coupled deploys); the shared wire contract (train-position
schema) is the reason to keep them together while solo/early.

```
metro-lisboa-ar/
├── PLANNING.md      # this file
├── spike/           # Phase 0: data capture + analysis (Python)      ✅
├── server/          # Phase 1: FastAPI interpolation service (Python) → VPS/Fly/Railway
├── data/            # shared: baked OSM track GeoJSON, station catalog
└── app/             # Phase 2: Flutter app + native iOS Swift AR module → TestFlight
```

## 8. Decisions

- **Mobile: Flutter, iOS-first** — Dart shell + native iOS AR platform view using ARCore
  Geospatial VPS (ARKit geo-anchors don't cover Lisbon; no Flutter VPS plugin). §4.
  Supersedes the earlier Unity / Android-first recommendation.
- **Monorepo** — frontend + backend + data in one repo; split later via `git filter-repo`
  only if it grows a team or CI configs conflict. §7.
- **Backend is mandatory** — holds the OAuth secret, single shared poller, owns the
  interpolation state machine. §3.
- **Spike verdict: VIABLE** — real-time feed with full forward itineraries; interpolation
  can start without a learning phase. §1.
