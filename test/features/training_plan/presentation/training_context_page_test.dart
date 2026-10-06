import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_context_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_context_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);
  for (final width in [320.0, 360.0, 1000.0]) {
    testWidgets('disponibilidad y material se pueden editar a $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp(
            theme: EntrenaTheme.dark,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 950),
                textScaler: TextScaler.linear(width == 320 ? 2 : 1),
              ),
              child: TrainingContextPage(repository: _ContextRepository()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (width == 360) {
        await capturePerformanceWidget(tester, 'contexto_compartido_dias');
      }
      final picker = find.text('Añadir o cambiar material');
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      final bar = find.widgetWithText(FilterChip, 'barra de dominadas');
      await tester.ensureVisible(bar);
      await tester.tap(bar);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Guardar disponibilidad y material'),
      );
      await tester.pumpAndSettle();
      if (width == 360) {
        await capturePerformanceWidget(tester, 'contexto_compartido_material');
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'edita material exacto y disponibilidad y vuelve a leer lo guardado',
    (tester) async {
      final repository = _ContextRepository();
      await tester.pumpWidget(
        MaterialApp(home: TrainingContextPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final cones = find.widgetWithText(InputChip, 'conos');
      await tester.ensureVisible(cones);
      await tester.tap(
        find.descendant(
          of: cones,
          matching: find.byTooltip('Retirar material'),
        ),
      );
      await tester.pumpAndSettle();
      expect(cones, findsNothing);
      await tester.tap(find.text('Añadir o cambiar material'));
      await tester.pumpAndSettle();
      final bar = find.widgetWithText(FilterChip, 'barra de dominadas');
      await tester.ensureVisible(bar);
      await tester.tap(bar);
      await tester.pumpAndSettle();
      final save = find.text('Guardar disponibilidad y material');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.saved!.equipment, {'pull_up_bar'});
      expect(repository.saved!.availability, {'1': 45, '4': 60});
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: TrainingContextPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'conos'), findsNothing);
      expect(
        find.widgetWithText(InputChip, 'barra de dominadas'),
        findsOneWidget,
      );
    },
  );
  testWidgets('preferencias generales no inventan material ni días concretos', (
    tester,
  ) async {
    final repository = _ContextRepository(empty: true);
    await tester.pumpWidget(
      MaterialApp(home: TrainingContextPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Antes indicabas 5 días de 45 min'),
      findsOneWidget,
    );
    expect(find.byType(InputChip), findsNothing);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((tile) => tile.value == false),
      isTrue,
    );
    final monday = find.widgetWithText(CheckboxListTile, 'Lunes');
    await tester.tap(monday);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(DropdownMenuItem<int>, '45'), findsWidgets);
  });
}

class _ContextRepository implements TrainingContextRepository {
  _ContextRepository({this.empty = false});
  final bool empty;
  TrainingContext? saved;
  @override
  Future<TrainingContextSettings> load() async => TrainingContextSettings(
    context:
        saved ??
        (empty
            ? null
            : TrainingContext(
                availability: {'1': 45, '4': 60},
                equipment: {'cones'},
                reportsPain: false,
                capacityConfirmed: true,
              )),
    equipmentOptions: {'cones', 'pull_up_bar'},
    previousDaysPerWeek: 5,
    previousSessionMinutes: 45,
  );
  @override
  Future<void> save(TrainingContext context) async {
    saved = context;
  }
}
