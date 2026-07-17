/// Wire-contract models — mirror server/app/models.py.
import 'package:latlong2/latlong.dart';

/// Line colours — the single source of truth for line colour anywhere in the
/// app (markers, stripes, track polylines, panels).
///
/// These are taken from the official line pictograms in assets/icons/*.svg,
/// which the meetro logo's stripe also matches — so the map, the pictograms
/// and the brand all agree.
const lineColors = <String, int>{
  'Amarela': 0xFFF7A800,
  'Azul': 0xFF2F7DE1,
  'Verde': 0xFF00A19B,
  'Vermelha': 0xFFEA1D76,
};

/// Favourite-star gold (matches the yellow line). ARGB int, like [lineColors].
const starColor = 0xFFF7A800;

/// Display order for the four lines.
const lineOrder = <String>['Azul', 'Amarela', 'Verde', 'Vermelha'];

class LineStatus {
  final String line;
  final String status;   // e.g. "Ok"
  final String detail;   // disruption message when present

  LineStatus({required this.line, required this.status, required this.detail});

  bool get isNormal => status.trim().toLowerCase() == 'ok';

  factory LineStatus.fromJson(Map<String, dynamic> j) => LineStatus(
        line: j['line'] as String,
        status: (j['status'] as String? ?? '').trim(),
        detail: (j['detail'] as String? ?? '').trim(),
      );
}

/// One line+direction track polyline from GET /track (baked OSM geometry).
class TrackLine {
  final String line;
  final int color;          // ARGB
  final List<LatLng> points;

  TrackLine({required this.line, required this.color, required this.points});

  factory TrackLine.fromFeature(Map<String, dynamic> f) {
    final props = f['properties'] as Map<String, dynamic>;
    final coords = f['geometry']['coordinates'] as List;
    final line = props['line'] as String? ?? '';
    return TrackLine(
      line: line,
      // Prefer the official palette so track lines match the markers; the
      // GeoJSON's `colour` is OpenStreetMap's own (different) shade.
      color: lineColors[line] ?? _hexToArgb(props['colour'] as String?),
      // GeoJSON is [lon, lat]
      points: coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList(),
    );
  }
}

int _hexToArgb(String? hex) {
  if (hex == null || hex.isEmpty) return 0xFF888888;
  return 0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16);
}

/// A geocoded place from search (Nominatim) or a matched station.
class Place {
  final String name;
  final LatLng pos;
  final Station? station; // non-null when the result is one of our stations

  Place({required this.name, required this.pos, this.station});
}

class Arrival {
  final String trainId;
  final String line;
  final String destinoName;
  final double etaSeconds;

  Arrival({required this.trainId, required this.line, required this.destinoName, required this.etaSeconds});

  factory Arrival.fromJson(Map<String, dynamic> j) => Arrival(
        trainId: j['train_id'] as String,
        line: j['line'] as String,
        destinoName: j['destino_name'] as String,
        etaSeconds: (j['eta_seconds'] as num).toDouble(),
      );
}

class Station {
  final String stopId;
  final String name;
  final LatLng pos;
  final List<String> lines;

  Station({required this.stopId, required this.name, required this.pos, required this.lines});

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        stopId: j['stop_id'] as String,
        name: j['name'] as String,
        pos: LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
        lines: (j['lines'] as List).cast<String>(),
      );
}

class TrainPosition {
  final String trainId;
  final String line;
  final String destinoName;
  final String nextStopName;
  final double etaSeconds;
  final LatLng pos;
  final double bearing;
  final double speedMps;

  TrainPosition({
    required this.trainId,
    required this.line,
    required this.destinoName,
    required this.nextStopName,
    required this.etaSeconds,
    required this.pos,
    required this.bearing,
    required this.speedMps,
  });

  factory TrainPosition.fromJson(Map<String, dynamic> j) => TrainPosition(
        trainId: j['train_id'] as String,
        line: j['line'] as String,
        destinoName: j['destino_name'] as String,
        nextStopName: j['next_stop_name'] as String,
        etaSeconds: (j['eta_seconds'] as num).toDouble(),
        pos: LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
        bearing: (j['bearing'] as num).toDouble(),
        speedMps: (j['speed_mps'] as num).toDouble(),
      );
}
