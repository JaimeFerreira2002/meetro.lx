# Legal — open risks

> **Not legal advice.** This is an engineer's inventory of what's unresolved, written
> so the risks are visible instead of forgotten. Anything here that matters needs a
> lawyer before meetro is published.

None of this blocks personal use on your own phone. All of it blocks the App Store.
The checklist form lives in [APP_STORE.md](APP_STORE.md); this is the *why*.

| Risk | Severity | Status |
|---|---|---|
| Metro API terms for a published app | **High** | Unverified |
| Metro's logo + line pictograms in-app | **High** | Open |
| CARTO / Nominatim at production volume | Medium | Open |
| OSM data licence (ODbL) on `data/` | Medium | Unexamined |
| Privacy policy + Terms are drafts | Medium | Open |
| The name "meetro" | Low | Judgement call |

---

## Metro Lisboa's API terms

**The biggest external risk, and the one entirely outside our control.**

`EstadoServicoML` is offered through a public API store with free registration. What's
never been checked is whether the terms permit **redistributing** that data through a
published, third-party app — as opposed to personal or experimental use. Providing an
API publicly is not the same as licensing its output for republication.

Everything meetro does rests on this. If the answer is no, there is no product — no
amount of engineering routes around it. It's cheap to ask and expensive to assume, and
it should be settled **before** further investment, not before submission.

Worth noting in our favour: we poll 4 requests per 12 seconds regardless of user count,
and never expose their API to clients. We are a light, well-behaved consumer.

## Their logo and pictograms

meetro currently shows:

- the **Metro de Lisboa logo**, persistently, bottom-left on the map;
- the **official line pictograms** (the Azul/Amarela/Verde/Vermelha marks) throughout
  the UI.

Both are Metropolitano de Lisboa's trademarks. Using them isn't automatically wrong —
they identify a real thing the app is about — but *persistent, prominent* placement
reads as endorsement, and **our own Terms explicitly disclaim being official**. The app
contradicts itself.

A common middle ground: keep their logo in **About & credits**, next to "Data provided
by Metropolitano de Lisboa", and drop it from the map. Pictograms are the harder call —
they're genuinely the clearest way to show a line, and users read them instantly, but
they're still marks.

The good news is the palette in [`models.dart`](../app/lib/models.dart) is *our* copy of
the colours; colours alone aren't protectable the way the marks are. If the pictograms
have to go, coloured dots and names still work.

Already fixed: the bundle ID used to be `pt.metrolisboa.metroLisboaAr` — the reverse-DNS
of *their* domain, which asserted ownership of a namespace we don't own. Now
`com.jaimeferreira.meetro`. The map tile User-Agent had the same problem.

## Tiles and geocoding

**CARTO basemaps** and **OSM Nominatim** are used with no API key, on free public
endpoints. Both are fine for development and neither is licensed for a shipped app
with real traffic:

- CARTO's free raster tiles aren't a production licence. Real usage needs a paid plan
  or self-hosting.
- Nominatim's usage policy is explicit about bulk/production use, and expects a real
  User-Agent. Ours says `metro-lisboa-ar/0.1` — honest, but stale versus the brand.

This isn't a lawsuit risk so much as a **rate-limit risk**: the failure mode is being
blocked, and the app degrading, on the day it gets popular. Budget for a tile plan and
a geocoding provider before any launch.

## OSM data licence (ODbL)

**Not yet examined, and worth an hour.**

`data/track_geometry.geojson` is derived from OpenStreetMap subway relations. OSM data
is licensed **ODbL**, which is share-alike for databases — unlike the map *tiles*, which
are a different question. We attribute OpenStreetMap, which ODbL requires. What hasn't
been checked is whether serving that derived geometry from `/track`, and bundling it in
an app, triggers the share-alike obligation on the derived database.

Plausibly fine — the repo is public and the file is right there — but "plausibly fine"
is doing a lot of work in a sentence about a copyleft licence.

## The drafts

[PRIVACY.md](PRIVACY.md) and [TERMS.md](TERMS.md), and their in-app copies in
[`legal.dart`](../app/lib/legal.dart), are **drafts with `[DATE]` and `[CONTACT]` still
in them**. They're honest about what the app does — that's the hard part, and it's
done — but they're unreviewed and unhosted.

Required for submission: the privacy policy at a **public URL** (App Store Connect asks
for one), placeholders filled, a real contact address.

Note the text exists in two places — `docs/` and `legal.dart` — and nothing keeps them
in sync. Change one, change the other.

## The name

**meetro** is a judgement call, not a known problem. It's distinct enough not to claim
to *be* Metro, and it doesn't use their wordmark. But it's one letter from "metro" in a
market where Metropolitano de Lisboa is the incumbent, and it's applied to an app about
their network. A trademark search before you print stickers is cheap insurance.

---

## What actually blocks the App Store

In order:

1. **Confirm the API terms.** Everything else is moot if this fails.
2. **Resolve the logo/pictogram question** — or accept the risk knowingly.
3. Get the privacy policy reviewed and hosted; fill the placeholders.
4. Move off free CARTO/Nominatim, or accept being rate-limited.
5. Enrol in the Developer Program ($99/yr) — also what ends the 7-day rebuild cycle.
6. Work [APP_STORE.md](APP_STORE.md).

Nothing on this list is urgent for an app that only runs on your own phone. All of it
is blocking the moment anyone else installs it.
