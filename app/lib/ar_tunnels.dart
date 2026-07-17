/// AR view (Phase 2, v0): visualize the metro tunnels below you through the camera.
///
/// iOS only, and ONLY runs on a PHYSICAL device — ARKit is unavailable in the
/// simulator. Alignment uses the device GPS + compass (ARKit
/// `gravityAndHeading`), so it's accurate to a few metres and can be off by the
/// compass error. The accurate upgrade is Google's ARCore Geospatial VPS (later).
///
/// Two modes:
///  - REAL: fetches the baked OSM track geometry from the backend, converts each
///    point to local metres relative to your GPS, and places line-coloured
///    markers ~18 m underground. Only shows anything within ~1.5 km of a line.
///  - TEST: a synthetic line with two moving trains, built directly in local
///    metres around wherever you're standing. Lets you exercise the AR view far
///    from Lisbon (e.g. the Algarve), where real geometry is out of range.
import 'dart:async';
import 'dart:math' as math;

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'line_stripe.dart';
import 'metro_api.dart';
import 'models.dart';
import 'strings.dart';

/// A mock train: a node that glides along the test polyline and wraps around.
class _MockTrain {
  final ARKitNode node;
  double distance; // metres along the polyline
  final double speed; // m/s, signed (direction)
  _MockTrain(this.node, this.distance, this.speed);
}

class ArTunnelsScreen extends StatefulWidget {
  final MetroApi api;
  const ArTunnelsScreen({super.key, required this.api});

  @override
  State<ArTunnelsScreen> createState() => _ArTunnelsScreenState();
}

class _ArTunnelsScreenState extends State<ArTunnelsScreen> {
  // Real mode
  static const double _tunnelDepth = 18; // metres below the device
  static const double _maxRange = 1500; // metres — cull distant points
  static const int _step = 3; // downsample polylines to keep node count sane

  // Test mode
  static const double _testDepth = 6; // shallower, so it's easy to see
  static const double _testLineLength = 420; // metres
  static const int _testMarker = 8; // metres between tunnel markers
  static const int _mockLineColor = 0xFFF7A800; // Amarela — bright, visible

  ARKitController? _controller;
  String _status = 'Starting AR…';
  int _placed = 0;
  bool _testMode = true; // start in test mode — nothing real is in range here

  // Scene bookkeeping so a rebuild can clear the previous scene.
  final List<String> _nodeNames = [];
  final List<_MockTrain> _trains = [];
  List<vm.Vector3> _mockPath = const [];
  List<double> _mockCum = const []; // cumulative arc length
  Timer? _anim;
  double? _lat, _lon;

  @override
  void dispose() {
    _anim?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onCreated(ARKitController controller) async {
    _controller = controller;
    try {
      setState(() => _status = tr('Getting your location…', 'A obter a localização…'));
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lon = pos.longitude;
      await _rebuild();
    } catch (e) {
      setState(() => _status = tr('AR failed: $e', 'Falha no AR: $e'));
    }
  }

  // ---- scene lifecycle ----

  Future<void> _clearScene() async {
    _anim?.cancel();
    _anim = null;
    final c = _controller;
    if (c != null) {
      for (final name in _nodeNames) {
        await c.remove(name);
      }
    }
    _nodeNames.clear();
    _trains.clear();
    _placed = 0;
  }

  Future<void> _rebuild() async {
    await _clearScene();
    final c = _controller;
    if (c == null) return;
    if (_testMode) {
      _drawMock(c);
    } else {
      setState(() => _status = tr('Loading tunnels…', 'A carregar túneis…'));
      final tracks = await widget.api.track();
      _drawReal(c, tracks);
    }
  }

  void _add(ARKitController c, ARKitNode node) {
    c.add(node);
    _nodeNames.add(node.name);
  }

  // ---- real tunnels ----

  void _drawReal(ARKitController c, List<TrackLine> tracks) {
    final lat0 = _lat, lon0 = _lon;
    if (lat0 == null || lon0 == null) return;
    const mPerLat = 111320.0;
    final mPerLon = 111320.0 * math.cos(lat0 * math.pi / 180);
    var placed = 0;

    for (final t in tracks) {
      final color = Color(t.color);
      for (var i = 0; i < t.points.length; i += _step) {
        final p = t.points[i];
        final east = (p.longitude - lon0) * mPerLon;
        final north = (p.latitude - lat0) * mPerLat;
        if (east.abs() > _maxRange || north.abs() > _maxRange) continue;

        // gravityAndHeading world: +X east, +Y up, +Z south (so north = -Z)
        _add(
          c,
          ARKitNode(
            geometry: ARKitSphere(
              radius: 0.6,
              materials: [ARKitMaterial(diffuse: ARKitMaterialProperty.color(color))],
            ),
            position: vm.Vector3(east, -_tunnelDepth, -north),
          ),
        );
        placed++;
      }
    }
    setState(() {
      _placed = placed;
      _status = placed == 0
          ? tr('No tunnels within range (you are far from a line)',
              'Sem túneis por perto (está longe de uma linha)')
          : '';
    });
  }

  // ---- mock line + moving trains ----

  void _drawMock(ARKitController c) {
    // Build a gently curving centreline in local metres, centred on the device.
    // Runs north–south (varying north), with a slight east–west S-curve.
    final path = <vm.Vector3>[];
    for (double d = -_testLineLength / 2; d <= _testLineLength / 2; d += _testMarker) {
      final east = 26 * math.sin(d / 70); // S-curve, ±26 m
      final north = d;
      path.add(vm.Vector3(east, -_testDepth, -north)); // north = -Z
    }
    _mockPath = path;

    // Cumulative arc length, for mapping a train's distance to a point.
    final cum = <double>[0];
    for (var i = 1; i < path.length; i++) {
      cum.add(cum[i - 1] + (path[i] - path[i - 1]).length);
    }
    _mockCum = cum;

    final color = const Color(_mockLineColor);

    // Tunnel markers — small dim spheres along the line.
    for (final p in path) {
      _add(
        c,
        ARKitNode(
          geometry: ARKitSphere(
            radius: 0.35,
            materials: [ARKitMaterial(diffuse: ARKitMaterialProperty.color(color))],
          ),
          position: p,
        ),
      );
    }

    // Two trains — one each direction, offset so they pass each other.
    final total = cum.last;
    _spawnTrain(c, color, distance: total * 0.15, speed: 7);
    _spawnTrain(c, color, distance: total * 0.65, speed: -7);

    setState(() {
      _placed = path.length;
      _status = '';
    });

    // ~20 Hz animation. Setting node.position moves it live (transformNotifier).
    _anim = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick(0.05));
  }

  void _spawnTrain(ARKitController c, Color color, {required double distance, required double speed}) {
    final node = ARKitNode(
      // A box reads as a train car more than a sphere. Bright, larger than markers.
      geometry: ARKitBox(
        width: 1.8,
        height: 1.8,
        length: 3.2,
        materials: [
          ARKitMaterial(
            diffuse: ARKitMaterialProperty.color(Colors.white),
            emission: ARKitMaterialProperty.color(color), // glow in the dark tunnel
          ),
        ],
      ),
      position: _pointAt(distance),
    );
    _add(c, node);
    _trains.add(_MockTrain(node, distance, speed));
  }

  void _tick(double dt) {
    if (_mockPath.length < 2) return;
    final total = _mockCum.last;
    for (final t in _trains) {
      t.distance = (t.distance + t.speed * dt) % total;
      if (t.distance < 0) t.distance += total;
      t.node.position = _pointAt(t.distance); // fires transformNotifier -> native move
    }
  }

  /// Point at arc-length [d] along the mock polyline (linear between vertices).
  vm.Vector3 _pointAt(double d) {
    final cum = _mockCum;
    if (_mockPath.isEmpty) return vm.Vector3.zero();
    d = d.clamp(0, cum.last);
    // find segment
    var lo = 0, hi = cum.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (cum[mid] <= d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final seg = cum[hi] - cum[lo];
    final f = seg == 0 ? 0.0 : (d - cum[lo]) / seg;
    return _mockPath[lo] + (_mockPath[hi] - _mockPath[lo]) * f;
  }

  void _toggleMode() {
    setState(() => _testMode = !_testMode);
    _rebuild();
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ARKitSceneView(
            worldAlignment: ARWorldAlignment.gravityAndHeading,
            onARKitViewCreated: _onCreated,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _circleButton(Icons.arrow_back_rounded, () => Navigator.of(context).pop()),
                  const Spacer(),
                  _modeToggle(),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 120, child: LineStripe(height: 3, gap: 2)),
                      const SizedBox(height: 8),
                      Text(
                        _statusText(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    if (_placed > 0) {
      return _testMode
          ? tr('Test line below you · point the phone down · $_placed markers',
              'Linha de teste abaixo de si · aponte para baixo · $_placed marcadores')
          : tr('Point down to see the tunnels below · $_placed markers',
              'Aponte para baixo para ver os túneis · $_placed marcadores');
    }
    return _status;
  }

  Widget _modeToggle() => GestureDetector(
        onTap: _toggleMode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_testMode ? Icons.science_rounded : Icons.public_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                _testMode ? tr('Test line', 'Linha teste') : tr('Real tunnels', 'Túneis reais'),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

  Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white),
        ),
      );
}
