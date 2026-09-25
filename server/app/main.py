"""FastAPI app: lifespan starts the poller; routes serve positions + the debug map."""

from __future__ import annotations

import asyncio
import json
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles

from .config import settings
from .carris import CarrisClient, CarrisSource, run_carris_poller
from .metro_client import MetroClient
from .poller import run_poller
from .reference import Reference
from .registry import Registry
from .router import plan_route
from .track import TrackGeometry

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
log = logging.getLogger("main")

WEB_DIR = Path(__file__).resolve().parent.parent / "web"
TRACK_FILE = Path(__file__).resolve().parents[2] / "data" / "track_geometry.geojson"


@asynccontextmanager
async def lifespan(app: FastAPI):
    client = MetroClient()
    ref = Reference()
    registry = Registry()
    stop = asyncio.Event()

    await ref.load(client)
    log.info("reference loaded: %d stations, %d destinos", len(ref.stations), len(ref.destino_names))
    track = TrackGeometry.load(TRACK_FILE)
    log.info("track geometry: %d directional polylines", sum(len(v) for v in track.by_line.values()))
    task = asyncio.create_task(run_poller(client, ref, registry, stop))

    # Carris (buses/trams) is optional and off by default — its positions come
    # from a separate live feed and merge into /trains and /stream.
    carris_client = carris_source = carris_task = None
    if settings.carris_enabled:
        carris_client = CarrisClient()
        carris_source = CarrisSource()
        carris_task = asyncio.create_task(run_carris_poller(carris_client, carris_source, stop))
        log.info("carris enabled: polling %s", settings.carris_base_url)

    app.state.client, app.state.ref, app.state.registry = client, ref, registry
    app.state.track = track
    app.state.carris = carris_source
    try:
        yield
    finally:
        stop.set()
        task.cancel()
        if carris_task is not None:
            carris_task.cancel()
        await client.aclose()
        if carris_client is not None:
            await carris_client.aclose()


app = FastAPI(title="Metro Lisboa AR — positions", lifespan=lifespan)


@app.get("/health")
async def health():
    reg: Registry = app.state.registry
    carris = app.state.carris
    return {
        "status": "ok",
        "stations": len(app.state.ref.stations),
        "trains_tracked": len(reg.trains),
        "carris_vehicles": len(carris.snapshot()) if carris is not None else 0,
        "lines": {k: v.status for k, v in reg.line_status.items()},
    }


@app.get("/stations")
async def stations():
    return [s.model_dump() for s in app.state.ref.stations.values()]


@app.get("/lines")
async def lines():
    return [v.model_dump() for v in app.state.registry.line_status.values()]


@app.get("/station/{stop_id}/arrivals")
async def station_arrivals(stop_id: str):
    reg: Registry = app.state.registry
    return reg.arrivals_at(app.state.ref, stop_id)


@app.get("/route")
async def route(
    from_stop: str = Query(alias="from"),
    to_stop: str = Query(alias="to"),
):
    """Fastest route between two stations using live train waits.

    Query params are `from` and `to` (station stop_ids). 404 for unknown stops or
    when the destination isn't reachable from the current (possibly still-warming)
    topology."""
    reg: Registry = app.state.registry
    ref: Reference = app.state.ref
    if from_stop not in ref.stations:
        raise HTTPException(status_code=404, detail=f"unknown station: {from_stop}")
    if to_stop not in ref.stations:
        raise HTTPException(status_code=404, detail=f"unknown station: {to_stop}")

    def station_name(sid: str) -> str:
        s = ref.stations.get(sid)
        return s.name if s else sid

    plan = plan_route(reg, station_name, ref.destino_name, from_stop, to_stop)
    if plan is None:
        raise HTTPException(status_code=404, detail="no route found (topology still warming up)")
    return plan.model_dump()


@app.get("/track")
async def track_geojson():
    if TRACK_FILE.exists():
        return FileResponse(TRACK_FILE, media_type="application/geo+json")
    return {"type": "FeatureCollection", "features": []}


@app.get("/trains")
async def trains():
    reg: Registry = app.state.registry
    out = reg.snapshot(app.state.ref, app.state.track)
    if app.state.carris is not None:
        out = out + app.state.carris.snapshot()
    return [t.model_dump() for t in out]


@app.get("/stream")
async def stream():
    reg: Registry = app.state.registry
    ref: Reference = app.state.ref
    track = app.state.track
    carris: CarrisSource | None = app.state.carris

    async def gen():
        while True:
            out = reg.snapshot(ref, track)
            if carris is not None:
                out = out + carris.snapshot()
            payload = [t.model_dump() for t in out]
            yield f"data: {json.dumps(payload)}\n\n"
            await asyncio.sleep(settings.stream_interval_seconds)

    return StreamingResponse(gen(), media_type="text/event-stream")


# Debug map at "/" (only mounted if the web dir exists).
if WEB_DIR.exists():
    @app.get("/")
    async def index():
        return FileResponse(WEB_DIR / "index.html")

    app.mount("/static", StaticFiles(directory=WEB_DIR), name="static")
