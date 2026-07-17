# meetro

Live Lisbon Metro trains on a map — and, later, overlaid through the phone camera in AR.

Train positions come from the official Metro Lisboa
[`EstadoServicoML` API](https://api.metrolisboa.pt/store/apis/info?name=EstadoServicoML&version=1.0.1&provider=admin),
which **has no train-position endpoint**. It reports wait times per platform. Because
the same train ID appears at up to 15 stations ahead with rising ETAs, each train is
effectively broadcasting its own itinerary — enough to place it on the track and watch
it move. [How that works →](docs/ARCHITECTURE.md)

Unofficial, and not affiliated with Metropolitano de Lisboa.

## Documentation

**[docs/](docs/README.md)** — start with [ARCHITECTURE.md](docs/ARCHITECTURE.md).

| | |
|---|---|
| [ARCHITECTURE](docs/ARCHITECTURE.md) | How it works and why it's built this way |
| [DEVELOPMENT](docs/DEVELOPMENT.md) | Run it, ship it, and the errors you'll hit |
| [SERVER](docs/SERVER.md) · [APP](docs/APP.md) · [WIDGET](docs/WIDGET.md) | Module by module |
| [API](docs/API.md) | Metro's API, live-verified |
| [SECURITY](docs/SECURITY.md) · [LEGAL](docs/LEGAL.md) | What's exposed, what's unresolved |

## Quick start

```bash
# Server — needs Metro API credentials (free, api.metrolisboa.pt/store)
cd server
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # paste ML_BASIC_AUTH
uvicorn app.main:app --reload # then http://localhost:8000/ for the debug map

# App
cd app
flutter pub get
flutter run --dart-define=API_BASE=http://localhost:8000
```

`--dart-define=API_BASE` is **not optional** — it's compiled in, and the default
(`localhost`) means "this phone" on a device. Full setup in
[DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Layout

```
server/   FastAPI — polls Metro every 12 s, estimates positions, streams over SSE
data/     Baked OSM tunnel geometry + build script
app/      Flutter client (lib/) + iOS home-screen widget (ios/MetroWidget/)
docs/     Documentation
```

## Status

Working end to end: the server runs on Fly, the app runs on a real iPhone, the widget
shows the next trains at your closest station, and it speaks English and Portuguese.

Not done: the AR view ([PR #11](https://github.com/JaimeFerreira2002/metro-lisboa-ar/pull/11),
parked), a square app icon, and the unresolved items in
[LEGAL.md](docs/LEGAL.md) — which block publishing, not personal use.

See [PLANNING.md](PLANNING.md) for the original design and roadmap.
