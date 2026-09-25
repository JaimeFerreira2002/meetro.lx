"""Carris (Lisbon buses / trams) live vehicle positions.

Unlike Metro's EstadoServicoML — which never says where a train *is* — the Carris
Metropolitana open API returns decoded GTFS-RT vehicle positions directly
(lat/lon/bearing/speed). So there's no inference to do: fetch `/vehicles`, map each
to the shared `TrainPosition` wire model with `mode`/`operator` set, and prune the
ones that have gone stale.

Off by default (`settings.carris_enabled`). The exact feed and tram coverage are
still open (issue #64) — Carris Metropolitana is the regional bus network; the
city tram feed (Carris) would slot in the same way with `mode="tram"`. The feed
shape below follows the documented Carris Metropolitana `/vehicles` schema and
should be confirmed against the live endpoint before enabling in production.
"""

from __future__ import annotations

import asyncio
import logging
import time
from dataclasses import dataclass, field

import httpx

from .config import settings
from .models import TrainPosition

log = logging.getLogger("carris")

# Positions arrive roughly every 10 s; drop a vehicle unseen for longer so the
# map doesn't show a bus that stopped reporting.
STALE_AFTER = 60.0


def _f(value, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def parse_vehicle(raw: dict) -> TrainPosition | None:
    """One Carris `/vehicles` entry -> TrainPosition, or None if it has no fix."""
    lat, lon = raw.get("lat"), raw.get("lon")
    if lat is None or lon is None:
        return None
    return TrainPosition(
        train_id=str(raw.get("id", "")),
        line=str(raw.get("line_id") or ""),
        destino=str(raw.get("pattern_id") or ""),
        destino_name="",
        next_stop=str(raw.get("stop_id") or ""),
        next_stop_name="",
        eta_seconds=0.0,
        lat=round(_f(lat), 6),
        lon=round(_f(lon), 6),
        bearing=round(_f(raw.get("bearing")), 1),
        speed_mps=round(_f(raw.get("speed")), 2),
        depth_m=0.0,        # surface transit
        progress=0.0,       # positions are exact; no segment interpolation needed
        mode="bus",         # Carris Metropolitana is buses; trams come with the city feed
        operator="Carris",
    )


def parse_vehicles(raw) -> list[TrainPosition]:
    out: list[TrainPosition] = []
    for entry in raw or []:
        if isinstance(entry, dict):
            v = parse_vehicle(entry)
            if v is not None:
                out.append(v)
    return out


@dataclass
class CarrisSource:
    """Holds the latest Carris vehicle snapshot, with staleness pruning."""

    vehicles: list[TrainPosition] = field(default_factory=list)
    captured_at: float = 0.0

    def update(self, vehicles: list[TrainPosition], now: float | None = None) -> None:
        self.vehicles = vehicles
        self.captured_at = time.time() if now is None else now

    def snapshot(self, now: float | None = None) -> list[TrainPosition]:
        now = time.time() if now is None else now
        if now - self.captured_at > STALE_AFTER:
            return []  # feed went quiet — don't serve stale positions
        return self.vehicles


class CarrisClient:
    def __init__(self) -> None:
        self._http = httpx.AsyncClient(timeout=15.0)

    async def vehicles(self) -> list:
        url = settings.carris_base_url.rstrip("/") + "/vehicles"
        resp = await self._http.get(url)
        resp.raise_for_status()
        data = resp.json()
        return data if isinstance(data, list) else []

    async def aclose(self) -> None:
        await self._http.aclose()


async def run_carris_poller(client: CarrisClient, source: CarrisSource, stop: asyncio.Event) -> None:
    """Poll Carris vehicle positions into [source] until [stop] is set."""
    while not stop.is_set():
        started = time.time()
        try:
            source.update(parse_vehicles(await client.vehicles()))
            log.info("carris poll: %d vehicles", len(source.vehicles))
        except Exception as exc:  # noqa: BLE001 — keep the loop alive
            log.warning("carris poll failed: %s", exc)
        elapsed = time.time() - started
        try:
            await asyncio.wait_for(
                stop.wait(), timeout=max(2.0, settings.carris_poll_interval_seconds - elapsed)
            )
        except asyncio.TimeoutError:
            pass
