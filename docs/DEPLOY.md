# Deploying the backend to Fly.io

Gives the interpolation service a stable **HTTPS** URL so the iPhone app works
anywhere (not just on your home Wi-Fi). Config lives at the repo root:
`Dockerfile`, `fly.toml`, `.dockerignore`.

## One-time

```bash
# 1. Install the CLI and log in (opens a browser)
brew install flyctl
fly auth login          # or: fly auth signup

# 2. From the repo root — reuse the committed fly.toml, pick a unique app name
cd ~/Desktop/metro-lisboa-ar
fly launch --no-deploy   # confirm region 'mad' (Madrid), do NOT add Postgres/Redis

# 3. Set the API credential as a secret (NOT baked into the image)
fly secrets set ML_BASIC_AUTH=<your base64 blob from the API store>

# 4. Deploy
fly deploy
```

Then verify:

```bash
fly open              # opens https://<app>.fly.dev/  (the debug map)
curl https://<app>.fly.dev/health
```

## Point the app at it

Build the iOS app against the deployed URL:

```bash
cd app
flutter run --release -d <iphone> --dart-define=API_BASE=https://<app>.fly.dev
```

## Redeploy after changes

```bash
fly deploy            # from repo root
```

## Notes

- **Always-on:** the app runs a continuous poller and long-lived SSE streams, so
  `fly.toml` keeps one machine running (`min_machines_running = 1`,
  `auto_stop_machines = false`). This means a **small ongoing cost** (~a few $/mo
  for one `shared-cpu-1x` / 512 MB machine).
- **Region:** `mad` (Madrid) is Fly's closest region to Lisbon — lowest latency to
  the Metro API and to users in Portugal.
- **Secret hygiene:** `ML_BASIC_AUTH` is a Fly secret; `server/.env` is git- and
  docker-ignored so it never ships in the image.
- **Track geometry** is baked into the image (`data/track_geometry.geojson`), so
  trains follow the real tunnels in production too.
- **Tiles/geocoding:** still the free CARTO/Nominatim endpoints — fine for a
  prototype, but see `docs/APP_STORE.md` before scaling to real traffic.
```
