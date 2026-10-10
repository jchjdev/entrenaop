import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';

/// La marca conserva su recurso oficial; Pro es un distintivo tipográfico,
/// no una nueva versión del logotipo ni una fuente deducida de su imagen.
class ProBrandTitle extends StatelessWidget {
  const ProBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'EntrenaOP Pro',
      header: true,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EntrenaWordmark(width: 176, forDarkSurface: dark),
              const SizedBox(width: 12),
              Text(
                'Pro',
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFD1D6DE)
                      : const Color(0xFF505A67),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
