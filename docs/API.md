# Metro Lisboa API reference (`EstadoServicoML`)

Live-verified reference for the official Metro Lisboa API that powers this app.
Everything below was confirmed against the running API (2026-07-15).

- **Base:** `https://api.metrolisboa.pt:8243/estadoServicoML/1.0.1/`
- **Auth:** OAuth2 `client_credentials` → `POST https://api.metrolisboa.pt:8243/token`
  with `Authorization: Basic base64(consumerKey:consumerSecret)` → Bearer token, ~1h expiry.
- **Envelope:** every response is `{"resposta": <data>, "codigo": "200"}`. On error,
  `codigo` is `"400"` and `resposta` is an error string (e.g. `"Hora inválida."`).
- **Lines:** `Amarela`, `Azul`, `Verde`, `Vermelha` (capitalized).
- **Day types:** `S` (weekday), `F` (weekend/holiday).
- **TLS:** the gateway cert is valid, but some trust stores (e.g. Homebrew Python on
  macOS) lack the issuer and fail verification while `curl` succeeds — use `certifi`
  or an unverified context if needed.

There is **no train-position endpoint**; positions are interpolated from the same
train ID appearing at multiple stations with rising ETAs (see the server).

---

## 1. Real-time wait times — `tempoEspera` (core feed)

```
GET /tempoEspera/Estacao/{id}      # one station
GET /tempoEspera/Estacao/todos     # all platforms (~111)
GET /tempoEspera/Linha/{linha}     # all platforms on a line
```

`resposta` is a list of platform entries, each listing up to 3 upcoming trains:

| Field | Example | Meaning |
|---|---|---|
| `stop_id` | `"AM"` | Station code |
| `cais` | `"A18A1O"` | Platform/track code (direction-specific) |
| `hora` | `"20260715120705"` | Data timestamp `YYYYMMDDhhmmss` |
| `comboio`, `comboio2`, `comboio3` | `"29C"` | Next 3 train IDs |
| `tempoChegada1`, `tempoChegada2`, `tempoChegada3` | `37` | **Seconds** to arrival (`"--"` when none) |
| `destino` | `"54"` | Destination code → resolve via `infoDestinos` |
| `sairServico` | `0` | `1` = train terminates / leaves service after this |
| `UT` | `2` | Train unit/composition type. Present only in `Estacao/*`, **not** `Linha`. Undocumented — likely number of coupled units |

**Quirks**
- ETAs are **seconds**, not minutes.
- Idle terminus platforms can show a **stale `hora`** (e.g. a 2024 date) with all `"--"`
  ETAs; judge liveness from the network as a whole, not one entry.
- The same train ID appears across many stations with increasing ETAs — the basis of
  the position interpolation.

## 2. Station catalog — `infoEstacao`

```
GET /infoEstacao/{id}
GET /infoEstacao/todos             # 50 stations
```

`resposta` is a list:

| Field | Example | Meaning |
|---|---|---|
| `stop_id` | `"AM"` | Station code |
| `stop_name` | `"Alameda"` | Display name |
| `stop_lat`, `stop_lon` | `38.7373` | GPS |
| `stop_url` | `"[…/alameda-linha-verde/,…/alameda-linha-vermelha/]"` | Bracketed list of official URLs |
| `linha` | `"[Verde, Vermelha]"` | Bracketed list of lines serving the station |
| `zone_id` | `"L"` | Fare zone |

**Quirk:** `/infoEstacao/{id}` returns `stop_lat`/`stop_lon` as **numbers**; `/todos`
returns them as **strings**. Parse both.

## 3. Line status — `estadoLinha`

```
GET /estadoLinha/todos
GET /estadoLinha/{linha}
```

`resposta` is an **object** (not a list):

- `/todos`: `{amarela, azul, verde, vermelha, tipo_msg_am, tipo_msg_az, tipo_msg_vd, tipo_msg_vm, amarela_curta, azul_curta, verde_curta, vermelha_curta}`
- `/{linha}`: e.g. `{"azul": " Ok", "tipo_msg_az": "0", "azul_curta": "normal"}`

Healthy = status `" Ok"` (note the leading space), `tipo_msg_* = "0"`, `*_curta = "normal"`.
Non-zero / non-"normal" indicates a disruption (with a message).

## 4. Destinations — `infoDestinos`

```
GET /infoDestinos/todos            # 24 entries
```

`resposta` list of `{id_destino, nome_destino}`, e.g. `{"id_destino": "33", "nome_destino": "Reboleira"}`.
Resolves the `destino` codes from `tempoEspera`. There are more than the 8 termini — the
extras are short-turn destinations (e.g. Amadora Este, Pontinha).

## 5. Scheduled headways — `infoIntervalos`

```
GET /infoIntervalos/{linha}/{dia}        # e.g. /Azul/S  (weekday) or /Azul/F (weekend)
GET /infoIntervalos/{linha}/{dia}/{hora} # time-specific — see note
```

Day-level returns a list of time bands (~13 weekday, ~7 weekend):

```json
{"Linha": "Azul", "HoraInicio": "06:30:00", "HoraFim": "06:59:59",
 "Intervalo": "07:00:00", "UT": 2, "Dia": "s"}
```

`Intervalo` is the headway for that band. **Format is ambiguous** — it reads like
`HH:MM:SS` but the values (`"07:00:00"` early weekday, `"08:10:00"` early weekend) don't
line up cleanly; verify against observed frequencies before displaying.

**Time-specific variant:** the accepted `{hora}` format could not be determined —
numeric (`063000`) returns `"Hora inválida."`, colon forms 404. **Recommendation:** skip
this variant; fetch the day-level list and filter by `HoraInicio`/`HoraFim` client-side.

---

## Attribution / credits

- **Transit data:** Metropolitano de Lisboa, E.P.E. (`EstadoServicoML` API).
- **Map tiles:** © OpenStreetMap contributors, © CARTO.
- **Search geocoding:** OpenStreetMap / Nominatim.
- **Track geometry:** OpenStreetMap (subway route relations, baked in `data/`).

## Open questions

- `UT` field meaning (train composition type?) — undocumented.
- `infoIntervalos` time-specific `{hora}` format.
- `Intervalo` value encoding.
