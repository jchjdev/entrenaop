import 'dart:async';
import 'dart:ui' as ui;

import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/evolution_fixtures.dart';

void main() {
  Future<void> mount(
    WidgetTester t,
    Future<PreparationMarksData> Function(String) load, {
    String id = 'generic',
  }) async {
    await t.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: PreparationMarksPage(goalId: id, load: load),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'separa controles y mantiene la cabecera legible al desplazar en $width px con texto x$scale',
      (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        const frameKey = ValueKey('marks-frame');
        final data = PreparationMarksData(
          goal: evolutionGeneric,
          running: [
            RunningTestResult(
              id: 'first',
              completedAt: DateTime(2026, 10, 10),
              durationSeconds: 400,
              rpe: 6,
              averageHrBpm: 155,
              maxHrBpm: 165,
            ),
            RunningTestResult(
              id: 'second',
              completedAt: DateTime(2026, 10, 10),
              durationSeconds: 510,
              rpe: 8,
            ),
          ],
        );
        await t.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: frameKey,
              child: PreparationMarksPage(
                goalId: 'generic',
                load: (_) async => data,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final toolbar = t.getRect(find.byType(AppBar));
        Future<Uint8List> headerPixels() async {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(frameKey),
          );
          return (await t.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final pixels = Uint8List.fromList(
              bytes!.buffer.asUint8List(
                (toolbar.top * width * 4).round(),
                (toolbar.height * width * 4).round(),
              ),
            );
            image.dispose();
            return pixels;
          }))!;
        }

        final before = await headerPixels();
        await t.drag(find.byType(ListView), const Offset(0, -160));
        await t.pumpAndSettle();
        final scrollable = t.state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.pixels, greaterThan(0));
        expect(
          listEquals(before, await headerPixels()),
          isTrue,
          reason: 'El contenido desplazado no debe verse bajo la cabecera.',
        );
        final first = find.ancestor(
          of: find.text('6:40 · RPE 6'),
          matching: find.byType(EntrenaCard),
        );
        final second = find.ancestor(
          of: find.text('8:30 · RPE 8'),
          matching: find.byType(EntrenaCard),
        );
        expect(
          t.getRect(second).top - t.getRect(first).bottom,
          greaterThanOrEqualTo(12),
        );
        await t.ensureVisible(find.text('8:30 · RPE 8'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('consulta snapshots e intentos nulos sin recalcular puntos', (
    t,
  ) async {
    await mount(t, (_) async => evolutionGenericData());
    expect(find.text('Baremo snapshot-v3 · M'), findsOneWidget);
    await t.tap(find.text('22/09/2026 · Apto'));
    await t.pumpAndSettle();
    expect(find.text('47,5 puntos totales'), findsOneWidget);
    expect(find.text('Marca 2,15'), findsOneWidget);
    expect(find.text('Intentos: Nulo · 2,15'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Tropa muestra el baremo guardado y todos los datos del control',
    (t) async {
      await mount(t, (_) async => evolutionTroopData(), id: 'troop');
      expect(find.byTooltip('Versión: baremo-guardado-v1'), findsOneWidget);
      expect(find.text('Baremo de ingreso'), findsOneWidget);
      expect(find.text('9:00 · RPE 7'), findsOneWidget);
      expect(find.text('FC media: 152 lpm'), findsOneWidget);
      expect(find.text('FC máxima: 172 lpm'), findsOneWidget);
      expect(
        find.text('Parciales (s): 108 · 108 · 108 · 108 · 108'),
        findsOneWidget,
      );
    },
  );

  testWidgets('FAS conserva su versión y rechaza puntuar otra desconocida', (
    t,
  ) async {
    final data = (await t.runAsync(
      () => evolutionFasData(version: 'baremo-desconocido'),
    ))!;
    await mount(t, (_) async => data, id: 'fas');
    expect(find.byTooltip('Versión: baremo-desconocido'), findsOneWidget);
    expect(find.text('Baremo guardado · Otra versión'), findsOneWidget);
    expect(find.textContaining('Este test usa otra versión'), findsOneWidget);
    expect(find.textContaining('puntos totales'), findsNothing);
    await t.tap(find.text('05/10/2026'));
    await t.pumpAndSettle();
    expect(find.text('30 repeticiones'), findsOneWidget);
  });

  testWidgets('fallar al actualizar conserva resultados y permite reintentar', (
    t,
  ) async {
    var calls = 0;
    await mount(t, (_) async {
      if (++calls == 2) throw StateError('offline');
      return evolutionGenericData();
    });
    final refresh = t
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await t.pumpAndSettle();
    await refresh;
    expect(find.text('Baremo snapshot-v3 · M'), findsOneWidget);
    expect(
      find.textContaining('Sigues viendo la última consulta'),
      findsOneWidget,
    );
    await t.tap(find.text('Reintentar actualizar'));
    await t.pumpAndSettle();
    expect(calls, 3);
    expect(
      find.textContaining('Sigues viendo la última consulta'),
      findsNothing,
    );
  });

  testWidgets('al cambiar de preparación no aparece una respuesta anterior', (
    t,
  ) async {
    final pending = Completer<PreparationMarksData>();
    Future<PreparationMarksData> load(String id) async =>
        id == 'troop' ? pending.future : evolutionGenericData();
    await t.pumpWidget(
      MaterialApp(
        home: PreparationMarksPage(goalId: 'troop', load: load),
      ),
    );
    await t.pump();
    await mount(t, load);
    pending.complete(evolutionTroopData());
    await t.pumpAndSettle();
    expect(find.text(evolutionGeneric.program.name), findsOneWidget);
    expect(find.text(evolutionTroop.program.name), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final data in [evolutionTroopData(), evolutionGenericData()]) {
    testWidgets(
      'registrar usa go_router y consulta de nuevo al volver: ${data.goal.id}',
      (t) async {
        var calls = 0;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => PreparationMarksPage(
                goalId: data.goal.id!,
                load: (_) async {
                  calls++;
                  return data;
                },
              ),
            ),
            GoRoute(
              path: '/plan/goal/:id/:form',
              builder: (_, state) => Scaffold(
                body: Text(
                  'Formulario ${state.pathParameters['id']} ${state.pathParameters['form']}',
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await t.pumpWidget(
          MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Registrar nuevas marcas'));
        await t.pumpAndSettle();
        final form = data.goal.id == 'troop'
            ? 'troop-assessment'
            : 'program-assessment';
        expect(find.text('Formulario ${data.goal.id} $form'), findsOneWidget);
        expect(calls, 1);
        router.pop();
        await t.pumpAndSettle();
        expect(calls, 2);
        expect(find.text('Marcas y resultados'), findsOneWidget);
      },
    );
  }

  for (final width in [320.0, 1100.0]) {
    testWidgets('marcas legibles con texto grande en $width px', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: PreparationMarksPage(
            goalId: 'generic',
            load: (_) async => evolutionGenericData(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('22/09/2026 · Apto'));
      await t.pumpAndSettle();
      await t.tap(find.text('22/09/2026 · Apto'));
      await t.pumpAndSettle();
      expect(find.text('47,5 puntos totales'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
