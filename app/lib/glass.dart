/// Cozy panel material: warm white, opaque, soft shadow, rounded — wrapped in a
/// continuous four-line gradient border (Azul→Amarela→Verde→Vermelha, sweeping
/// around the perimeter and meeting seamlessly). The app's signature frame.
import 'dart:ui';
import 'package:flutter/material.dart';

import 'models.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final bool gradientBorder;
  final double borderWidth;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blur = 12,
    this.gradientBorder = true,
    this.borderWidth = 2.5,
  });

  Radius _shrink(Radius r) {
    final v = r.x - borderWidth;
    return Radius.circular(v < 0 ? 0.0 : v);
  }

  BorderRadius get _innerRadius => BorderRadius.only(
        topLeft: _shrink(borderRadius.topLeft),
        topRight: _shrink(borderRadius.topRight),
        bottomLeft: _shrink(borderRadius.bottomLeft),
        bottomRight: _shrink(borderRadius.bottomRight),
      );

  @override
  Widget build(BuildContext context) {
    // Sweep the four line colors around the border; repeat the first at the
    // end so the seam (at 3 o'clock) is a seamless Azul→Azul.
    final gradient = SweepGradient(
      colors: [
        for (final line in lineOrder) Color(lineColors[line]!),
        Color(lineColors[lineOrder.first]!),
      ],
    );

    final shadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.12),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];

    final inner = ClipRRect(
      borderRadius: gradientBorder ? _innerRadius : borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          color: Colors.white.withOpacity(0.96),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );

    if (!gradientBorder) {
      return DecoratedBox(
        decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
        child: inner,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: gradient,
        boxShadow: shadow,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: inner,
    );
  }
}
