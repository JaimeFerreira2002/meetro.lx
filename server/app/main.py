"""FastAPI app: lifespan starts the poller; routes serve positions + the debug map."""

from __future__ import annotations

import asyncio
import json
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles

from .config import settings
from .metro_client import MetroClient
from .poller import run_poller
from .reference import Reference
from .registry import Registry

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
log = logging.getLogger("main")

WEB_DIR = Path(__file__).resolve().parent.parent / "web"


@asynccontextmanager
async def lifespan(app: FastAPI):
    client = MetroClient()
    ref = Reference()
    registry = Registry()
    stop = asyncio.Event()

    await ref.load(client)
    log.info("reference loaded: %d stations, %d destinos", len(ref.stations), len(ref.destino_names))
    task = asyncio.create_task(run_poller(client, ref, registry, stop))

    app.state.client, app.state.ref, app.state.registry = client, ref, registry
    try:
        yield
    finally:
        stop.set()
        task.cancel()
        await client.aclose()


app = FastAPI(title="Metro Lisboa AR — positions", lifespan=lifespan)


@app.get("/health")
async def health():
    reg: Registry = app.state.registry
    return {
        "status": "ok",
        "stations": len(app.state.ref.stations),
        "trains_tracked": len(reg.trains),
        "lines": {k: v.status for k, v in reg.line_status.items()},
    }


@app.get("/stations")
async def stations():
    return [s.model_dump() for s in app.state.ref.stations.values()]


@app.get("/lines")
async def lines():
    return [v.model_dump() for v in app.state.registry.line_status.values()]


@app.get("/trains")
async def trains():
    reg: Registry = app.state.registry
    return [t.model_dump() for t in reg.snapshot(app.state.ref)]


@app.get("/stream")
async def stream():
    reg: Registry = app.state.registry
    ref: Reference = app.state.ref

    async def gen():
        while True:
            payload = [t.model_dump() for t in reg.snapshot(ref)]
            yield f"data: {json.dumps(payload)}\n\n"
            await asyncio.sleep(settings.stream_interval_seconds)

    return StreamingResponse(gen(), media_type="text/event-stream")


# Debug map at "/" (only mounted if the web dir exists).
if WEB_DIR.exists():
    @app.get("/")
    async def index():
        return FileResponse(WEB_DIR / "index.html")

    app.mount("/static", StaticFiles(directory=WEB_DIR), name="static")
