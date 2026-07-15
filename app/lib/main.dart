/// Phase 1 Flutter client: a 2D live map mirroring the web debug view.
/// This is also the app's fallback/indoor mode; the AR camera view (Phase 2)
/// is a separate native platform-view screen that reuses [MetroApi].
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'glass.dart';
import 'line_stripe.dart';
import 'metro_api.dart';
import 'models.dart';
import 'search_box.dart';
import 'splash.dart';
import 'station_details.dart';
import 'stations_panel.dart';

void main() => runApp(const MetroApp());

class MetroApp extends StatelessWidget {
  const MetroApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Metro Lisboa AR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const _Root(),
      );
}

/// Splash first, then the map.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _ready
          ? const MapScreen()
          : SplashScreen(onDone: () => setState(() => _ready = true)),
    );
  }
}

enum MapStyle { cozy, minimal, light, dark }

extension MapStyleX on MapStyle {
  // All keyless: CARTO raster basemaps (© OpenStreetMap contributors © CARTO).
  String get url => switch (this) {
        MapStyle.cozy => 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
        MapStyle.minimal =>
          'https://basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
        MapStyle.light => 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
        MapStyle.dark => 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      };
  String get label => switch (this) {
        MapStyle.cozy => 'Cozy',
        MapStyle.minimal => 'Minimal',
        MapStyle.light => 'Light',
        MapStyle.dark => 'Dark',
      };
  IconData get icon => switch (this) {
        MapStyle.cozy => Icons.local_cafe_rounded,
        MapStyle.minimal => Icons.layers_clear_rounded,
        MapStyle.light => Icons.light_mode_rounded,
        MapStyle.dark => Icons.dark_mode_rounded,
      };
}

// Cozy palette
const _ink = Colors.black87;
const _inkSoft = Colors.black45;
const _ok = Color(0xFF34C759);
const _warn = Color(0xFFFF9F0A);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _api = MetroApi();
  final _mapController = MapController();

  int _tab = 0; // 0 map, 1 stations, 2 info, 3 settings
  MapStyle _style = MapStyle.cozy;

  List<TrackLine> _track = [];
  List<Station> _stations = [];
  List<TrainPosition> _trains = [];
  List<LineStatus> _lines = [];
  LatLng? _userLocation;
  Station? _selectedStation;
  String? _followTrainId; // camera auto-follows this train
  Timer? _linesTimer;

  @override
  void initState() {
    super.initState();
    _api.track().then((t) => setState(() => _track = t));
    _api.stations().then((s) => setState(() => _stations = s));
    _api.trainStream().listen(_onTrains);
    _refreshLines();
    _linesTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshLines());
    _requestLocationPermission();
  }

  void _onTrains(List<TrainPosition> t) {
    setState(() => _trains = t);
    // keep the camera centered on the followed train as it moves
    final id = _followTrainId;
    if (id != null) {
      final match = t.where((x) => x.trainId == id);
      if (match.isNotEmpty) {
        _mapController.move(match.first.pos, _mapController.camera.zoom);
      }
    }
  }

  void _followTrain(TrainPosition t) {
    setState(() {
      _followTrainId = t.trainId;
      _selectedStation = null;
    });
    _mapController.move(t.pos, 15);
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_subway_rounded, color: _ink, size: 20),
                            const SizedBox(width: 8),
                            Text('${_trains.length}',
                                style: const TextStyle(
                                    color: _ink, fontSize: 24, fontWeight: FontWeight.w800, height: 1)),
                            const SizedBox(width: 6),
                            const Text('trains live',
                                style: TextStyle(
                                    color: _inkSoft, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const LineStripe(width: 72, height: 3, gap: 2),
                      ],
                    ),
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
                    child: Icon(Icons.my_location_rounded, color: _ink),
                  ),
                ),
              ),
            ),
          ),

          // Animated panels (slide up + fade between states)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _panelContent(),
                ),
              ),
            ),
          ),

          _navBar(),
        ],
      ),
    );
  }

  // ---- panels ----

  Widget _panelContent() {
    final Widget? inner;
    final Key key;
    if (_followTrainId != null) {
      inner = _followContent();
      key = const ValueKey('follow');
    } else if (_selectedStation != null) {
      inner = StationDetailsPanel(
        api: _api,
        station: _selectedStation!,
        onClose: () => setState(() => _selectedStation = null),
      );
      key = const ValueKey('station');
    } else if (_tab == 1) {
      inner = StationsList(api: _api, stations: _stations);
      key = const ValueKey('stations');
    } else if (_tab == 2) {
      inner = SingleChildScrollView(child: _infoContent());
      key = const ValueKey('info');
    } else if (_tab == 3) {
      inner = SingleChildScrollView(child: _settingsContent());
      key = const ValueKey('settings');
    } else {
      return const SizedBox.shrink(key: ValueKey('none'));
    }
    return ConstrainedBox(
      key: key,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: GlassPanel(child: inner),
    );
  }

  Widget _followContent() {
    final matches = _trains.where((t) => t.trainId == _followTrainId).toList();
    final close = GestureDetector(
      onTap: () => setState(() => _followTrainId = null),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), shape: BoxShape.circle),
        child: const Icon(Icons.close_rounded, color: Colors.black54, size: 18),
      ),
    );
    if (matches.isEmpty) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        StripeHeader(
            icon: Icons.directions_subway_rounded, title: 'Train $_followTrainId', trailing: close),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('This train is no longer live',
              style: TextStyle(color: _inkSoft, fontWeight: FontWeight.w500)),
        ),
      ]);
    }
    final t = matches.first;
    final color = Color(lineColors[t.line] ?? 0xFF9E9E9E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StripeHeader(
            icon: Icons.directions_subway_rounded, title: 'Train ${t.trainId}', trailing: close),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(t.line, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Spacer(),
          const Icon(Icons.my_location_rounded, color: _inkSoft, size: 16),
          const SizedBox(width: 4),
          const Text('following', style: TextStyle(color: _inkSoft, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 14),
        Text('→ ${t.destinoName}',
            style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text('Next: ${t.nextStopName}',
                style: const TextStyle(color: _inkSoft, fontWeight: FontWeight.w500)),
          ),
          Text(fmtEta(t.etaSeconds),
              style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          const Padding(
            padding: EdgeInsets.only(bottom: 3),
            child: Text('min', style: TextStyle(color: _inkSoft, fontSize: 12)),
          ),
        ]),
      ],
    );
  }

  Widget _infoContent() {
    final disrupted = _lines.where((l) => !l.isNormal).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const StripeHeader(icon: Icons.info_rounded, title: 'Service status'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_trains.length}',
                style: const TextStyle(
                    color: _ink, fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('trains circulating',
                  style: TextStyle(color: _inkSoft, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final line in lineOrder) _lineRow(line),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.warning_rounded, color: _ink, size: 18),
          const SizedBox(width: 8),
          Text(disrupted.isEmpty ? 'Warnings' : 'Warnings (${disrupted.length})',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        if (disrupted.isEmpty)
          const Row(children: [
            Icon(Icons.check_circle, color: _ok, size: 18),
            SizedBox(width: 8),
            Text('All lines running normally',
                style: TextStyle(color: _inkSoft, fontWeight: FontWeight.w500)),
          ])
        else
          for (final l in disrupted)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${l.line}: ${l.detail.isEmpty ? l.status : l.detail}',
                  style: const TextStyle(color: _warn, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Color(lineColors[line] ?? 0xFFFFFFFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(line, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
          ),
          Text('${_countFor(line)}',
              style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          const Text('trains', style: TextStyle(color: _inkSoft, fontSize: 12)),
          const SizedBox(width: 12),
          Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded,
              color: ok ? _ok : _warn, size: 18),
        ],
      ),
    );
  }

  Widget _settingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const StripeHeader(icon: Icons.settings_rounded, title: 'Settings'),
        const SizedBox(height: 16),
        const Row(children: [
          Icon(Icons.layers_rounded, color: _inkSoft, size: 18),
          SizedBox(width: 6),
          Text('Map style', style: TextStyle(color: _inkSoft, fontWeight: FontWeight.w500)),
        ]),
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
            color: selected ? _ink : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(s.icon, size: 20, color: selected ? Colors.white : _ink),
              const SizedBox(height: 4),
              Text(
                s.label,
                style: TextStyle(
                  color: selected ? Colors.white : _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.translate(
            offset: Offset(0, (1 - v) * 80),
            child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
          ),
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
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _tab == index && _selectedStation == null && _followTrainId == null;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = index;
        _selectedStation = null;
        _followTrainId = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: selected ? Colors.white : _inkSoft),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
          _followTrainId = null;
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
    final followed = t.trainId == _followTrainId;
    return Marker(
      point: t.pos,
      width: followed ? 44 : 32,
      height: followed ? 44 : 32,
      child: GestureDetector(
        onTap: () => _followTrain(t),
        child: Tooltip(
          message: '${t.trainId} → ${t.destinoName}\n'
              'next: ${t.nextStopName} in ${(t.etaSeconds / 60).floor()}:'
              '${(t.etaSeconds % 60).round().toString().padLeft(2, '0')}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: followed ? 4 : 3),
              boxShadow: followed
                  ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 14, spreadRadius: 2)]
                  : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
            ),
            padding: EdgeInsets.all(followed ? 4 : 3),
            child: Image.asset(
              'assets/icons/metro.png',
              errorBuilder: (_, __, ___) =>
                  Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
          ),
        ),
      ),
    );
  }
}
