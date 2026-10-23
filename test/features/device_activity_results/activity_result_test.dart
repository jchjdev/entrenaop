import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/device_activity_results/domain/activity_result.dart';
import 'package:entrenaop/features/device_activity_results/presentation/activity_result_cubit.dart';

const lap0 = RecordedLap(0, 87.3, 400, 'active');
const lap1 = RecordedLap(1, 50, 10, 'rest');
const row = LapAssignment(
  block: 0,
  item: 0,
  set: 0,
  label: 'Serie',
  requiresRecovery: true,
  laps: [0],
  recoveryLaps: [1],
);
ActivityResultReview review() => ActivityResultReview(
  activityId: 'activity',
  activityRevision: 'a',
  scheduledId: 'scheduled',
  sourceRevision: 'b',
  name: 'Sintética',
  startedAt: DateTime.utc(2026, 10, 20),
  seconds: 137.3,
  meters: 410,
  offsetMinutes: 120,
  averageHeartRate: null,
  laps: const [lap0, lap1],
  rows: const [row],
);

class FakeRepository implements ActivityResultRepository {
  final calls = <ConfirmActivityResult>[];
  bool fail = true;
  Completer<ActivityResultCatalog>? deferred;
  @override
  Future<ActivityResultCatalog> load() =>
      deferred?.future ?? Future.value(const ActivityResultCatalog([], [], []));
  @override
  Future<ActivityResultReview> preview(
    String activityId,
    String scheduledId,
  ) async => review();
  @override
  Future<String> confirm(ConfirmActivityResult request) async {
    calls.add(request);
    if (fail) throw const ActivityResultException('activity_unavailable');
    return 'execution';
  }
}

void main() {
  test(
    'exige una vuelta distinta para la recuperación y no inventa la ausente',
    () {
      expect(validLapAssignments([row], [lap0, lap1]), isTrue);
      expect(
        validLapAssignments(
          [
            row.select(laps: [0], recoveryLaps: [0]),
          ],
          [lap0, lap1],
        ),
        isFalse,
      );
      expect(
        validLapAssignments(
          [
            row.select(laps: [0], recoveryLaps: []),
          ],
          [lap0, lap1],
        ),
        isFalse,
      );
      expect(validLapAssignments([row, row], [lap0, lap1]), isFalse);
      expect(
        validLapAssignments(
          [
            row.select(laps: [0, 2], recoveryLaps: [3]),
          ],
          [
            lap0,
            lap1,
            const RecordedLap(2, 10, 30, 'active'),
            const RecordedLap(3, 10, 0, 'rest'),
          ],
        ),
        isFalse,
      );
      expect(validLapAssignments([row.select(skipped: true)], []), isTrue);
    },
  );
  test(
    'no completa al recibir y necesita revisión y esfuerzo expresos',
    () async {
      final repository = FakeRepository();
      final cubit = ActivityResultCubit(repository, () => 'operation');
      addTearDown(cubit.close);
      await cubit.preview('activity', 'scheduled');
      expect(cubit.state.canConfirm, isFalse);
      await cubit.confirm();
      expect(repository.calls, isEmpty);
      cubit.edit(rpe: 4);
      expect(cubit.state.canConfirm, isFalse);
      cubit.edit(reviewed: true);
      expect(cubit.state.canConfirm, isTrue);
      cubit.edit(rows: [row]);
      expect(cubit.state.reviewed, isFalse);
    },
  );
  test('respuesta perdida conserva operación, RPE y correspondencias en el reintento', () async {
    final repository = FakeRepository();
    var ids = 0;
    final cubit = ActivityResultCubit(repository, () => 'operation-${++ids}');
    addTearDown(cubit.close);
    await cubit.preview('activity', 'scheduled');
    cubit.edit(rpe: 4, reviewed: true);
    await cubit.confirm();
    expect(cubit.state.retryingConfirmation, isTrue);
    cubit.edit(rpe: 10);
    expect(cubit.state.rpe, 4);
    repository.fail = false;
    await cubit.confirm();
    expect(repository.calls.length, 2);
    expect(identical(repository.calls[0], repository.calls[1]), isTrue);
    expect(ids, 1);
    expect(cubit.state.executionId, 'execution');
  });
  test('una carga vieja no sobreescribe una revisión posterior', () async {
    final deferred = Completer<ActivityResultCatalog>();
    final repository = FakeRepository()..deferred = deferred;
    final cubit = ActivityResultCubit(repository, () => 'operation');
    addTearDown(cubit.close);
    final loading = cubit.load();
    // Al actualizar se invalida la generación anterior.
    repository.deferred = null;
    await cubit.load();
    expect(cubit.state.catalog, isNotNull);
    final latest = cubit.state.catalog;
    deferred.complete(const ActivityResultCatalog([], [], ['stale']));
    await loading;
    expect(identical(cubit.state.catalog, latest), isTrue);
  });
}
