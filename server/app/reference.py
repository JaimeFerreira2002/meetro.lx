"""Static reference data: station catalog (GPS) and destino code → name.

Loaded from the API at startup and refreshed rarely (this rarely changes).
"""

from __future__ import annotations

from .metro_client import MetroClient
from .models import Station


def _parse_bracket_list(value: str) -> list[str]:
    """'[Verde, Vermelha]' -> ['Verde', 'Vermelha']."""
    return [p.strip() for p in value.strip().strip("[]").split(",") if p.strip()]


class Reference:
    def __init__(self) -> None:
        self.stations: dict[str, Station] = {}
        self.destino_names: dict[str, str] = {}

    async def load(self, client: MetroClient) -> None:
        for row in await client.stations():
            try:
                station = Station(
                    stop_id=row["stop_id"],
                    name=row.get("stop_name", row["stop_id"]),
                    lat=float(row["stop_lat"]),
                    lon=float(row["stop_lon"]),
                    lines=_parse_bracket_list(row.get("linha", "")),
                )
            except (KeyError, ValueError):
                continue
            self.stations[station.stop_id] = station

        for row in await client.destinos():
            code = row.get("id_destino")
            if code:
                self.destino_names[str(code)] = row.get("nome_destino", str(code))

    def destino_name(self, code: str) -> str:
        return self.destino_names.get(str(code), str(code))
