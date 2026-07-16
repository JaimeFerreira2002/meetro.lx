/// "Nearby" panel: the closest stations to you, each with its live next trains
/// (per direction). The daily-use view — glance and see when your train comes.
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

  const NearbyPanel({
    super.key,
    required this.api,
    required this.stations,
    required this.location,
    required this.onTapStation,
  });

  @override
  State<NearbyPanel> createState() => _NearbyPanelState();
}

class _NearbyPanelState extends State<NearbyPanel> {
  static const _count = 6;
  List<Station> _nearest = [];
  final Map<String, List<Arrival>?> _arrivals = {}; // null = loading
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _computeNearest();
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAll());
  }

  @override
  void didUpdateWidget(NearbyPanel old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location || old.stations.length != widget.stations.length) {
      _computeNearest();
      _loadAll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _computeNearest() {
    final sorted = [...widget.stations]
      ..sort((a, b) =>
          _distanceM(widget.location, a.pos).compareTo(_distanceM(widget.location, b.pos)));
    _nearest = sorted.take(_count).toList();
  }

  Future<void> _loadAll() async {
    for (final s in _nearest) {
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
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _nearest.length,
            separatorBuilder: (_, __) => Divider(color: Colors.black.withOpacity(0.06), height: 20),
            itemBuilder: (_, i) => _stationBlock(_nearest[i]),
          ),
        ),
      ],
    );
  }

  Widget _stationBlock(Station s) {
    final dist = _distanceM(widget.location, s.pos);
    final arrivals = _arrivals[s.stopId];
    return InkWell(
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
                  style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          if (arrivals == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (arrivals.isEmpty)
            const Text('No upcoming trains',
                style: TextStyle(color: Colors.black38, fontSize: 12))
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
    );
  }
}
