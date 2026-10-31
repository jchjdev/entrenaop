import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/device_activity_results/domain/activity_result.dart';
import 'package:entrenaop/features/device_activity_results/presentation/activity_result_cubit.dart';
import 'package:entrenaop/features/device_activity_results/presentation/activity_result_page.dart';

const work = LapAssignment(
  block: 0,
  item: 0,
  set: 0,
  label: 'Carrera',
  requiresRecovery: true,
  requiresDistance: true,
  laps: [0],
  recoveryLaps: [1],
);
ActivityResultReview result({bool test = false, String? blocked}) =>
    ActivityResultReview(
      activityId: 'activity',
      activityRevision: 'a',
      scheduledId: 'scheduled',
      sourceRevision: 'b',
      name: 'Carrera sintética',
      startedAt: DateTime.utc(2026, 10, 31),
      seconds: 117.3,
      meters: 420,
      offsetMinutes: 60,
      averageHeartRate: null,
      laps: const [
        RecordedLap(0, 87.3, 400, 'unknown'),
        RecordedLap(1, 30, 20, 'unknown'),
      ],
      rows: const [work],
      recordedRpe: 4,
      isTest: test,
      blockedReason: blocked,
      requiresMeasuredStep: true,
    );

class Repository implements ActivityResultRepository {
  bool test = false;
  int confirmations = 0;
  @override
  Future<ActivityResultCatalog> load() async => ActivityResultCatalog(
    [
      ReceivedRun(
        'activity',
        'a',
        'Carrera sintética',
        DateTime.utc(2026, 10, 31),
        117.3,
        420,
        null,
        scheduledId: 'scheduled',
      ),
    ],
    const [RunAppointment('scheduled', 'Series', '2026-10-31')],
    [],
  );
  @override
  Future<ActivityResultReview> preview(
    String activityId,
    String scheduledId,
  ) async => result(test: test);
  @override
  Future<String> confirm(ConfirmActivityResult value) async {
    confirmations++;
    return 'execution';
  }
}

void main() {
  test('La ausencia de distancia no se convierte en cero ni acredita un paso que la exige', () {
    const laps = [
      RecordedLap(0, 87.3, null, 'unknown'),
      RecordedLap(1, 30, null, 'unknown'),
    ];
    expect(validLapAssignments([work], laps), isFalse);
    const timed = LapAssignment(
      block: 0,
      item: 0,
      set: 0,
      label: 'Tiempo',
      requiresRecovery: false,
      laps: [0],
    );
    expect(validLapAssignments([timed], laps), isTrue);
  });
  test('Una prueba, un conflicto y todos los pasos omitidos impiden cerrar la semana', () {
    ActivityResultState state(
      ActivityResultReview review,
      List<LapAssignment> rows,
    ) => ActivityResultState(
      review: review,
      rows: rows,
      reviewed: true,
      rpe: 4,
      offsetMinutes: 60,
    );
    expect(state(result(), [work]).canConfirm, isTrue);
    expect(state(result(test: true), [work]).canConfirm, isFalse);
    expect(
      state(result(blocked: 'activity_conflict'), [work]).canConfirm,
      isFalse,
    );
    expect(state(result(), [work.select(skipped: true)]).canConfirm, isFalse);
  });
  test(
    'El esfuerzo registrado se propone sin confirmar la sesión por recibirla',
    () async {
      final repository = Repository();
      final cubit = ActivityResultCubit(repository, () => 'operation');
      addTearDown(cubit.close);
      await cubit.preview('activity', 'scheduled');
      expect(cubit.state.rpe, 4);
      expect(cubit.state.reviewed, isFalse);
      await cubit.confirm();
      expect(repository.confirmations, 0);
      cubit.edit(reviewed: true);
      await cubit.confirm();
      expect(cubit.state.executionId, 'execution');
      expect(repository.confirmations, 1);
    },
  );
  testWidgets(
    'Apple abre la pauta conocida y permite revisar los intervalos en tarjetas plegables',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityResultPage(
            repository: Repository(),
            provider: 'Apple Watch',
            initialActivityId: 'activity',
            initialScheduledId: 'scheduled',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('Tu esfuerzo global (1–10)'), findsOneWidget);
      expect(find.text('Paso no realizado'), findsNothing);
      await tester.tap(find.text('Asignar intervalos en orden y revisar'));
      await tester.pumpAndSettle();
      expect(find.text('Intervalos asignados'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Completar sesión con estos datos'),
      );
      expect(button.onPressed, isNull);
    },
  );
}
