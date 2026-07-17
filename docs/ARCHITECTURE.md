# Architecture — how meetro actually works

If you read one document, read this one. It explains the central trick the whole
product rests on, and why the pieces are arranged the way they are.

- [The problem](#the-problem)
- [The trick](#the-trick)
- [Placing a train](#placing-a-train)
- [Making it glide](#making-it-glide)
- [Why the server is stateful](#why-the-server-is-stateful)
- [The whole data flow](#the-whole-data-flow)
- [Where it's wrong](#where-its-wrong)

---

## The problem

meetro shows live trains moving on a map. Metro de Lisboa's API — `EstadoServicoML`,
fully documented in [API.md](API.md) — **has no train-position endpoint**. It never
tells you where a train is. There is no GPS, no coordinate, no "train 29C is here".

So the map should be impossible. It isn't, because of what the API *does* give you.

## The trick

The API's core feed is **wait times**. You ask "what's coming to this platform?" and
it answers with up to three trains and their arrival times in seconds:

```
GET /tempoEspera/Linha/Azul   ->  one entry per platform
{ "stop_id": "AM", "comboio": "29C", "tempoChegada1": 37,
                   "comboio2": "14B", "tempoChegada2": 245, ... }
```

Read that as a departure board and it's a list of arrivals per station. **Turn it
inside out** — group by train ID instead of by station — and each train hands you its
own forward itinerary:

```
train 29C, heading to destino 54:
  Alameda      in   37 s
  Areeiro      in  134 s
  Roma         in  251 s
  Alvalade     in  372 s
  ...up to 15 stations ahead
```

That is the entire premise. The API is describing every train's next quarter-hour of
travel, station by station, several times a minute. It just isn't labelled that way.

The inversion is `Registry.ingest_line` in
[`server/app/registry.py`](../server/app/registry.py): walk every platform entry,
pull out all three train slots, and accumulate `{train_id: {stop: eta}}`. Sort each
train's stops by ETA and you have its itinerary, soonest first.

## Placing a train

An itinerary tells you where a train is *going*, not where it **is**. But the first
entry — the smallest ETA — is its **next stop**, and a train that arrives at Alameda
in 37 seconds is somewhere just short of Alameda. To turn that into a coordinate you
need three things.

**1. Which station is behind it.** The API never says. We learn it from the feed:
in an itinerary sorted by ETA, each consecutive pair `(a, b)` means *a comes before b*
for trains heading to this destination. Observe enough trains and you've reconstructed
the line's topology without ever being told it. That's `Registry._learn`.

Note it's keyed by **`destino`**, not line — direction matters. Alameda's predecessor
depends entirely on which way you're going.

**2. How long that segment takes.** Also learned, from the same pair: if `a` is 37 s
away and `b` is 134 s away, the `a → b` segment takes about 97 s. Each new observation
is folded into an exponential moving average, weighted 70% history / 30% new sighting,
which smooths out the noise in any single reading. Until a segment has been observed,
a 100 s default stands in (`default_segment_seconds`).

**3. How far along it is.** Now it's arithmetic. If the segment takes 97 s and the
train arrives in 37 s, it has 60 s behind it — it's **62% of the way across**:

```
progress = 1 − (eta_to_next / segment_seconds)
         = 1 − (37 / 97)
         = 0.62
```

Then `progress` is mapped onto real geometry. `data/track_geometry.geojson` holds the
actual tunnel path from OpenStreetMap as one polyline per line *per direction*.
[`track.py`](../server/app/track.py) projects both stations onto that polyline to get
their arc-lengths, walks 62% of the distance between them, and returns the point —
plus the bearing, so the train icon points the way it's moving. Trains follow the real
curves rather than cutting straight through the city.

## Making it glide

We poll Metro every **12 seconds**, but the app's SSE stream pushes a snapshot every
**1.5 seconds**. The extra frames aren't new data — they're the same data, re-read
against a later clock.

Every observation is stamped `captured_at`. `Registry.snapshot` starts by asking how
old it is and subtracting that from every ETA:

```python
dt = now - obs.captured_at
adjusted = [(stop, eta - dt) for stop, eta in obs.itinerary]
```

So a train captured 8 seconds ago with a 37 s ETA now reads 29 s — which raises
`progress`, which moves the dot. **The train keeps moving between polls because the
countdown keeps running.** Each poll then corrects the estimate against reality.

This is why it never jumps backwards: within a poll cycle, motion is a smooth function
of elapsed time. It's dead reckoning, and it's the difference between a map that
crawls in 12-second lurches and one that flows.

Trains unseen for **90 seconds** (`STALE_AFTER`) are pruned. That's also what empties
the map after the last train at 01:00 — the feed goes quiet, and 90 seconds later the
registry is empty.

## Why the server is stateful

This shapes every infrastructure decision, so it's worth being explicit.

**The registry's knowledge is accumulated.** Segment times are moving averages built
over many polls; topology is inferred from sightings. A process that starts cold knows
no adjacency and no segment times, and it takes a few polls of warm-up before positions
are good.

That rules out serverless. On Vercel or Lambda, each request is a fresh, short-lived
invocation with no shared memory and no background work between requests. There is
nowhere for the poller to live and nowhere for what it learned to persist. **That's
why this runs on Fly with `min_machines_running = 1` and `auto_stop_machines = 'off'`**
— a machine that scales to zero forgets everything and starts the warm-up again.

The second reason is manners: **one poller serves all users**. A thousand people
opening meetro is still 4 requests per 12 seconds to Metro's API, because they're
reading our registry, not Metro's. If clients called Metro directly, load would scale
with users and our credentials would have to ship inside the app. Both bad.

## The whole data flow

```
Metro Lisboa EstadoServicoML
        │  poller.py — every 12 s, 4 lines: wait times + line status
        │  (the only thing that talks to Metro; holds the OAuth token)
        ▼
   Registry  ──── learns: adjacency, segment times (EMA)
        │    ──── holds:  each train's latest itinerary + captured_at
        │
        │  snapshot(now) — subtract elapsed, find next stop,
        │  compute progress, place on track geometry
        ▼
   FastAPI  ── /stream  SSE, re-computed every 1.5 s   ← the live map
            ── /trains  one-shot snapshot
            ── /station/{id}/arrivals                  ← station panels, widget
            ── /stations, /lines, /track               ← fetched once at startup
            ── /                                        the debug map
        ▼
   Flutter app (app/lib) + iOS widget (app/ios/MetroWidget)
```

Startup order matters and is enforced by the FastAPI `lifespan` in
[`main.py`](../server/app/main.py): load the station catalog and destination names
from the API, load track geometry from disk, *then* start the poller. Reference data
must exist before the first observation lands.

## Where it's wrong

Honest limits, so you know what you're looking at:

**Cold start is dumb.** Adjacency is learned, so a freshly booted server doesn't know
what's behind a train. Those trains sit *at* their next station with `progress = -1`
until a later train reveals the predecessor. `-1` is the sentinel for "placed, but not
really" — see `Registry._place`.

**Termini stay dumb.** A train whose next stop is the first station of its itinerary
in that direction has no observable predecessor, so it parks at the station instead of
approaching it. A static per-line ordering baked into `data/` would fix both this and
the cold start.

**Segment times are averages, not schedules.** A train held at a signal still shows as
gliding, because the model only knows the average crossing time. Reality reasserts
itself at the next poll, and the dot corrects.

**Depth is a lie.** `depth_m` is hardcoded to 20 m for every station
([`registry.py`](../server/app/registry.py), `_place`). It exists for the AR view,
which needs to draw tunnels below the pavement. Real per-station depths would need a
source we don't have.

**Positions are estimates, always.** Nothing here is ground truth. The trains are
real, the timings are real, the placement is inference. It's usually good to a few
seconds — which at metro speeds is tens of metres.

---

**Next:** [SERVER.md](SERVER.md) for the module-by-module walkthrough ·
[APP.md](APP.md) for the Flutter client · [API.md](API.md) for the upstream API.
