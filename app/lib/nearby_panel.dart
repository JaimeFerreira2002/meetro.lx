/// "Nearby" panel: your favourite stations first, then the closest ones — each
/// with its live next trains (per direction). The daily-use view.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'line_stripe.dart';
import 'metro_api.dart';
import 'models.dart';
import 'stations_panel.dart' show fmtEta;

double _distanceM(LatLng a, LatLng b) {
  const r = 6371000.0;
  final p1 = a.latitude * math.pi / 180, p2 = b.latitude * math.pi / 180;
  final dp = (b.latitude - a.latitude) * math.pi / 180;
  final dl = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

String _fmtDist(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

class NearbyPanel extends StatefulWidget {
  final MetroApi api;
  final List<Station> stations;
  final LatLng location;
  final void Function(Station) onTapStation;
  final Set<String> favorites;
  final void Function(String stopId) onToggleFavorite;

  const NearbyPanel({
    super.key,
    required this.api,
    required this.stations,
    required this.location,
    required this.onTapStation,
    required this.favorites,
    required this.onToggleFavorite,
  });

  @override
  State<NearbyPanel> createState() => _NearbyPanelState();
}

class _NearbyPanelState extends State<NearbyPanel> {
  static const _count = 6;
  List<Station> _favStations = [];
  List<Station> _nearest = [];
  final Map<String, List<Arrival>?> _arrivals = {}; // null = loading
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _recompute();
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAll());
  }

  @override
  void didUpdateWidget(NearbyPanel old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location ||
        old.stations.length != widget.stations.length ||
        !_sameSet(old.favorites, widget.favorites)) {
      _recompute();
      _loadAll();
    }
  }

  bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _recompute() {
    final byDistance = [...widget.stations]
      ..sort((a, b) =>
          _distanceM(widget.location, a.pos).compareTo(_distanceM(widget.location, b.pos)));
    _favStations = byDistance.where((s) => widget.favorites.contains(s.stopId)).toList();
    // don't repeat favourites in the closest list
    _nearest =
        byDistance.where((s) => !widget.favorites.contains(s.stopId)).take(_count).toList();
  }

  Future<void> _loadAll() async {
    for (final s in [..._favStations, ..._nearest]) {
      widget.api.arrivals(s.stopId).then((a) {
        if (mounted) setState(() => _arrivals[s.stopId] = a);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const StripeHeader(icon: Icons.near_me_rounded, title: 'Nearby'),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_favStations.isNotEmpty) ...[
                  _sectionLabel(Icons.star_rounded, 'Favourites'),
                  for (final s in _favStations) _stationBlock(s),
                  const SizedBox(height: 14),
                ],
                _sectionLabel(Icons.near_me_rounded, 'Closest'),
                for (final s in _nearest) _stationBlock(s),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: Colors.black45),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _stationBlock(Station s) {
    final dist = _distanceM(widget.location, s.pos);
    final arrivals = _arrivals[s.stopId];
    final fav = widget.favorites.contains(s.stopId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => widget.onTapStation(s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final line in s.lines)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(lineColors[line] ?? 0xFFFFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(s.name,
                      style: const TextStyle(
                          color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text(_fmtDist(dist),
                    style: const TextStyle(
                        color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => widget.onToggleFavorite(s.stopId),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 20,
                      color: fav ? const Color(starColor) : Colors.black26,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (arrivals == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child:
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (arrivals.isEmpty)
              Text(
                  widget.api.connected.value
                      ? 'No upcoming trains'
                      : "Can't reach the server",
                  style: const TextStyle(color: Colors.black38, fontSize: 12))
            else
              for (final a in arrivals.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(lineColors[a.line] ?? 0xFFFFFFFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('→ ${a.destinoName}',
                            style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ),
                      Text(fmtEta(a.etaSeconds),
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
