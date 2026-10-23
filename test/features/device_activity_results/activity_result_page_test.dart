import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/device_activity_results/domain/activity_result.dart';
import 'package:entrenaop/features/device_activity_results/presentation/activity_result_page.dart';
import 'package:entrenaop/features/workouts/data/models/workout_execution_model.dart';

import 'activity_result_test.dart' show review;

class PageRepository implements ActivityResultRepository {
  int confirmations = 0;
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
    const [],
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
      await tester.tap(find.text('Revisar vueltas y sesión'));
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
