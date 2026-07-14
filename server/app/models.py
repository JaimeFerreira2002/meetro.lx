"""Wire-contract models shared with the mobile client / debug map."""

from __future__ import annotations

from pydantic import BaseModel


class Station(BaseModel):
    stop_id: str
    name: str
    lat: float
    lon: float
    lines: list[str]


class LineStatus(BaseModel):
    line: str
    status: str          # e.g. "Ok"
    detail: str = ""     # short human message when disrupted


class TrainPosition(BaseModel):
    train_id: str
    line: str
    destino: str
    destino_name: str
    next_stop: str
    next_stop_name: str
    eta_seconds: float          # to next_stop, adjusted to "now"
    lat: float
    lon: float
    bearing: float              # degrees, 0 = north, direction of travel
    speed_mps: float
    depth_m: float              # approximate; underground offset for AR
    progress: float             # 0..1 along current segment (−1 if unknown)
