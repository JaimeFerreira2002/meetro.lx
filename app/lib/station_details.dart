/// Station details panel: opens when a station dot on the map is tapped.
/// Shows the station name, its lines, and the next trains (live arrivals).
import 'package:flutter/material.dart';

import 'line_stripe.dart';
import 'metro_api.dart';
import 'models.dart';
import 'stations_panel.dart' show fmtEta;

class StationDetailsPanel extends StatefulWidget {
  final MetroApi api;
  final Station station;
  final VoidCallback onClose;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const StationDetailsPanel({
    super.key,
    required this.api,
    required this.station,
    required this.onClose,
    required this.isFavorite,
    required this.onToggleFavorite,
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
        StripeHeader(
          icon: Icons.pin_drop_rounded,
          title: s.name,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: widget.onToggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    widget.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: widget.isFavorite ? const Color(0xFFF2C200) : Colors.black38,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.black54, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final line in s.lines)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(lineColors[line] ?? 0xFFFFFFFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(lineColors[line] ?? 0xFFFFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(line,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(children: [
          Icon(Icons.schedule_rounded, color: Colors.black87, size: 18),
          SizedBox(width: 8),
          Text('Next trains',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
        ]),
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
      return const Text('No upcoming trains',
          style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500));
    }
    return Column(
      children: [
        for (final a in arrivals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
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
                        color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                const Text('min', style: TextStyle(color: Colors.black45, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}
