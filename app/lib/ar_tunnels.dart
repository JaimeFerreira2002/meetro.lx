/// AR view (Phase 2, v0): visualize the metro tunnels below you through the camera.
///
/// iOS only, and ONLY runs on a PHYSICAL device — ARKit is unavailable in the
/// simulator. Alignment uses the device GPS + compass (ARKit
/// `gravityAndHeading`), so it's accurate to a few metres and can be off by the
/// compass error. The accurate upgrade is Google's ARCore Geospatial VPS (later).
///
/// The track geometry (baked OSM polylines) is fetched from the backend and each
/// point is converted to local metres relative to your position, then placed
/// ~18 m underground and coloured by line.
import 'dart:math' as math;

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'line_stripe.dart';
import 'metro_api.dart';
import 'models.dart';

class ArTunnelsScreen extends StatefulWidget {
  final MetroApi api;
  const ArTunnelsScreen({super.key, required this.api});

  @override
  State<ArTunnelsScreen> createState() => _ArTunnelsScreenState();
}

class _ArTunnelsScreenState extends State<ArTunnelsScreen> {
  static const double _tunnelDepth = 18; // metres below the device
  static const double _maxRange = 1500; // metres — cull distant points
  static const int _step = 3; // downsample polylines to keep node count sane

  ARKitController? _controller;
  String _status = 'Starting AR…';
  int _placed = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _circleButton(Icons.arrow_back_rounded, () => Navigator.of(context).pop()),
                      const Spacer(),
                    ],
                  ),
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
                        _placed > 0
                            ? 'Point down to see the tunnels below · $_placed markers'
                            : _status,
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

  Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white),
        ),
      );

  Future<void> _onCreated(ARKitController controller) async {
    _controller = controller;
    try {
      setState(() => _status = 'Getting your location…');
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition();

      setState(() => _status = 'Loading tunnels…');
      final tracks = await widget.api.track();
      _drawTunnels(controller, pos.latitude, pos.longitude, tracks);
    } catch (e) {
      setState(() => _status = 'AR failed: $e');
    }
  }

  void _drawTunnels(ARKitController c, double lat0, double lon0, List<TrackLine> tracks) {
    final mPerLat = 111320.0;
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
        final node = ARKitNode(
          geometry: ARKitSphere(
            radius: 0.6,
            materials: [ARKitMaterial(diffuse: ARKitMaterialProperty.color(color))],
          ),
          position: vm.Vector3(east, -_tunnelDepth, -north),
        );
        c.add(node);
        placed++;
      }
    }
    setState(() {
      _placed = placed;
      _status = placed == 0 ? 'No tunnels within range' : '';
    });
  }
}
