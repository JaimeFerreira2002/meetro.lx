#!/usr/bin/env python3
"""Phase 0 spike: analyze captured tempoEspera data.

Answers the questions the interpolation engine depends on:
  1. Is the data live at all? (error rate, response codes)
  2. Are train IDs stable across consecutive polls? (lifespan, gaps)
  3. Does the same train ID appear at multiple stations in one poll?
     (this is what makes position interpolation possible)
  4. Do ETAs count down consistently between polls for a (train, station) pair?
  5. What is the ETA granularity/update cadence?

Usage:
  python3 analyze.py captures/tempo_espera_YYYYMMDD_HHMMSS.jsonl
"""

import json
import statistics
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

# Confirmed schema (2026-07-14, live): each platform entry has
#   stop_id, cais, hora (YYYYMMDDhhmmss), destino, sairServico, and up to three
#   upcoming trains: comboio/tempoChegada1, comboio2/tempoChegada2, comboio3/tempoChegada3.
# tempoChegada is SECONDS to arrival; empty slots come through as "--".
# Extra fallbacks kept in case the response model shifts.
TRAIN_KEYS = [("comboio", "tempoChegada1"), ("comboio2", "tempoChegada2"), ("comboio3", "tempoChegada3")]
STATION_KEYS = ["stop_id", "estacao", "station"]


def station_of(entry: dict) -> str:
    for key in STATION_KEYS:
        if key in entry:
            return str(entry[key])
    return "?"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <capture.jsonl>")
    path = Path(sys.argv[1])

    records = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    total = len(records)
    errors = [r for r in records if "error" in r]
    print(f"== Liveness ==\nrecords: {total}, errors: {len(errors)} ({100 * len(errors) / max(total, 1):.1f}%)")
    if errors:
        sample = defaultdict(int)
        for r in errors:
            sample[r["error"][:80]] += 1
        for msg, n in sorted(sample.items(), key=lambda kv: -kv[1])[:5]:
            print(f"  {n:4d}x {msg}")
    ok = [r for r in records if "error" not in r]
    if not ok:
        sys.exit("\nNo successful responses — the API is down or credentials are wrong.")

    # Print one raw entry so we can see the actual schema.
    first_entries = None
    for r in ok:
        resposta = r.get("body", {}).get("resposta")
        if isinstance(resposta, list) and resposta:
            first_entries = resposta
            break
    if first_entries is None:
        sys.exit("\nResponses succeeded but contained no 'resposta' array — inspect the JSONL manually.")
    print(f"\n== Schema sample ==\nkeys: {sorted(first_entries[0].keys())}")
    print(json.dumps(first_entries[0], ensure_ascii=False, indent=2))

    # sightings[(train, station)] = list of (poll, captured_at, eta_seconds)
    sightings: dict[tuple[str, str], list[tuple[int, datetime, float]]] = defaultdict(list)
    # per_poll_train_stations[(poll, train)] = set of stations
    per_poll: dict[tuple[int, str], set[str]] = defaultdict(set)
    for r in ok:
        ts = datetime.fromisoformat(r["captured_at"])
        for entry in r.get("body", {}).get("resposta", []) or []:
            for train_key, eta_key in TRAIN_KEYS:
                train, eta = entry.get(train_key), entry.get(eta_key)
                if not train or eta in (None, ""):
                    continue
                try:
                    eta_s = float(eta)
                except ValueError:
                    continue
                station = station_of(entry)
                sightings[(train, station)].append((r["poll"], ts, eta_s))
                per_poll[(r["poll"], train)].add(station)

    trains = {t for t, _ in sightings}
    polls = {p for (p, _t) in per_poll}
    print(f"\n== Train identity ==\ndistinct train IDs: {len(trains)} across {len(polls)} polls")

    lifespans = defaultdict(set)
    for (poll, train), _stations in per_poll.items():
        lifespans[train].add(poll)
    spans = [max(ps) - min(ps) + 1 for ps in lifespans.values()]
    observed = [len(ps) for ps in lifespans.values()]
    if spans:
        print(f"train lifespan (polls): median {statistics.median(spans):.0f}, max {max(spans)}")
        gappiness = [o / s for o, s in zip(observed, spans)]
        print(f"presence within lifespan: median {100 * statistics.median(gappiness):.0f}% "
              f"(100% = no gaps; low values mean IDs flicker)")

    multi = [len(st) for st in per_poll.values()]
    frac_multi = sum(1 for n in multi if n >= 2) / max(len(multi), 1)
    print(f"\n== Multi-station visibility (interpolation prerequisite) ==")
    print(f"stations per (poll, train): median {statistics.median(multi):.0f}, max {max(multi)}")
    print(f"trains visible at >=2 stations simultaneously: {100 * frac_multi:.0f}% of observations")
    verdict = "VIABLE" if frac_multi > 0.5 else "AT RISK — mostly single-station sightings"
    print(f"interpolation premise: {verdict}")

    print(f"\n== ETA countdown behavior ==")
    deltas_eta, deltas_wall, regressions = [], [], 0
    for series in sightings.values():
        series.sort()
        for (_, t0, e0), (_, t1, e1) in zip(series, series[1:]):
            wall = (t1 - t0).total_seconds()
            if 0 < wall < 120:
                deltas_wall.append(wall)
                deltas_eta.append(e0 - e1)
                if e1 > e0 + 5:
                    regressions += 1
    if deltas_eta:
        ratio = statistics.median(d / w for d, w in zip(deltas_eta, deltas_wall) if w)
        print(f"pairs compared: {len(deltas_eta)}; median ETA decrease per wall-second: {ratio:.2f} "
              f"(~1.0 = real-time countdown, ~0 = stale/cached)")
        print(f"regressions (ETA jumped up >5s): {regressions} "
              f"({100 * regressions / len(deltas_eta):.1f}%) — smoothing must absorb these")
    else:
        print("not enough repeat sightings to measure — capture longer")


if __name__ == "__main__":
    main()
