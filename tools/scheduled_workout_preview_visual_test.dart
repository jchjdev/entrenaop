// Capturas del entrenamiento pautado real con una versión ficticia y sin red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout_preview.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/scheduled_workout_preview_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/scheduled_workout_preview_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/scheduled_workout_preview_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/pages/scheduled_workout_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/features/workout_schedule/presentation/scheduled_workout_preview_test.dart'
    show scheduledWorkoutPreviewFixture;
import '../test/helpers/performance_visual_review.dart' show loadReviewFont;

void main() {
  var fontsLoaded = false;
  for (final (width, scale) in [
    (390.0, 1.0),
    (320.0, 1.0),
    (390.0, 2.0),
    (320.0, 2.0),
  ]) {
    testWidgets('entrenamiento pautado a $width px y texto $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (!fontsLoaded) {
        await tester.runAsync(() => loadReviewFont(always: true));
        fontsLoaded = true;
      }
      final repository = _ReadOnlyPreview();
      final cubit = ScheduledWorkoutPreviewCubit(
        scheduledId: 'scheduled',
        getPreview: GetScheduledWorkoutPreviewUseCase(repository),
        startReviewed: StartReviewedScheduledWorkoutUseCase(repository),
      );
      await cubit.load();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: BlocProvider.value(
              value: cubit,
              child: ScheduledWorkoutPreviewPage(
                routeBase: '/plan/week/session/scheduled',
                initialDate: DateTime(2026, 9, 23),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prefix = 'preview-${width.toInt()}-texto-${scale.toInt()}';
      final start = find.byKey(const ValueKey('scheduled-preview-start'));
      final startRect = tester.getRect(start);
      expect(startRect.bottom, lessThanOrEqualTo(900));
      expect(find.text('Versión 3'), findsOneWidget);
      await _capture(tester, '$prefix-inicio');

      final protocol = find.textContaining(
        'Controla la bajada y evita el rebote.',
      );
      await Scrollable.ensureVisible(tester.element(protocol), alignment: .5);
      await tester.pumpAndSettle();
      expect(find.textContaining('22 kg'), findsOneWidget);
      expect(find.textContaining('RPE 8'), findsOneWidget);
      expect(tester.getRect(start), startRect);
      expect(tester.getRect(protocol).bottom, lessThanOrEqualTo(startRect.top));
      await _capture(tester, '$prefix-series');

      await Scrollable.ensureVisible(
        tester.element(find.text('Carrera final')),
        alignment: .05,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('5:00–5:30/km'), findsOneWidget);
      expect(find.textContaining('recuperación andando'), findsOneWidget);
      expect(tester.getRect(start), startRect);
      await _capture(tester, '$prefix-carrera');
      expect(repository.starts, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('review-boundary')),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory(
      'docs/visual-audit/scheduled-workout-preview-2026-11-01',
    )..createSync(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

class _ReadOnlyPreview implements ScheduledWorkoutPreviewRepository {
  int starts = 0;

  @override
  Future<ScheduledWorkoutPreview> get(String scheduledId) async =>
      scheduledWorkoutPreviewFixture();

  @override
  Future<String> startReviewed(String scheduledId, String revision) async {
    starts++;
    throw StateError('Una captura visual no debe iniciar entrenamientos.');
  }
}
