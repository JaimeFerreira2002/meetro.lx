/// Live list of all circulating trains, sorted by line then arrival.
/// Tapping a train selects it (camera follows).
import 'package:flutter/material.dart';

import 'line_stripe.dart';
import 'models.dart';
import 'stations_panel.dart' show fmtEta;

class TrainsList extends StatelessWidget {
  final List<TrainPosition> trains;
  final void Function(TrainPosition) onSelect;

  const TrainsList({super.key, required this.trains, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sorted = [...trains]..sort((a, b) {
        final byLine = lineOrder.indexOf(a.line).compareTo(lineOrder.indexOf(b.line));
        return byLine != 0 ? byLine : a.etaSeconds.compareTo(b.etaSeconds);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StripeHeader(icon: Icons.directions_subway_rounded, title: 'Trains (${sorted.length})'),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No trains circulating',
                style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500)),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sorted.length,
              itemBuilder: (_, i) => _row(sorted[i]),
            ),
          ),
      ],
    );
  }

  Widget _row(TrainPosition t) {
    final color = Color(lineColors[t.line] ?? 0xFF9E9E9E);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text('Train ${t.trainId}  →  ${t.destinoName}',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('Next: ${t.nextStopName}',
          style: const TextStyle(color: Colors.black45, fontSize: 12)),
      trailing: Text(fmtEta(t.etaSeconds),
          style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w800)),
      onTap: () => onSelect(t),
    );
  }
}
