/// The app's surface material: warm white, opaque, rounded, with a soft glow.
/// Used for every floating surface — panels, nav bar, HUD, search and buttons.
import 'dart:ui';
import 'package:flutter/material.dart';

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;

  /// Halo around the panel. Defaults to white; pass a line colour to tint it
  /// (e.g. the followed train's line).
  final Color glowColor;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blur = 12,
    this.glowColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // NOTE: the glow/shadow must live OUTSIDE the ClipRRect — a shadow drawn by
    // the clipped child renders beyond its box and gets cut away entirely.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          // the glow
          BoxShadow(
            color: glowColor.withOpacity(0.55),
            blurRadius: 22,
            spreadRadius: 1,
          ),
          // grounding shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          // subtle blur behind the near-opaque panel keeps map edges soft
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: Colors.white.withOpacity(0.96),
              border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
            ),
            // Transparent Material so ListTile/ExpansionTile ink and tile colors
            // inside panels render correctly (they require a Material ancestor).
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}
