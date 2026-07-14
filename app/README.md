# app — Flutter client

Flutter/Dart app. **Phase 1** (here) is the 2D live map that mirrors the web debug
view and doubles as the fallback/indoor mode. **Phase 2** adds the AR camera screen as
a native iOS platform view (ARKit + ARCore Geospatial), reusing `lib/metro_api.dart`.

## Finish the scaffold

Only the Dart source + `pubspec.yaml` are committed. Generate the platform folders
(ios/android/etc.) in place, then run:

```bash
cd app
flutter create .            # fills in ios/, android/, etc. around the existing lib/
flutter pub get
# point the app at your running server (see server/README.md):
#   iOS simulator:      localhost works
#   Android emulator:   use 10.0.2.2
#   physical device:    your machine's LAN IP
flutter run --dart-define=API_BASE=http://localhost:8000
```

## Structure

| File | Role |
|---|---|
| `lib/models.dart` | wire-contract types (mirror `server/app/models.py`) + line colors |
| `lib/metro_api.dart` | HTTP + SSE client for the interpolation service (shared with AR later) |
| `lib/main.dart` | `flutter_map` screen: OSM tiles, station dots, live train markers |

Map uses `flutter_map` + free OSM tiles (token-free) for the debug/fallback view;
swap to `mapbox_maps_flutter` later if you want Mapbox styling.
