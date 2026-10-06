import 'package:flutter/material.dart';

class EntrenaWordmark extends StatelessWidget {
  const EntrenaWordmark({
    super.key,
    this.width = 148,
    this.forDarkSurface = true,
  });

  final double width;
  final bool forDarkSurface;

  @override
  Widget build(BuildContext context) {
    final asset = forDarkSurface
        ? 'assets/branding/entrenaop_wordmark_on_dark.png'
        : 'assets/branding/entrenaop_wordmark_on_light.png';
    final height = width / 7.3;
    return Semantics(
      label: 'EntrenaOP',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(
            asset,
            package: 'entrena_ui',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
