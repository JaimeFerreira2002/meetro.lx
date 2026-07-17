# Development

Everything needed to run meetro from a clean machine, plus the failures we actually
hit and why they happen.

- [What you need](#what-you-need)
- [The server](#the-server)
- [The app](#the-app)
- [On a real iPhone](#on-a-real-iphone)
- [Deploying the server](#deploying-the-server)
- [Rebuilding track geometry](#rebuilding-track-geometry)
- [Troubleshooting](#troubleshooting)

---

## What you need

| Tool | Version used | For |
|---|---|---|
| Python | 3.12+ (3.14 locally, 3.12-slim in Docker) | server |
| Flutter | 3.44 stable | app |
| Xcode | 16.1 | iOS builds, the widget |
| Docker | any recent | optional; how Fly builds |
| An Apple ID | free tier works | signing to a device |

You also need **Metro API credentials** — a free account at
[api.metrolisboa.pt/store](https://api.metrolisboa.pt/store), subscribe to
`EstadoServicoML`, and copy the consumer key/secret. Nothing runs without them: the
server calls Metro during startup, so bad credentials mean the process won't boot.

## The server

```bash
cd server
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env      # paste ML_BASIC_AUTH — base64(consumerKey:consumerSecret)
uvicorn app.main:app --reload
```

`ML_BASIC_AUTH` is the pre-encoded blob; `ML_CONSUMER_KEY` + `ML_CONSUMER_SECRET`
works too. **`server/.env` is gitignored and must stay that way** — see
[SECURITY.md](SECURITY.md).

Then <http://localhost:8000/> is the debug map — a single Leaflet page, no build step,
and the fastest way to tell whether the server is healthy. `curl localhost:8000/health`
gives you the same answer in one line:

```json
{"status":"ok","stations":50,"trains_tracked":37,
 "lines":{"Amarela":"Ok","Azul":"Ok","Verde":"Ok","Vermelha":"Ok"}}
```

`trains_tracked: 0` with `lines: unknown` between 01:00 and 06:30 is **correct** — the
metro is shut. Judge liveness during service hours.

Give it a couple of poll cycles (~30 s) before judging positions: adjacency and segment
times are learned from the feed, so a cold server places trains badly at first.
[ARCHITECTURE.md](ARCHITECTURE.md#where-its-wrong) explains why.

## The app

```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE=http://localhost:8000
```

**The `--dart-define` is not optional.** `API_BASE` is compiled in, defaulting to
`http://localhost:8000`. That default is fine on a simulator and useless on a phone,
where `localhost` is the phone itself. Against production:

```bash
flutter run --dart-define=API_BASE=https://metro-lisboa-ar.fly.dev
```

Other targets: Android emulator reaches your host at `10.0.2.2`; a physical device on
your Wi-Fi needs your Mac's LAN IP.

```bash
flutter analyze          # ~56 style infos are pre-existing; errors/warnings are not
```

There is no test suite. `flutter analyze` plus a real build is the gate.

## On a real iPhone

No App Store, no TestFlight — a free Apple ID signs a build straight onto your device.

1. Plug in, unlock, trust the Mac.
2. **Xcode → Settings → Accounts →** add your Apple ID.
3. `flutter devices` — copy the device ID.
4. Build and install:

```bash
cd app
flutter run --release -d <device-id> --dart-define=API_BASE=https://metro-lisboa-ar.fly.dev
```

5. On the phone: **Settings → General → VPN & Device Management → Developer App → Trust**.
   The phone needs internet — iOS verifies the certificate online.

Both **Runner** and **MetroWidgetExtension** must be on the same team, or the build
fails in a confusing way (see below).

**Free-tier limits.** Provisioning profiles expire after **7 days** — when the app
stops launching, reinstall it. You get 10 App IDs per 7 days (meetro needs 2: app +
widget). Paid-only capabilities are unavailable — notably **App Groups**, the usual way
a widget shares data with its app. Ours doesn't need it; it calls the API directly.
TestFlight and the App Store need the $99/yr Developer Program.

To install a build you've already made without rebuilding:

```bash
xcrun devicectl device install app --device <device-id> build/ios/iphoneos/Runner.app
```

`flutter install` won't do here — it doesn't accept `--dart-define`, and its
`--use-application-binary` wants an IPA.

## Deploying the server

See [DEPLOY.md](DEPLOY.md). Briefly: Fly, one always-on machine in `cdg`.

```bash
fly deploy                                   # from repo root
fly secrets set ML_BASIC_AUTH=<blob>         # only needed once
fly logs
```

The root `Dockerfile` builds from the **repo root**, not `server/`, because the image
needs `data/track_geometry.geojson` and a Dockerfile can't reach outside its context.
It recreates the repo layout under `/srv` so the server's relative paths resolve.
`server/Dockerfile` is the other one — for `docker run` inside `server/`, without track
geometry.

The machine must never scale to zero. `auto_stop_machines = 'off'` and
`min_machines_running = 1` are deliberate: a stopped machine loses the registry's
learned state and stops polling.
[ARCHITECTURE.md](ARCHITECTURE.md#why-the-server-is-stateful) explains why.

Fly does **not** auto-deploy on merge — there's no GitHub Action. `fly deploy` is manual.

## Rebuilding track geometry

`data/track_geometry.geojson` is baked and committed. It only needs rebuilding if the
network changes:

```bash
python3 data/build_track_geometry.py             # fresh from Overpass
python3 data/build_track_geometry.py --raw dump.json
```

Stdlib only, no dependencies. It fetches the 8 `route=subway` relations for Lisbon and
stitches each one's ways into a single oriented polyline. Check the output reports **0
gaps** and plausible lengths (Amarela 11 km, Azul 14 km, Verde 9 km, Vermelha ~10.5 km)
— a stitching failure shows up as trains sliding through walls, not as an error.

---

## Troubleshooting

### `CERTIFICATE_VERIFY_FAILED` from Python, but `curl` works

Metro's gateway certificate is valid, but some trust stores — notably Homebrew Python
on macOS — don't have its issuer. `curl` uses the system store and succeeds; Python
uses its own and doesn't.

This is why `insecure_tls` exists in `config.py`. **It defaults to `True`, which
disables certificate verification everywhere, including production.** That's a real
problem, not a quirk — [SECURITY.md](SECURITY.md#tls-verification-is-off-by-default)
has the detail.

### Fly health checks fail, app won't boot

Almost always a **missing or wrong `ML_BASIC_AUTH`**. The server calls Metro during
`lifespan` startup; if that raises, the process never comes up, so `/health` never
answers and Fly reports a timeout. The logs have the real error:

```bash
fly logs -a metro-lisboa-ar
```

### "Unable to log in with account '<someone-else>'" when building for a device

The account named isn't the one you added — it's whoever owns the **`DEVELOPMENT_TEAM`
the project asks for**. Xcode looks up the team, then goes hunting for the account that
owns it.

This bites when Xcode rewrites the team on *one* target and leaves the others. Check
they agree:

```bash
grep DEVELOPMENT_TEAM app/ios/Runner.xcodeproj/project.pbxproj
```

All of Runner and MetroWidgetExtension's configs should show the same ID. Your team ID
is the `OU` field of your signing certificate:

```bash
security find-identity -v -p codesigning
```

### "Multiple commands produce .../MetroWidgetExtension.appex/Info.plist"

Xcode 16 made `MetroWidget/` a **file-system synchronized root group**: every file in
the folder is implicitly a target member. So the folder's `Info.plist` was being copied
as a *resource* while `INFOPLIST_FILE` also *processed* it — two commands, one output.

Fixed by moving the plist **out** of the synchronized folder
(`app/ios/MetroWidgetInfo.plist`). Don't move it back.

A related trap: those targets show **empty Sources and Resources build phases**. That's
normal for synchronized groups — membership is implicit. It does not mean the widget
has no code.

### Xcode build cycle involving "Thin Binary"

"Embed Foundation Extensions" must run **before** Flutter's "Thin Binary" phase. It's
already ordered correctly in the committed project; if a regenerated project reintroduces
it, that's the fix.

### The app runs but shows nothing / never connects

You almost certainly forgot `--dart-define=API_BASE=...`, so it's talking to itself. The
offline banner is the tell — the app distinguishes "can't reach the server" from "no
trains", so trust what it says.
