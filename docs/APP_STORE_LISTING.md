# App Store listing copy (#28)

Ready-to-paste text for App Store Connect. Primary language **Português (Portugal)**;
English as a second localization for reach. Character limits noted — App Store
Connect enforces them and does **not** render Markdown (plain text + line breaks +
emoji only).

Screenshots are handled separately (done). Privacy-policy URL is [#23]; support URL
is below.

---

## Português (Portugal) — primary

**Nome** (≤30) — already set
```
meetro
```

**Subtítulo** (≤30)
```
Metros de Lisboa em tempo real
```

**Texto promocional** (≤170, editável sem revisão)
```
Sabe ao segundo se vem aí o próximo metro — e se vale a pena correr. Estações favoritas, estado das linhas e um widget com os metros mais perto de ti.
```

**Palavras-chave** (≤100, separadas por vírgula, sem espaços)
```
metro,lisboa,comboio,metropolitano,transportes,estação,horário,linha,tempos,espera,carris,mapa
```

**Descrição** (≤4000)
```
O meetro mostra-te as carruagens do Metro de Lisboa em tempo real. Sabe ao segundo se vem aí um metro — e se vale a pena correr. 🏃‍♂️

Um projeto pessoal, feito para quem apanha o metro todos os dias.

O QUE FAZ
📍 Metros a chegar a qualquer estação, ao segundo
⭐ As tuas estações favoritas aparecem primeiro
⚠️ Vê se há algum problema numa linha
🤔 Ajuda a decidir para que estação ir quando estás entre duas ou mais
📲 Widget no ecrã inicial com os metros mais perto de ti
🌙 Sabe quando o metro está fechado (serviço das 06:30 à 01:00)
🇵🇹 Em português e inglês

A CAMINHO
🗺️ Planeamento de viagens com base nos tempos de espera
🥽 Visualização em realidade aumentada das linhas e carruagens

As posições dos comboios são estimadas a partir dos tempos de espera da API pública do Metropolitano de Lisboa, ao segundo.

O meetro é um projeto pessoal e não está associado, patrocinado nem aprovado pelo Metropolitano de Lisboa.
```

**Novidades desta versão** (≤4000)
```
Primeira versão do meetro. 🚇
Metros de Lisboa em tempo real, estações favoritas, estado das linhas e um widget para o ecrã inicial. Obrigado por experimentares — o feedback é muito bem-vindo!
```

---

## English

**Subtitle** (≤30)
```
Live Lisbon Metro trains
```

**Promotional text** (≤170)
```
Know to the second if the next train is coming — and whether it's worth running for. Favourite stations, line status, and a widget with the trains nearest you.
```

**Keywords** (≤100)
```
metro,lisbon,subway,train,transit,transport,station,schedule,line,realtime,lisboa,map
```

**Description** (≤4000)
```
meetro shows Lisbon Metro trains in real time. Know to the second if a train is coming — and whether it's worth running for. 🏃‍♂️

A personal side project, made for people who ride the metro every day.

WHAT IT DOES
📍 Trains arriving at any station, to the second
⭐ Your favourite stations show up first
⚠️ See if there's a problem on any line
🤔 Helps you choose which station to head for when you're between two
📲 Home-screen widget with the trains nearest you
🌙 Knows when the metro is closed (service runs 06:30–01:00)
🇵🇹 In Portuguese and English

COMING SOON
🗺️ Trip planning based on wait times
🥽 Augmented-reality view of the lines and trains

Train positions are estimated to the second from the wait-time data in Metropolitano de Lisboa's public API.

meetro is a personal project and is not associated with, sponsored by, or endorsed by Metropolitano de Lisboa.
```

**What's New** (≤4000)
```
The first release of meetro. 🚇
Live Lisbon Metro trains, favourite stations, line status, and a home-screen widget. Thanks for trying it — feedback very welcome!
```

---

## Shared fields

**Support URL** (required) — needs a real page with a way to reach you. Options:
- A simple GitHub Pages page with a contact email, or
- the public repo: `https://github.com/JaimeFerreira2002/meetro.lx`
```
[SUPPORT_URL]
```

**Marketing URL** (optional)
```
[MARKETING_URL — e.g. a landing page or the repo]
```

**Privacy policy URL** (required) — hosted ✅
```
https://jaimeferreira2002.github.io/meetro.lx/privacy.html
```

**App Privacy (nutrition labels)**
- **Precise Location** → used for *App Functionality* · **not** linked to identity · **not** used for tracking
- Note the third-party search request to OpenStreetMap Nominatim

**Age rating:** expected 4+

---

## App Review notes (paste into "Notes" at submission)

```
meetro is an unofficial app that shows live Lisbon Metro (Metropolitano de Lisboa)
train arrivals, estimated from their public EstadoServicoML API. It is not
affiliated with or endorsed by Metropolitano de Lisboa; a disclaimer to that
effect is shown in the app (Settings → About).

Please test during Lisbon service hours (06:30–01:00, Europe/Lisbon time). The
metro does not run overnight, so outside those hours the map is legitimately
empty — the app labels this state ("Metro closed · opens 06:30"). During service
hours you will see live trains moving on the map and second-level arrivals at
each station.

No login or account is required. Location is used only on-device to show nearby
stations; it is never sent to our server.
```

> Keep the Fly backend up (`min_machines_running = 1`) throughout review — the app
> depends on it, and a reviewer hitting a dead server would see an empty map.
