// Capturas de widgets de producción con datos ficticios, sin cuentas ni red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_tools_section.dart';
import 'package:entrenaop/features/trainers/presentation/my_trainer_page.dart';
import 'package:entrenaop/features/welcome/presentation/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../test/helpers/performance_visual_review.dart';

void main() {
  for (final (name, size, scale) in [
    ('bienvenida-movil', const Size(390, 900), 1.0),
    ('bienvenida-escritorio', const Size(1100, 900), 1.0),
    ('bienvenida-accesible', const Size(320, 900), 2.0),
    ('herramientas-movil', const Size(390, 900), 1.0),
    ('invitacion-movil', const Size(390, 900), 1.0),
  ]) {
    testWidgets('captura $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => loadReviewFont(always: true));
      final boundary = GlobalKey();
      Widget page = WelcomePage(
        onChoose: (_) async {},
        onContinueForNow: (_) {},
      );
      if (name.startsWith('herramientas')) page = const HomeToolsPage();
      if (name.startsWith('invitacion')) {
        page = MyTrainerPage(
          repository: FakeTrainerRepository(),
          initialInvitation: 'a' * 64,
        );
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(
            'assets/branding/entrenaop_wordmark_on_dark.png',
            package: 'entrena_ui',
          ),
          tester.element(find.byType(Scaffold).first),
        ),
      );
      await tester.pumpAndSettle();
      if (name.startsWith('invitacion')) {
        await tester.scrollUntilVisible(
          find.text('Aceptar y vincularme'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/visual-audit/welcome-2026-10-26/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
