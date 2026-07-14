/// Phase 1 Flutter client: a 2D live map mirroring the web debug view.
/// This is also the app's fallback/indoor mode; the AR camera view (Phase 2)
/// is a separate native platform-view screen that reuses [MetroApi].
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'metro_api.dart';
import 'models.dart';

void main() => runApp(const MetroApp());

class MetroApp extends StatelessWidget {
  const MetroApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Metro Lisboa AR',
        theme: ThemeData.dark(useMaterial3: true),
        home: const MapScreen(),
      );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _api = MetroApi();
  List<Station> _stations = [];
  List<TrainPosition> _trains = [];

  @override
  void initState() {
    super.initState();
    _api.stations().then((s) => setState(() => _stations = s));
    _api.trainStream().listen((t) => setState(() => _trains = t));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(38.728, -9.145),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pt.metrolisboa.ar',
              ),
              MarkerLayer(markers: _stations.map(_stationMarker).toList()),
              MarkerLayer(markers: _trains.map(_trainMarker).toList()),
            ],
          ),
          Positioned(
            top: 48,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_trains.length} trains · live',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Marker _stationMarker(Station s) => Marker(
        point: s.pos,
        width: 8,
        height: 8,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
      );

  Marker _trainMarker(TrainPosition t) => Marker(
        point: t.pos,
        width: 16,
        height: 16,
        child: Tooltip(
          message: '${t.trainId} → ${t.destinoName}\n'
              'next: ${t.nextStopName} in ${(t.etaSeconds / 60).floor()}:'
              '${(t.etaSeconds % 60).round().toString().padLeft(2, '0')}',
          child: Container(
            decoration: BoxDecoration(
              color: Color(lineColors[t.line] ?? 0xFFFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
          ),
        ),
      );
}
