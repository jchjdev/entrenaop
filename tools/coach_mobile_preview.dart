// Vista local de las pantallas reales. Ejecutar únicamente como target de
// desarrollo; las identidades y datos proceden de fixtures sin transporte.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';

import '../test/support/coach_mobile_fixture.dart';
import '../test/support/coach_workspace_fixture.dart';

void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  runApp(const MaterialApp(home: _Preview()));
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final router = createRouter(
    CoachMobileFixture(),
    FakeSecurity(),
    initial: '/coach',
  );
  double scale = 1;
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff20252b),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            const Text(
              'EntrenaOP · revisión móvil · datos simulados',
              style: TextStyle(color: Colors.white),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tamaño de texto',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 12),
                DropdownButton<double>(
                  value: scale,
                  dropdownColor: const Color(0xff20252b),
                  items: [
                    for (final value in [1.0, 1.3, 2.0])
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          '$value×',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => scale = value!),
                ),
              ],
            ),
            SizedBox(
              width: 390,
              height: 844,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: MaterialApp.router(
                  theme: EntrenaTheme.dark,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: const Size(390, 844),
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(top: 47, bottom: 34),
                      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                    ),
                    child: child!,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
