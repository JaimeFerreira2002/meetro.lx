/// Splash: the metro (assets/icons/metro.png) glides in from the left,
/// stops at the platform while the title fades in, then departs to the right.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;

  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _x;      // train x, in screen-widths
  late final Animation<double> _title;  // title opacity

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));

    // arrive (decelerate) -> dwell -> depart (accelerate)
    _x = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.8, end: 0.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 32,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 38),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.8).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
    ]).animate(_c);

    // title visible while the train dwells, gone by departure
    _title = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 26),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 14),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_c);

    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // the train
            Transform.translate(
              offset: Offset(_x.value * width, 0),
              child: Image.asset(
                'assets/icons/metro.png',
                width: 140,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.directions_subway_rounded, size: 120, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            // the platform: a track with the four line colors
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Row(
                children: [
                  for (final line in lineOrder)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Color(lineColors[line]!),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Opacity(
              opacity: _title.value,
              child: Column(
                children: [
                  Text('Metro Lisboa',
                      style: GoogleFonts.poppins(
                          fontSize: 30, fontWeight: FontWeight.w700, color: Colors.black87)),
                  Text('live',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black38)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
