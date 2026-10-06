import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'Mi plan conserva jerarquía y no desborda a ${width.toInt()} px',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          MaterialApp(theme: EntrenaTheme.dark, home: const TrainingHubPage()),
        );
        await tester.pumpAndSettle();
        final cards = tester.widgetList<EntrenaCard>(find.byType(EntrenaCard));
        expect(
          cards.where((card) => card.tone == EntrenaCardTone.accent),
          hasLength(1),
        );
        await tester.scrollUntilVisible(
          find.text('Preferencias de entrenamiento'),
          300,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
