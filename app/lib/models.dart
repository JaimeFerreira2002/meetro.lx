/// Wire-contract models — mirror server/app/models.py.
import 'package:latlong2/latlong.dart';

const lineColors = <String, int>{
  'Amarela': 0xFFF2C200,
  'Azul': 0xFF0A6CB0,
  'Verde': 0xFF009A44,
  'Vermelha': 0xFFD2222D,
};

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
