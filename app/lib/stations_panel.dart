/// Expandable list of all stations; each row expands to show the next trains
/// (fetched from GET /station/{id}/arrivals on demand).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'line_logo.dart';
import 'line_stripe.dart';
import 'metro_api.dart';
import 'models.dart';
import 'schedule.dart';
import 'strings.dart';

String fmtEta(double s) => '${(s / 60).floor()}:${(s % 60).round().toString().padLeft(2, '0')}';

/// An ETA fetched at [since], re-aged to [now]; never negative.
double agedEta(double seconds, DateTime since, DateTime now) {
  final aged = seconds - now.difference(since).inSeconds;
  return aged < 0 ? 0 : aged;
}

/// A countdown that stays live between fetches. Arrival ETAs are fetched
/// on-demand (and only refreshed every ~20s), so a plain `fmtEta(eta)` sits
/// frozen and then jumps. This re-ages the ETA from when it was fetched and
/// ticks every second, so the number actually counts down on screen.
class LiveEta extends StatefulWidget {
  final double seconds; // ETA at fetch time
  final DateTime since; // when the arrivals were fetched
  final TextStyle? style;

  const LiveEta({super.key, required this.seconds, required this.since, this.style});

  @override
  State<LiveEta> createState() => _LiveEtaState();
}

class _LiveEtaState extends State<LiveEta> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(fmtEta(agedEta(widget.seconds, widget.since, DateTime.now())), style: widget.style);
  }
}

class StationsList extends StatefulWidget {
  final MetroApi api;
  final List<Station> stations;
  final Set<String> favorites;
  final void Function(String stopId) onToggleFavorite;

  const StationsList({
    super.key,
    required this.api,
    required this.stations,
    required this.favorites,
    required this.onToggleFavorite,
  });

  @override
  State<StationsList> createState() => _StationsListState();
}

class _StationsListState extends State<StationsList> {
  // stopId -> arrivals (null = loading)
  final Map<String, List<Arrival>?> _arrivals = {};
  final Map<String, DateTime> _fetchedAt = {}; // when each stop's ETAs were fetched

  String? _lineFilter; // null = every line

  Future<void> _load(String stopId) async {
    setState(() => _arrivals[stopId] = null);
    final a = await widget.api.arrivals(stopId);
    if (mounted) {
      setState(() {
        _arrivals[stopId] = a;
        _fetchedAt[stopId] = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.stations]..sort((a, b) => a.name.compareTo(b.name));
    final stations =
        _lineFilter == null ? all : all.where((s) => s.lines.contains(_lineFilter)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StripeHeader(
          icon: Icons.pin_drop_rounded,
          title: '${tr('Stations', 'Estações')} (${stations.length})',
          lines: _lineFilter == null ? null : [_lineFilter!],
        ),
        const SizedBox(height: 10),
        _filterBar(),
        const SizedBox(height: 4),
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

  Widget _filterBar() => SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _chip(null),
            for (final line in lineOrder) _chip(line),
          ],
        ),
      );

  Widget _chip(String? line) {
    final selected = _lineFilter == line;
    final color = line == null ? Colors.black87 : Color(lineColors[line]!);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _lineFilter = line);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: line == null ? 14 : 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (line != null) ...[
                LineLogo(line, height: 14),
                const SizedBox(width: 6),
              ],
              Text(line ?? tr('All', 'Todas'),
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Station s) {
    final fav = widget.favorites.contains(s.stopId);
    return ExpansionTile(
      // Without a stable key, expansion state sticks to list position — after
      // filtering, a different station would appear open.
      key: ValueKey(s.stopId),
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
          // Tapping the star toggles the favourite without expanding the row —
          // the gesture detector claims the tap before the ExpansionTile does.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onToggleFavorite(s.stopId);
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                fav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: fav ? const Color(starColor) : Colors.black38,
                size: 20,
              ),
            ),
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
          child: Text(noTrainsLabel(widget.api.connected.value),
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
                  LiveEta(
                      seconds: a.etaSeconds,
                      since: _fetchedAt[stopId] ?? DateTime.now(),
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
