/// Official Metro de Lisboa line pictograms (the seagull, sunflower, caravel
/// and compass rose), shipped as SVG in assets/icons/.
///
/// They're detailed marks with different aspect ratios, so they only read at
/// ~16px+. Anywhere tighter than that (dense arrival rows) keeps the plain
/// colour dot — [LineDot].
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'models.dart';

const _lineAssets = <String, String>{
  'Azul': 'assets/icons/linha_azul.svg',
  'Amarela': 'assets/icons/linha_amarela.svg',
  'Verde': 'assets/icons/linha_verde.svg',
  'Vermelha': 'assets/icons/linha_vermelha.svg',
};

/// The line's official pictogram. Falls back to a colour dot if the asset is
/// missing or the line is unknown.
class LineLogo extends StatelessWidget {
  final String line;
  final double height;

  const LineLogo(this.line, {super.key, this.height = 20});

  @override
  Widget build(BuildContext context) {
    final asset = _lineAssets[line];
    if (asset == null) return LineDot(line, size: height);
    return SvgPicture.asset(
      asset,
      height: height,
      placeholderBuilder: (_) => LineDot(line, size: height),
    );
  }
}

/// Plain line-coloured dot — used where a pictogram would be too small to read.
class LineDot extends StatelessWidget {
  final String line;
  final double size;

  const LineDot(this.line, {super.key, this.size = 10});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(lineColors[line] ?? 0xFF9E9E9E),
          shape: BoxShape.circle,
        ),
      );
}
