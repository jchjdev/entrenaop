import 'package:device_activity_core/device_activity_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const planner = PlanActivityImport();

ActivityImportPlan apply(ActivityImportState state, ActivityImportPage batch) =>
    planner(ownerId: 'athlete', current: state, page: batch);

void main() {
  test(
    'la misma revisión final resulta de cualquier orden de eventos fechados',
    () {
      final revisions = [
        running(revision: 'b', modifiedAt: modification),
        running(
          revision: 'a',
          modifiedAt: modification.add(const Duration(seconds: 1)),
        ),
        running(
          revision: 'opaque',
          modifiedAt: modification.add(const Duration(seconds: 2)),
        ),
      ];
      for (final order in [
        [0, 1, 2],
        [0, 2, 1],
        [1, 0, 2],
        [1, 2, 0],
        [2, 0, 1],
        [2, 1, 0],
      ]) {
        final result = apply(
          importState(),
          page(order.map((index) => revisions[index])),
        );
        expect(result.nextState.activities.single.revision.token, 'opaque');
        expect(result.nextState.records.length, 1);
      }
    },
  );

  test('recibos antiguos impiden reutilizar una orden tras otras páginas', () {
    final firstPage = page([running()]);
    final first = apply(importState(), firstPage).nextState;
    final second = apply(
      first,
      page(
        [],
        operation: 'page-2',
        expectedCursor: 'cursor-1',
        nextCursor: 'cursor-2',
      ),
    ).nextState;
    expect(apply(second, firstPage).nextState, same(second));
    expect(
      () => apply(
        second,
        page([], expectedCursor: 'cursor-2', nextCursor: 'cursor-3'),
      ),
      throwsA(hasProblem(ActivityProblem.reusedOperation)),
    );
    expect(second.receipts.length, 2);
    expect(() => second.receipts.clear(), throwsUnsupportedError);
  });

  test(
    'invalidar generación o revocar consulta también bloquea un reintento',
    () {
      final batch = page([running()]);
      final saved = apply(importState(), batch).nextState;
      final revoked = ActivityImportState(
        scope: saved.scope,
        generation: saved.generation,
        readAccess: ActivityReadAccess.revoked,
        cursor: saved.cursor,
        checkpoint: saved.checkpoint,
        records: saved.records,
        receipts: saved.receipts,
      );
      expect(
        () => apply(revoked, batch),
        throwsA(hasProblem(ActivityProblem.authorizationRequired)),
      );
      expect(
        () => apply(importState(generation: 'new-generation'), batch),
        throwsA(hasProblem(ActivityProblem.staleGeneration)),
      );
    },
  );

  test('snapshot y página copian sus colecciones de entrada', () {
    final data = running();
    final changes = <ActivityChange>[data];
    final batch = page(changes);
    changes.clear();
    expect(batch.changes.single, same(data));
    expect(() => batch.changes.clear(), throwsUnsupportedError);
    final records = <ActivityIdentity, ActivityChange>{data.identity: data};
    final state = ActivityImportState(
      scope: scope(),
      generation: 'generation-1',
      readAccess: ActivityReadAccess.queryAllowed,
      records: records,
    );
    records.clear();
    expect(state.activities.single, same(data));
  });

  test(
    'todos los canales usan el mismo dominio sin compartir el namespace',
    () {
      for (final channel in ActivityChannel.values) {
        final observation = running(key: identity(channel: channel));
        final feed = scope(channel: channel);
        final result = apply(
          importState(feed: feed),
          page([observation], feed: feed),
        );
        expect(result.nextState.activities.single.identity.channel, channel);
        expect(result.nextState.records.length, 1);
      }
    },
  );

  test(
    'una ventana reconciliada tras cursor caducado conserva las identidades',
    () {
      final original = running();
      final saved = apply(importState(), page([original])).nextState;
      // El adaptador abre una generación nueva al reconciliar y conserva registros.
      final reconciled = ActivityImportState(
        scope: saved.scope,
        generation: 'reconcile',
        readAccess: saved.readAccess,
        checkpoint: saved.checkpoint,
        records: saved.records,
      );
      final result = apply(
        reconciled,
        page([running()], generation: 'reconcile', operation: 'reconcile-page'),
      );
      expect(result.unchanged, 1);
      expect(result.nextState.records.length, 1);
    },
  );

  test(
    'importa una página con cuarentena identificable y un único checkpoint',
    () {
      final initial = importState();
      final valid = running();
      final incomplete = running(
        key: identity(id: 'incomplete'),
        missingEnd: true,
      );
      final plan = apply(initial, page([valid, incomplete]));
      expect(plan.inserted, 1);
      expect(plan.quarantined, 1);
      expect(plan.expectedCheckpoint, 0);
      expect(plan.nextState.checkpoint, 1);
      expect(plan.nextState.cursor, 'cursor-1');
      expect(plan.nextState.activities.single, same(valid));
      expect(plan.nextState.quarantine.single.identity, incomplete.identity);
      expect(
        plan.nextState.quarantine.single.issues,
        contains(ActivityIssue.missingEnd),
      );
      expect(initial.records, isEmpty);
      expect(initial.cursor, isNull);
      expect(() => plan.nextState.records.clear(), throwsUnsupportedError);
      expect(() => plan.nextState.quarantine.clear(), throwsUnsupportedError);
    },
  );

  test('respuesta incierta permite repetir la orden sin cambiar estado', () {
    final batch = page([running()]);
    final first = apply(importState(), batch);
    final replay = apply(first.nextState, batch);
    expect(replay.isReplay, isTrue);
    expect(replay.nextState, same(first.nextState));
    expect(replay.nextState.records.length, 1);
    expect(replay.nextState.checkpoint, 1);
    expect(
      () => apply(first.nextState, page([running()], nextCursor: 'different')),
      throwsA(hasProblem(ActivityProblem.reusedOperation)),
    );
  });

  test(
    'releer con otra recepción o ventana solapada no duplica una observación',
    () {
      final original = running();
      final batch = page([original]);
      final state = apply(importState(), batch).nextState;
      final seenLater = running(
        receivedAt: modification.add(const Duration(hours: 1)),
      );
      expect(apply(state, page([seenLater])).isReplay, isTrue);
      final overlapping = apply(
        state,
        page(
          [seenLater],
          operation: 'page-2',
          expectedCursor: 'cursor-1',
          nextCursor: 'cursor-2',
        ),
      );
      expect(overlapping.unchanged, 1);
      expect(overlapping.nextState.records.values.single, same(original));
    },
  );

  test('rechaza callback de cuenta, conexión, ámbito o generación ajenos', () {
    final state = importState();
    expect(
      () => apply(state, page([running()], feed: scope(owner: 'other'))),
      throwsA(hasProblem(ActivityProblem.wrongOwner)),
    );
    for (final feed in [
      scope(connection: 'other-connection'),
      scope(account: 'other-account'),
      scope(channel: ActivityChannel.appleHealth),
    ]) {
      expect(
        () => apply(state, page([], feed: feed)),
        throwsA(hasProblem(ActivityProblem.wrongScope)),
      );
    }
    expect(
      () => apply(state, page([], generation: 'old-generation')),
      throwsA(hasProblem(ActivityProblem.staleGeneration)),
    );
    expect(state.records, isEmpty);
  });

  test(
    'un registro ajeno rechaza toda la página antes de planificar escrituras',
    () {
      final state = importState();
      expect(
        () => apply(
          state,
          page([running(), running(key: identity(owner: 'other'))]),
        ),
        throwsA(hasProblem(ActivityProblem.wrongScope)),
      );
      expect(state.records, isEmpty);
      expect(state.checkpoint, 0);
    },
  );

  for (final access in ActivityReadAccess.values.where(
    (value) => value != ActivityReadAccess.queryAllowed,
  )) {
    test('no admite lectura sin autorización de consulta: ${access.name}', () {
      expect(
        () => apply(importState(access: access), page([])),
        throwsA(hasProblem(ActivityProblem.authorizationRequired)),
      );
    });
  }

  test('HealthKit vacío no se convierte en permiso denegado', () {
    final result = apply(importState(), page([]));
    expect(result.nextState.readAccess, ActivityReadAccess.queryAllowed);
    expect(result.nextState.activities, isEmpty);
    expect(result.nextState.cursor, 'cursor-1');
  });

  test('cursor obsoleto falla sin reabrir una ventana aplicada', () {
    final state = apply(importState(), page([running()])).nextState;
    expect(
      () => apply(state, page([], operation: 'old-page')),
      throwsA(hasProblem(ActivityProblem.staleCursor)),
    );
    expect(state.cursor, 'cursor-1');
  });

  test('actualiza revisión más reciente sin modificar el objeto anterior', () {
    final old = running();
    final next = running(
      revision: 'r2',
      modifiedAt: modification.add(const Duration(seconds: 1)),
      metrics: const ActivityMetrics(distanceMeters: 2100),
    );
    final result = apply(importState(records: [old]), page([next]));
    expect(result.updated, 1);
    expect(result.nextState.activities.single, same(next));
    expect(old.metrics.distanceMeters, 2000);
  });

  test(
    'tokens opacos no ordenan versiones y una revisión antigua no revive datos',
    () {
      final latest = running(revision: '2');
      final older = running(
        revision: '100',
        modifiedAt: modification.subtract(const Duration(days: 1)),
      );
      final result = apply(importState(records: [latest]), page([older]));
      expect(result.stale, 1);
      expect(result.nextState.activities.single, same(latest));
    },
  );

  test('sin orden demostrable conserva el anterior y exige recuperación', () {
    for (final changed in [
      running(revision: 'r2', unknownModificationTime: true),
      running(revision: 'r2'),
    ]) {
      final old = running();
      final result = apply(importState(records: [old]), page([changed]));
      expect(result.nextState.records.values.single, same(old));
      expect(result.nextState.activities, isEmpty);
      expect(
        result.nextState.quarantine.single.reason,
        ActivityQuarantineReason.unknownRevisionOrder,
      );
    }
  });

  test(
    'un token reutilizado con otras métricas no sobreescribe ni se ofrece',
    () {
      final original = running();
      final changed = running(
        metrics: const ActivityMetrics(distanceMeters: 9000),
      );
      final result = apply(
        importState(records: [original]),
        page([changed, changed]),
      );
      expect(result.nextState.records.values.single, same(original));
      expect(result.nextState.quarantine.length, 1);
      expect(
        result.nextState.quarantine.single.reason,
        ActivityQuarantineReason.revisionCollision,
      );
      expect(result.nextState.activities, isEmpty);
    },
  );

  test(
    'una revisión inválida más nueva bloquea propuestas hasta corregirse',
    () {
      final original = running();
      final broken = running(
        revision: 'r2',
        modifiedAt: modification.add(const Duration(seconds: 1)),
        missingEnd: true,
      );
      final rejected = apply(importState(records: [original]), page([broken]));
      expect(rejected.nextState.activities, isEmpty);
      expect(rejected.nextState.records.values.single, same(original));
      final repaired = running(
        revision: 'r3',
        modifiedAt: modification.add(const Duration(seconds: 2)),
      );
      final recovered = apply(
        rejected.nextState,
        page(
          [repaired],
          operation: 'repair',
          expectedCursor: 'cursor-1',
          nextCursor: 'cursor-2',
        ),
      );
      expect(recovered.nextState.activities.single, same(repaired));
      expect(recovered.nextState.quarantine.length, 1);
      expect(recovered.nextState.needsRecovery(repaired), isFalse);
    },
  );

  test('borrado, relectura antigua y recuperación respetan revisiones', () {
    final original = running();
    final deletion = ActivityDeletion(
      identity: original.identity,
      revision: ActivityRevision(
        'r2',
        modifiedAtUtc: modification.add(const Duration(seconds: 1)),
      ),
    );
    final deleted = apply(
      importState(records: [original]),
      page([deletion, original]),
    );
    expect(deleted.stale, 1);
    expect(deleted.nextState.activities, isEmpty);
    expect(deleted.nextState.records.values.single, same(deletion));
    final restored = running(
      revision: 'r3',
      modifiedAt: modification.add(const Duration(seconds: 2)),
    );
    final recovered = apply(
      deleted.nextState,
      page([restored], operation: 'restore', expectedCursor: 'cursor-1'),
    );
    expect(recovered.nextState.activities.single, same(restored));
  });

  test('el estado inicial también rechaza un ámbito mezclado', () {
    expect(
      () => importState(
        records: [running(key: identity(account: 'other'))],
      ),
      throwsA(hasProblem(ActivityProblem.wrongScope)),
    );
  });
}
