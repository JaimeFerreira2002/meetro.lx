/// Expandable list of all stations; each row expands to show the next trains
/// (fetched from GET /station/{id}/arrivals on demand).
import 'package:flutter/material.dart';

import 'line_stripe.dart';
import 'metro_api.dart';
import 'models.dart';

String fmtEta(double s) => '${(s / 60).floor()}:${(s % 60).round().toString().padLeft(2, '0')}';

class StationsList extends StatefulWidget {
  final MetroApi api;
  final List<Station> stations;

  const StationsList({super.key, required this.api, required this.stations});

  @override
  State<StationsList> createState() => _StationsListState();
}

class _StationsListState extends State<StationsList> {
  // stopId -> arrivals (null = loading)
  final Map<String, List<Arrival>?> _arrivals = {};

  Future<void> _load(String stopId) async {
    setState(() => _arrivals[stopId] = null);
    final a = await widget.api.arrivals(stopId);
    if (mounted) setState(() => _arrivals[stopId] = a);
  }

  @override
  Widget build(BuildContext context) {
    final stations = [...widget.stations]..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StripeHeader(icon: Icons.pin_drop_rounded, title: 'Stations (${stations.length})'),
        const SizedBox(height: 8),
        Flexible(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: stations.length,
              itemBuilder: (_, i) => _tile(stations[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(Station s) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: Colors.black45,
      collapsedIconColor: Colors.black45,
      onExpansionChanged: (open) {
        if (open && !_arrivals.containsKey(s.stopId)) _load(s.stopId);
      },
      title: Row(
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
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      children: [_arrivalsBody(s.stopId)],
    );
  }

  Widget _arrivalsBody(String stopId) {
    final arrivals = _arrivals[stopId];
    if (arrivals == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (arrivals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              widget.api.connected.value ? 'No upcoming trains' : "Can't reach the server",
              style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w500)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (final a in arrivals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(lineColors[a.line] ?? 0xFFFFFFFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('→ ${a.destinoName}',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                  ),
                  Text(fmtEta(a.etaSeconds),
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  const Text('min', style: TextStyle(color: Colors.black45, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
