# Security

What meetro holds, what it exposes, and what's currently wrong. This is a personal
project with one production machine and no users yet — the point of writing it down is
that "no users yet" stops being true without warning.

- [Secrets](#secrets)
- [Open issues](#open-issues)
- [The public API surface](#the-public-api-surface)
- [Location and personal data](#location-and-personal-data)
- [Third parties](#third-parties)
- [If a credential leaks](#if-a-credential-leaks)

---

## Secrets

There is exactly **one** secret in this system: the Metro Lisboa API credential
(`ML_BASIC_AUTH`, or the key/secret pair it encodes). Everything else is public data.

**Where it lives**

| Where | How |
|---|---|
| Your machine | `server/.env` — gitignored (`.gitignore:2`), verified never committed |
| Production | A Fly secret (`fly secrets set`), injected as an env var |
| The app | **Nowhere.** The phone never sees it |

**Why the app doesn't have it.** The client talks only to our server; the server talks
to Metro. Anything shipped in an app binary is readable by anyone who downloads it —
`--dart-define` values included. They are compiled in, not encrypted. If the phone
called Metro directly, the credential would be public the day we shipped, and Metro's
load would scale with our users.

**Rotation.** Regenerate the consumer key/secret at
[api.metrolisboa.pt/store](https://api.metrolisboa.pt/store), then update `server/.env`
and `fly secrets set ML_BASIC_AUTH=...`. Nothing else needs touching, and no client
build is affected. Rotation is cheap here — do it whenever there's doubt.

## Open issues

### TLS verification is off by default

**Status: open. This is the real one.**

[`config.py`](../server/app/config.py) declares:

```python
insecure_tls: bool = True
```

and [`metro_client.py`](../server/app/metro_client.py) does `verify = not settings.insecure_tls`.
So **every HTTPS call to Metro runs with certificate verification disabled** — including
the `POST /token` request that carries the Basic credential.

That means the server does not check it's talking to Metro at all. Anyone able to
intercept the connection between our Fly machine in `cdg` and Metro's gateway could
present any certificate, and we'd hand them the credential. That's not a likely attack
on a datacentre network path — but it's the exact attack TLS verification exists to
stop, and it's disabled.

**How it got here:** Homebrew Python on macOS doesn't trust Metro's issuer, so local
development failed with `CERTIFICATE_VERIFY_FAILED` while `curl` worked. The workaround
became the **default** rather than a local override, so it shipped.

**The fix** is to default it to `False`, let developers opt in via `ML_INSECURE_TLS=true`
locally, and check whether the Debian-based production image needs it at all — it very
likely doesn't, since `python:3.12-slim` uses a normal CA bundle. Deliberately not fixed
in the documentation change that discovered it.

### No auth or rate limiting on our API

**Status: open, low severity.**

Every endpoint on `metro-lisboa-ar.fly.dev` is public and unauthenticated. Anyone can
open `/stream` and hold it.

It's mild, because of the architecture: `/stream` reads our in-memory registry, so no
amount of client traffic increases load on *Metro*. Abuse costs us Fly CPU and bandwidth
on a 512 MB shared machine, not our standing with the data provider. Worst realistic
case is our own machine falling over.

Worth revisiting before any real launch — every SSE client gets its own `snapshot()`
call every 1.5 s, so concurrent viewers are the scaling limit.

### The debug map is public

**Status: open, accepted.**

`GET /` serves the Leaflet debug map at `metro-lisboa-ar.fly.dev` to anyone. It exposes
nothing that `/stream` doesn't, and it's genuinely useful for checking production. But
it's an unbranded developer tool sitting on a public URL — worth gating or removing
before launch, if only for appearances.

## The public API surface

Everything served is **derived from public transit data**. There are no user accounts,
no user data, and nothing to leak:

| Route | Exposes |
|---|---|
| `/health` | Station count, trains tracked, line statuses |
| `/stations`, `/lines`, `/track` | Public reference data |
| `/trains`, `/stream` | Estimated train positions |
| `/station/{id}/arrivals` | Upcoming trains at a stop |
| `/` | The debug map |

No CORS middleware is configured, so browsers can't call the API cross-origin. The
Flutter app isn't a browser and isn't affected. If a web client is ever built, this
becomes a deliberate decision rather than an accident.

## Location and personal data

**The server has never seen a user's location.** It has no idea who's connected.

Location is used on-device only, for the Nearby panel and the widget's "closest
station". It's read via `geolocator`, kept in memory, and never transmitted. Favourite
stations are stop IDs in `SharedPreferences` — local, not synced.

The widget declares `NSWidgetWantsLocation` so it can find your closest station on the
home screen. Same rule: it resolves the station on-device and asks our API about *that
station*, never about you.

The one exception is [`geocode()`](../app/lib/metro_api.dart) — typing in the search box
sends your query text to OpenStreetMap's Nominatim. That's a third party receiving user
input, and it's why Nominatim appears in [PRIVACY.md](PRIVACY.md). It's search text, not
location, and only when you type.

For App Store privacy labels: **Precise Location**, used for *App Functionality*, **not**
linked to identity, **not** used for tracking.

## Third parties

| Service | Gets | Risk |
|---|---|---|
| Metro Lisboa | Our credential, 4 req/12 s | Terms unverified for a published app — [LEGAL.md](LEGAL.md) |
| Fly.io | Hosts the server + secret | Standard |
| CARTO | Tile requests from every user | Free tier not licensed for production |
| Nominatim | Search text | Usage policy; not licensed for production volume |
| OpenStreetMap | One-off Overpass fetch, baked into `data/` | None at runtime |

CARTO and Nominatim are the ones that bite at scale: they're free for development, not
for a shipped app with real traffic. See [LEGAL.md](LEGAL.md).

## If a credential leaks

1. **Rotate first**, at the API store. Don't investigate first.
2. Update `server/.env` and `fly secrets set ML_BASIC_AUTH=...`.
3. If it reached git, rotating is the fix — `git rebase`/`filter-branch` doesn't help
   once it's pushed, and forks and clones keep the old object.

Treat a credential pasted into any chat, issue, or terminal recording as leaked. It
costs nothing to rotate.
