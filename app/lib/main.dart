/// Phase 1 Flutter client: a 2D live map mirroring the web debug view.
/// This is also the app's fallback/indoor mode; the AR camera view (Phase 2)
/// is a separate native platform-view screen that reuses [MetroApi].
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'glass.dart';
import 'metro_api.dart';
import 'models.dart';
import 'search_box.dart';
import 'station_details.dart';
import 'stations_panel.dart';

void main() => runApp(const MetroApp());

class MetroApp extends StatelessWidget {
  const MetroApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Metro Lisboa AR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const MapScreen(),
      );
}

enum MapStyle { standard, light, dark }

extension MapStyleX on MapStyle {
  String get url => switch (this) {
        MapStyle.standard => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        MapStyle.light => 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
        MapStyle.dark => 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      };
  String get label => switch (this) {
        MapStyle.standard => 'Standard',
        MapStyle.light => 'Light',
        MapStyle.dark => 'Dark',
      };
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _api = MetroApi();
  final _mapController = MapController();

  int _tab = 0; // 0 map, 1 stations, 2 info, 3 settings
  MapStyle _style = MapStyle.standard;

  List<TrackLine> _track = [];
  List<Station> _stations = [];
  List<TrainPosition> _trains = [];
  List<LineStatus> _lines = [];
  LatLng? _userLocation;
  Station? _selectedStation;
  Timer? _linesTimer;

  @override
  void initState() {
    super.initState();
    _api.track().then((t) => setState(() => _track = t));
    _api.stations().then((s) => setState(() => _stations = s));
    _api.trainStream().listen((t) => setState(() => _trains = t));
    _refreshLines();
    _linesTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshLines());
    _requestLocationPermission();
  }

  Future<void> _refreshLines() async {
    final l = await _api.lines();
    if (mounted) setState(() => _lines = l);
  }

  @override
  void dispose() {
    _linesTimer?.cancel();
    super.dispose();
  }

  int _countFor(String line) => _trains.where((t) => t.line == line).length;

  // ---- location ----

  Future<void> _requestLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission(); // triggers the OS pop-up
    }
  }

  Future<void> _goToMyLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition();
    final ll = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() => _userLocation = ll);
    _mapController.move(ll, 15);
  }

  void _flyTo(LatLng target, Station? station) {
    _mapController.move(target, station != null ? 15 : 14);
    if (station != null) setState(() => _selectedStation = station);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(38.728, -9.145),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: _style.url,
                userAgentPackageName: 'pt.metrolisboa.ar',
              ),
              PolylineLayer(
                polylines: _track
                    .map((t) => Polyline(
                          points: t.points,
                          color: Color(t.color).withOpacity(0.6),
                          strokeWidth: 4,
                        ))
                    .toList(),
              ),
              MarkerLayer(markers: _stations.map(_stationMarker).toList()),
              MarkerLayer(markers: _trains.map(_trainMarker).toList()),
              if (_userLocation != null)
                MarkerLayer(markers: [_userMarker(_userLocation!)]),
            ],
          ),

          // Top: search + live count
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchBox(api: _api, stations: _stations, onPick: _flyTo),
                  const SizedBox(height: 8),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: Text('${_trains.length} trains · live',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          // Home / my-location button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 96),
                child: GestureDetector(
                  onTap: _goToMyLocation,
                  child: const GlassPanel(
                    padding: EdgeInsets.all(14),
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                    child: Icon(Icons.my_location_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          // Panels — station details takes priority over the nav panels
          if (_selectedStation != null)
            _panelShell(StationDetailsPanel(
              api: _api,
              station: _selectedStation!,
              onClose: () => setState(() => _selectedStation = null),
            ))
          else if (_tab == 1)
            _panelShell(StationsList(api: _api, stations: _stations))
          else if (_tab == 2)
            _panelShell(SingleChildScrollView(child: _infoContent()))
          else if (_tab == 3)
            _panelShell(SingleChildScrollView(child: _settingsContent())),

          _navBar(),
        ],
      ),
    );
  }

  // ---- panels ----

  Widget _panelShell(Widget child) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: GlassPanel(child: child),
          ),
        ),
      ),
    );
  }

  Widget _infoContent() {
    final disrupted = _lines.where((l) => !l.isNormal).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Service status',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${_trains.length} trains circulating',
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 16),
        for (final line in lineOrder) _lineRow(line),
        const SizedBox(height: 16),
        Text(disrupted.isEmpty ? 'Warnings' : 'Warnings (${disrupted.length})',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (disrupted.isEmpty)
          Row(children: [
            const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 18),
            const SizedBox(width: 8),
            Text('All lines running normally',
                style: TextStyle(color: Colors.white.withOpacity(0.8))),
          ])
        else
          for (final l in disrupted)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${l.line}: ${l.detail.isEmpty ? l.status : l.detail}',
                  style: const TextStyle(color: Color(0xFFFF9F0A))),
            ),
      ],
    );
  }

  Widget _lineRow(String line) {
    final status = _lines.firstWhere(
      (l) => l.line == line,
      orElse: () => LineStatus(line: line, status: '—', detail: ''),
    );
    final ok = status.isNormal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(lineColors[line] ?? 0xFFFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(line,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          Text('${_countFor(line)} trains',
              style: TextStyle(color: Colors.white.withOpacity(0.6))),
          const SizedBox(width: 12),
          Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded,
              color: ok ? const Color(0xFF34C759) : const Color(0xFFFF9F0A), size: 18),
        ],
      ),
    );
  }

  Widget _settingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Settings',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Text('Map style', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final s in MapStyle.values) ...[
              _styleChip(s),
              if (s != MapStyle.values.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }

  Widget _styleChip(MapStyle s) {
    final selected = _style == s;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _style = s),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(selected ? 0.9 : 0.3)),
          ),
          child: Text(
            s.label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ---- nav bar ----

  Widget _navBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            borderRadius: const BorderRadius.all(Radius.circular(30)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _navItem(Icons.map_rounded, 'Map', 0),
                _navItem(Icons.pin_drop_rounded, 'Stations', 1),
                _navItem(Icons.info_rounded, 'Info', 2),
                _navItem(Icons.settings_rounded, 'Settings', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _tab == index && _selectedStation == null;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = index;
        _selectedStation = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.85) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: selected ? Colors.black : Colors.white),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  // ---- markers ----

  Marker _stationMarker(Station s) {
    final color = Color(lineColors[s.lines.isNotEmpty ? s.lines.first : ''] ?? 0xFF9E9E9E);
    return Marker(
      point: s.pos,
      width: 22,
      height: 22,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedStation = s;
          _tab = 0;
        }),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }

  Marker _userMarker(LatLng p) => Marker(
        point: p,
        width: 22,
        height: 22,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A84FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4)],
          ),
        ),
      );

  Marker _trainMarker(TrainPosition t) {
    final color = Color(lineColors[t.line] ?? 0xFFFFFFFF);
    return Marker(
      point: t.pos,
      width: 32,
      height: 32,
      child: Tooltip(
        message: '${t.trainId} → ${t.destinoName}\n'
            'next: ${t.nextStopName} in ${(t.etaSeconds / 60).floor()}:'
            '${(t.etaSeconds % 60).round().toString().padLeft(2, '0')}',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
          ),
          padding: const EdgeInsets.all(3),
          child: Image.asset(
            'assets/icons/metro.png',
            errorBuilder: (_, __, ___) =>
                Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
        ),
      ),
    );
  }
}
