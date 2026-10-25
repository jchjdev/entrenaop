import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/device_activity_results/domain/activity_result.dart';
import 'package:entrenaop/features/device_activity_results/presentation/activity_result_page.dart';
import 'package:entrenaop/features/workouts/data/models/workout_execution_model.dart';

import 'activity_result_test.dart' show review;

class PageRepository implements ActivityResultRepository {
  int confirmations = 0;
  List<String> problems = const [];
  @override
  Future<ActivityResultCatalog> load() async => ActivityResultCatalog(
    [
      ReceivedRun(
        'activity',
        'revision',
        'Carrera sintética',
        DateTime.utc(2026, 10, 20),
        137.3,
        410,
        null,
      ),
    ],
    const [RunAppointment('scheduled', 'Series de prueba', '2026-10-20')],
    problems,
  );
  @override
  Future<ActivityResultReview> preview(
    String activityId,
    String scheduledId,
  ) async => review();
  @override
  Future<String> confirm(ConfirmActivityResult request) async {
    confirmations++;
    return 'execution';
  }
}

void main() {
  testWidgets(
    'otro deporte no se presenta como fallo técnico ni completa una cita',
    (tester) async {
      final repository = PageRepository()..problems = ['unsupported_activity'];
      await tester.pumpWidget(
        MaterialApp(home: ActivityResultPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('de un tipo que esta integración'),
        findsOneWidget,
      );
      expect(
        find.textContaining('pendiente de revisión técnica'),
        findsNothing,
      );
      expect(repository.confirmations, 0);
    },
  );

  test('el codec conserva el tiempo nativo de cada serie y copyWith no lo redondea', () {
    final e = WorkoutExecutionModel.fromJson({
      'id': 'execution',
      'template_id': 'template',
      'template_name': 'Fixture',
      'template_version': 1,
      'status': 'completed',
      'started_at': '2026-10-20T08:00:00Z',
      'result_source': 'device',
      'workout_execution_sets': [
        {
          'id': 'set',
          'block_order': 0,
          'block_name': 'Series',
          'item_order': 0,
          'exercise_id': 'exercise',
          'exercise_name': 'Carrera',
          'set_order': 0,
          'rest_after_seconds': 0,
          'status': 'completed',
          'result_source': 'device',
          'actual_duration_seconds': 88,
          'observed_duration_seconds': 87.625,
          'observed_recovery_duration_seconds': 30.25,
        },
      ],
    });
    expect(e.sets.single.measuredDurationSeconds, 87.625);
    expect(e.sets.single.copyWith().observedRecoveryDurationSeconds, 30.25);
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets('revisión a $width px, texto grande y sin completar al abrir', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = PageRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: ActivityResultPage(repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-10-20 · Series de prueba').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar datos y sesión'));
      await tester.pumpAndSettle();
      expect(find.text('1. Serie'), findsOneWidget);
      expect(repository.confirmations, 0);
      expect(tester.takeException(), isNull);
    });
  }
  test('el resultado usa el temporizador medido, conserva decimales y sobrevive a copyWith', () {
    final execution = WorkoutExecutionModel.fromJson({
      'id': 'execution',
      'template_id': 'template',
      'template_name': 'Fixture',
      'template_version': 1,
      'status': 'completed',
      'started_at': '2026-10-20T08:00:00Z',
      'completed_at': '2026-10-21T12:00:00Z',
      'result_source': 'device',
      'observed_timer_seconds': 137.3,
      'observed_elapsed_seconds': 150.2,
      'observed_distance_meters': 410.25,
      'workout_execution_sets': [],
    });
    expect(execution.measuredDuration?.inMilliseconds, 137300);
    expect(execution.copyWith(notes: 'Fixture').observedDistanceMeters, 410.25);
  });
}
