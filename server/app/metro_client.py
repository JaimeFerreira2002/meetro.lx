"""Async client for the Metro Lisboa EstadoServicoML API.

Owns the OAuth token (client-credentials, auto-refresh) so the secret never leaves
the backend. Mirrors the auth/TLS behavior validated in the Phase 0 spike.
"""

from __future__ import annotations

import base64
import time

import httpx

from .config import settings


class MetroClient:
    def __init__(self) -> None:
        verify = not settings.insecure_tls
        self._http = httpx.AsyncClient(timeout=30.0, verify=verify)
        self._token: str | None = settings.access_token or None
        self._expires_at: float = float("inf") if settings.access_token else 0.0
        self._basic = settings.basic_auth
        if not self._basic and settings.consumer_key and settings.consumer_secret:
            raw = f"{settings.consumer_key}:{settings.consumer_secret}".encode()
            self._basic = base64.b64encode(raw).decode()

    async def aclose(self) -> None:
        await self._http.aclose()

    async def _token_value(self) -> str:
        if self._token and time.time() < self._expires_at - 60:
            return self._token
        if not self._basic:
            raise RuntimeError(
                "No credentials: set ML_BASIC_AUTH, ML_CONSUMER_KEY+SECRET, or ML_ACCESS_TOKEN"
            )
        resp = await self._http.post(
            settings.token_url,
            data={"grant_type": "client_credentials"},
            headers={"Authorization": f"Basic {self._basic}"},
        )
        resp.raise_for_status()
        payload = resp.json()
        self._token = payload["access_token"]
        self._expires_at = time.time() + int(payload.get("expires_in", 3600))
        return self._token

    async def _get(self, path: str) -> dict:
        token = await self._token_value()
        resp = await self._http.get(
            f"{settings.base_url}/{path}",
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
        )
        resp.raise_for_status()
        return resp.json()

    async def waits_for_line(self, line: str) -> list[dict]:
        data = await self._get(f"tempoEspera/Linha/{line}")
        resp = data.get("resposta")
        return resp if isinstance(resp, list) else []

    async def stations(self) -> list[dict]:
        data = await self._get("infoEstacao/todos")
        resp = data.get("resposta")
        return resp if isinstance(resp, list) else []

    async def destinos(self) -> list[dict]:
        data = await self._get("infoDestinos/todos")
        resp = data.get("resposta")
        return resp if isinstance(resp, list) else []

    async def line_status(self, line: str) -> dict:
        data = await self._get(f"estadoLinha/{line}")
        resp = data.get("resposta")
        return resp if isinstance(resp, dict) else {}
