"""Single background poller: the only thing that talks to the Metro API."""

from __future__ import annotations

import asyncio
import logging
import time

from .config import settings
from .metro_client import MetroClient
from .models import LineStatus
from .reference import Reference
from .registry import Registry

log = logging.getLogger("poller")


async def run_poller(client: MetroClient, ref: Reference, registry: Registry, stop: asyncio.Event) -> None:
    while not stop.is_set():
        started = time.time()
        for line in settings.lines:
            try:
                entries = await client.waits_for_line(line)
                registry.ingest_line(line, entries, captured_at=time.time())
            except Exception as exc:  # noqa: BLE001 — keep the loop alive
                log.warning("waits %s failed: %s", line, exc)
            try:
                raw = await client.line_status(line)
                status = raw.get(line.lower(), "").strip() or "unknown"
                registry.set_line_status(LineStatus(line=line, status=status))
            except Exception as exc:  # noqa: BLE001
                log.warning("status %s failed: %s", line, exc)

        registry.prune(time.time())
        log.info("poll done: %d trains tracked", len(registry.trains))

        elapsed = time.time() - started
        try:
            await asyncio.wait_for(stop.wait(), timeout=max(1.0, settings.poll_interval_seconds - elapsed))
        except asyncio.TimeoutError:
            pass
