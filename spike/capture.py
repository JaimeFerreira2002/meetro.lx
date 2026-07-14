#!/usr/bin/env python3
"""Phase 0 spike: capture raw tempoEspera data from the Metro Lisboa API.

Polls /tempoEspera/Linha/{linha} for all four lines on an interval and appends
every raw response to a JSONL file, one record per (poll, line). Run it for at
least an hour of metro operation, then run analyze.py on the output.

Credentials (from your subscription at https://api.metrolisboa.pt/store/):
  Either a ready-made token:
    export ML_ACCESS_TOKEN=...
  Or consumer key/secret for the client-credentials flow (auto-refreshes):
    export ML_CONSUMER_KEY=...
    export ML_CONSUMER_SECRET=...
  A .env file next to this script is also read (KEY=VALUE lines).

Usage:
  python3 capture.py [--interval 20] [--duration 3600] [--out captures/]
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

BASE_URL = "https://api.metrolisboa.pt:8243/estadoServicoML/1.0.1"
TOKEN_URL = "https://api.metrolisboa.pt:8243/token"
LINES = ["Amarela", "Azul", "Verde", "Vermelha"]


def load_dotenv() -> None:
    env_file = Path(__file__).parent / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


class TokenManager:
    """Serves a bearer token, refreshing via client-credentials when possible."""

    def __init__(self) -> None:
        self._static_token = os.environ.get("ML_ACCESS_TOKEN")
        self._key = os.environ.get("ML_CONSUMER_KEY")
        self._secret = os.environ.get("ML_CONSUMER_SECRET")
        self._token: str | None = None
        self._expires_at: float = 0.0
        if not self._static_token and not (self._key and self._secret):
            sys.exit(
                "No credentials. Set ML_ACCESS_TOKEN, or ML_CONSUMER_KEY + "
                "ML_CONSUMER_SECRET (env or spike/.env)."
            )

    def get(self) -> str:
        if self._static_token:
            return self._static_token
        if self._token and time.time() < self._expires_at - 60:
            return self._token
        creds = base64.b64encode(f"{self._key}:{self._secret}".encode()).decode()
        req = urllib.request.Request(
            TOKEN_URL,
            data=urllib.parse.urlencode({"grant_type": "client_credentials"}).encode(),
            headers={
                "Authorization": f"Basic {creds}",
                "Content-Type": "application/x-www-form-urlencoded",
            },
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read())
        self._token = payload["access_token"]
        self._expires_at = time.time() + int(payload.get("expires_in", 3600))
        print(f"[token] refreshed, expires in {payload.get('expires_in', '?')}s")
        return self._token


def fetch_line(tokens: TokenManager, line: str) -> dict:
    url = f"{BASE_URL}/tempoEspera/Linha/{line}"
    req = urllib.request.Request(
        url, headers={"Authorization": f"Bearer {tokens.get()}", "Accept": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return {"http_status": resp.status, "body": json.loads(resp.read())}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--interval", type=float, default=20, help="seconds between polls")
    parser.add_argument("--duration", type=float, default=3600, help="total capture seconds")
    parser.add_argument("--out", default="captures", help="output directory")
    args = parser.parse_args()

    load_dotenv()
    tokens = TokenManager()

    out_dir = Path(__file__).parent / args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"tempo_espera_{datetime.now():%Y%m%d_%H%M%S}.jsonl"
    print(f"Capturing every {args.interval}s for {args.duration}s -> {out_file}")

    deadline = time.time() + args.duration
    poll = 0
    with out_file.open("a") as fh:
        while time.time() < deadline:
            poll += 1
            for line in LINES:
                record = {
                    "poll": poll,
                    "captured_at": datetime.now(timezone.utc).isoformat(),
                    "line": line,
                }
                try:
                    record.update(fetch_line(tokens, line))
                except urllib.error.HTTPError as e:
                    record["error"] = f"HTTP {e.code}: {e.read()[:500].decode(errors='replace')}"
                except Exception as e:  # noqa: BLE001 — spike: log everything, never die
                    record["error"] = repr(e)
                fh.write(json.dumps(record, ensure_ascii=False) + "\n")
            fh.flush()
            errors = record.get("error")
            print(f"[poll {poll:4d}] {datetime.now():%H:%M:%S}" + (f" last error: {errors}" if errors else ""))
            time.sleep(args.interval)

    print(f"Done. {poll} polls written to {out_file}")


if __name__ == "__main__":
    main()
