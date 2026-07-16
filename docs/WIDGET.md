# Home-screen widget (iOS)

Shows the next trains at the metro station closest to you, on the home screen.

The widget is **native (WidgetKit/SwiftUI)**, not Flutter — it's a separate Xcode
target that runs in its own process. The implementation lives in
[`app/ios/MetroWidget/MetroWidget.swift`](../app/ios/MetroWidget/MetroWidget.swift);
the target itself has to be created in Xcode once (it rewrites the `.xcodeproj`).

## One-time setup

1. **Create the target.** Open `app/ios/Runner.xcworkspace` →
   **File → New → Target… → Widget Extension**.
   - Product Name: **`MetroWidget`** (must match, the folder is already there)
   - Uncheck *Include Configuration Intent* (we use a static widget)
   - Uncheck *Include Live Activity*
   - Activate the scheme when prompted.
2. **Use our implementation.** Xcode generates a template `MetroWidget.swift` —
   replace its contents with `app/ios/MetroWidget/MetroWidget.swift` from this
   repo (or delete the generated file and add ours to the target).
   Make sure the file's *Target Membership* is **MetroWidget**.
3. **Let the widget read location.** Select the **MetroWidget** target →
   **Info** → add a row:
   - Key: `NSWidgetWantsLocation` · Type: `Boolean` · Value: `YES`
4. **Run it.**
   ```bash
   cd app && flutter run -d "iPhone 16" --dart-define=API_BASE=https://metro-lisboa-ar.fly.dev
   ```
   Open the app once and **allow location** (the widget piggybacks on the app's
   When-In-Use permission). Then long-press the home screen → **+** → search
   "Metro" → add the widget. Widgets work in the simulator.

## How it works (and its limits)

- **Talks to the backend directly** (`https://metro-lisboa-ar.fly.dev`) — no App
  Group, so it works with a **free Apple ID**. (App Groups, the usual way to
  share data between app and widget, need a paid membership.)
- **Location** comes from WidgetKit via `NSWidgetWantsLocation`; it finds the
  nearest station from `/stations` and fetches `/station/{id}/arrivals`.
- **Refresh:** iOS budgets widget updates (~every 10 min here) — a widget can't
  hold a live stream. To avoid a frozen, stale "3:20", each ETA is converted to
  an **absolute arrival time** at fetch, and SwiftUI counts it down on-device.
  So the countdown ticks live between refreshes; only the underlying train data
  is periodic.
- **Sizes:** small (2 arrivals) and medium (3).

## Changing the backend URL

`apiBase` at the top of `MetroWidget.swift`. The widget can't read Flutter's
`--dart-define`, so it's set in Swift.

## Known gaps / next steps

- Doesn't use your **favourites** yet — that needs an App Group (paid account)
  to read the app's `shared_preferences`. Currently always "nearest station".
- No Lock Screen (`accessoryRectangular`) family yet — easy to add later.
