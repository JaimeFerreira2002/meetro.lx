/// Opening animation: the meetro logo fades in, holds, and fades out.
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;

  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    // fade in -> hold -> fade out
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 42),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 28,
      ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Image.asset(
            'assets/logos/metro_full.png',
            // the artwork carries a lot of its own padding, so go wide
            width: MediaQuery.of(context).size.width * 0.78,
            errorBuilder: (_, __, ___) => const Text(
              'meetro',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
