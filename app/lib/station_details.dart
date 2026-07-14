/// Station details panel: opens when a station dot on the map is tapped.
/// Shows the station name, its lines, and the next trains (live arrivals).
import 'package:flutter/material.dart';

import 'metro_api.dart';
import 'models.dart';
import 'stations_panel.dart' show fmtEta;

class StationDetailsPanel extends StatefulWidget {
  final MetroApi api;
  final Station station;
  final VoidCallback onClose;

  const StationDetailsPanel({
    super.key,
    required this.api,
    required this.station,
    required this.onClose,
  });

  @override
  State<StationDetailsPanel> createState() => _StationDetailsPanelState();
}

class _StationDetailsPanelState extends State<StationDetailsPanel> {
  List<Arrival>? _arrivals;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StationDetailsPanel old) {
    super.didUpdateWidget(old);
    if (old.station.stopId != widget.station.stopId) {
      setState(() => _arrivals = null);
      _load();
    }
  }

  Future<void> _load() async {
    final a = await widget.api.arrivals(widget.station.stopId);
    if (mounted) setState(() => _arrivals = a);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            GestureDetector(
              onTap: widget.onClose,
              child: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final line in s.lines)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(lineColors[line] ?? 0xFFFFFFFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(line, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Next trains',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _body(),
      ],
    );
  }

  Widget _body() {
    final arrivals = _arrivals;
    if (arrivals == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (arrivals.isEmpty) {
      return Text('No upcoming trains', style: TextStyle(color: Colors.white.withOpacity(0.6)));
    }
    return Column(
      children: [
        for (final a in arrivals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
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
                  child: Text('→ ${a.destinoName}', style: const TextStyle(color: Colors.white)),
                ),
                Text(fmtEta(a.etaSeconds),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
