# App icons

Drop the two PNGs here (exact filenames matter):

- **`metro.png`** — the metro-front icon (the one with the "M"). Used for the
  moving train markers on the map.
- **`station.png`** — the platform/person icon. Used for the station markers.

Until these files exist, the map falls back to colored dots (via `errorBuilder`),
so the app still runs. Add the files, then hot-restart Flutter.

Recommended: square, transparent-background PNGs, ~128×128 or larger.
