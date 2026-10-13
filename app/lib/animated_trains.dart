import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path; // latlong2's Path shadows dart:ui Path

import 'models.dart';

/// Smooths train motion between server snapshots.
///
/// The server streams a fresh set of positions roughly every 1.5 s (already
/// dead-reckoned). Drawn as-is, trains step from one frame to the next. This
/// layer tweens each train from where it is currently drawn to its newly
/// received position over the time until the next snapshot, so motion reads as
/// continuous between frames.
///
/// It drives its **own** ticker and rebuilds only itself (a [MarkerLayer]).
/// The parent screen still rebuilds once per snapshot — not once per animation
/// frame — which matters given `main.dart`'s single-big-widget architecture.
///
/// This is the client half of a hybrid: the server dead-reckons positions
/// forward in time; the client interpolates between the frames it receives.
class AnimatedTrains extends StatefulWidget {
  /// Latest snapshot. A *new list instance* signals a new snapshot — other
  /// parent rebuilds reuse the same instance and are ignored (see
  /// [_AnimatedTrainsState.didUpdateWidget]).
  final List<TrainPosition> trains;

  /// Builds the marker for a train. The caller picks metro vs. Carris styling;
  /// this layer hands back a copy with interpolated `pos`/`bearing`.
  final Marker Function(TrainPosition) builder;

  /// Train kept pinned to its exact snapshot position (no tween). The camera
  /// follows it, so tweening would make it drift from the map centre.
  final String? followId;

  const AnimatedTrains({
    super.key,
    required this.trains,
    required this.builder,
    this.followId,
  });

  @override
  State<AnimatedTrains> createState() => _AnimatedTrainsState();
}

/// Per-train tween endpoints for the current snapshot interval.
class _Track {
  final LatLng from;
  final LatLng to;
  final double fromBearing;
  final double toBearing;
  const _Track(this.from, this.to, this.fromBearing, this.toBearing);
}

class _AnimatedTrainsState extends State<AnimatedTrains>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Map<String, _Track> _tracks = {};

  DateTime? _snapAt; // when the current snapshot was applied
  Duration _interval = const Duration(milliseconds: 1500);

  // Beyond this, a position change is a discontinuity (reappearance, line
  // change) rather than travel — snap instead of sweeping across the map.
  static const double _snapMeters = 400;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    for (final t in widget.trains) {
      _tracks[t.trainId] = _Track(t.pos, t.pos, t.bearing, t.bearing);
    }
  }

  @override
  void didUpdateWidget(AnimatedTrains old) {
    super.didUpdateWidget(old);
    // Only a genuinely new snapshot (a fresh list from the stream) restarts the
    // tween; incidental parent rebuilds reuse the same list instance.
    if (!identical(old.trains, widget.trains)) {
      _applySnapshot(widget.trains);
    }
  }

  void _applySnapshot(List<TrainPosition> trains) {
    final now = DateTime.now();
    final frac = _frac(now);

    // Cadence = time since the last snapshot, clamped so a hiccup can't make
    // the tween crawl, nor a burst make it snap.
    if (_snapAt != null) {
      _interval = Duration(
        milliseconds: now.difference(_snapAt!).inMilliseconds.clamp(600, 4000),
      );
    }

    final next = <String, _Track>{};
    var moving = false;
    for (final t in trains) {
      final prev = _tracks[t.trainId];
      // Where this train is being drawn *right now* (mid-tween, if any).
      final current =
          prev == null ? t.pos : _lerpLatLng(prev.from, prev.to, frac);
      final currentBearing = prev == null
          ? t.bearing
          : _lerpAngle(prev.fromBearing, prev.toBearing, frac);

      if (prev == null || _meters(current, t.pos) > _snapMeters) {
        next[t.trainId] = _Track(t.pos, t.pos, t.bearing, t.bearing); // snap
      } else {
        next[t.trainId] = _Track(current, t.pos, currentBearing, t.bearing);
        if (_meters(current, t.pos) > 0.5) moving = true;
      }
    }

    _tracks
      ..clear()
      ..addAll(next);
    _snapAt = now;

    // No point burning frames when nothing actually moved (e.g. closed hours,
    // an offline stall still emitting the last snapshot).
    if (moving && !_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    final frac = _frac(DateTime.now());
    setState(() {}); // rebuild markers at the new interpolation point
    if (frac >= 1.0) _ticker.stop(); // idle until the next snapshot
  }

  double _frac(DateTime now) {
    if (_snapAt == null) return 1.0;
    final ms = now.difference(_snapAt!).inMilliseconds;
    return (ms / _interval.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frac = _frac(DateTime.now());
    final markers = <Marker>[];
    for (final t in widget.trains) {
      final track = _tracks[t.trainId];
      // Unseen train, or the followed one (kept pinned to the camera centre).
      if (track == null || t.trainId == widget.followId) {
        markers.add(widget.builder(t));
        continue;
      }
      final pos = _lerpLatLng(track.from, track.to, frac);
      final bearing = _lerpAngle(track.fromBearing, track.toBearing, frac);
      markers.add(widget.builder(t.copyWith(pos: pos, bearing: bearing)));
    }
    return MarkerLayer(markers: markers);
  }
}

LatLng _lerpLatLng(LatLng a, LatLng b, double t) => LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );

/// Shortest-path angular interpolation, degrees.
double _lerpAngle(double a, double b, double t) {
  var diff = (b - a) % 360;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return a + diff * t;
}

/// Rough planar distance in metres — fine at city scale for a snap threshold.
double _meters(LatLng a, LatLng b) {
  const mPerDeg = 111320.0;
  final dLat = (a.latitude - b.latitude) * mPerDeg;
  final dLon = (a.longitude - b.longitude) *
      mPerDeg *
      math.cos(a.latitude * math.pi / 180);
  return math.sqrt(dLat * dLat + dLon * dLon);
}
