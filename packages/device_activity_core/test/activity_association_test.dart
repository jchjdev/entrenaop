import 'package:device_activity_core/device_activity_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

ActivityAssociationPlan confirm({
  required ActivityAssociationReview review,
  ActivityAssociationState? state,
  Iterable<ActivityChange>? observations,
  RunningSessionTarget? session,
  String owner = 'athlete',
}) => const ConfirmActivityAssociation()(
  ownerId: owner,
  current: state ?? ActivityAssociationState(ownerId: 'athlete'),
  review: review,
  currentObservations: observations ?? review.observations,
  currentTarget: session ?? review.target,
  confirmedAtUtc: modification,
);

ActivityAssociationReview review({
  ExternalActivity? activity,
  RunningSessionTarget? session,
  String operation = 'association-1',
  Iterable<ExternalActivity> aliases = const [],
}) => reviewRunningActivity(
  ownerId: 'athlete',
  operationId: operation,
  primary: activity ?? running(),
  target: session ?? target(),
  aliases: aliases,
);

void main() {
  test(
    'propone todas las citas propias del día local sin escoger una pauta',
    () {
      final sessions = [
        target(id: 'algorithm'),
        target(id: 'coach'),
        target(id: 'other-owner', owner: 'other'),
        target(id: 'tomorrow', date: ActivityLocalDate(2026, 10, 22)),
        target(id: 'retired', status: RunningSessionStatus.retired),
      ];
      final proposed = proposeRunningSessions(
        ownerId: 'athlete',
        activity: running(),
        targets: sessions,
      );
      expect(proposed.map((item) => item.id), ['algorithm', 'coach']);
      expect(sessions[0].status, RunningSessionStatus.planned);
      expect(sessions[1].executionId, isNull);
      expect(() => proposed.clear(), throwsUnsupportedError);
    },
  );

  test('offset desconocido no se convierte en fecha UTC para proponer', () {
    expect(
      proposeRunningSessions(
        ownerId: 'athlete',
        activity: running(startOffset: null),
        targets: [target()],
      ),
      isEmpty,
    );
    // La ausencia de sugerencia no impide elegir una cita de forma explícita.
    expect(
      confirm(review: review(activity: running(startOffset: null)))
          .association
          .sessionId,
      'session-1',
    );
  });

  test('confirmar asocia sin crear ejecución ni completar la pauta', () {
    final preview = review();
    final result = confirm(review: preview);
    expect(result.expectedCheckpoint, 0);
    expect(result.nextState.checkpoint, 1);
    expect(result.association.primaryIdentity, preview.primary.identity);
    expect(result.association.executionId, isNull);
    expect(preview.target.status, RunningSessionStatus.planned);
    expect(preview.primary.metrics.averageHeartRateBpm, isNull);
    expect(() => result.nextState.associations.clear(), throwsUnsupportedError);
  });

  test('una ejecución existente se conserva al asociar', () {
    final result = confirm(
      review: review(
        session: target(
          executionId: 'existing-execution',
          resultRevision: 'result-2',
          status: RunningSessionStatus.completed,
        ),
      ),
    );
    expect(result.association.executionId, 'existing-execution');
    expect(result.association.review.target.resultRevision, 'result-2');
  });

  test(
    'titular elige primaria y alias sin fusionar métricas ni priorizar marca',
    () {
      final direct = running();
      final health = running(
        key: identity(channel: ActivityChannel.appleHealth),
        upstream: direct.identity,
        metrics: const ActivityMetrics(distanceMeters: 2300),
      );
      final preview = review(activity: direct, aliases: [health]);
      final result = confirm(review: preview);
      expect(result.association.identities.toSet(), {
        direct.identity,
        health.identity,
      });
      expect(result.association.review.primary.metrics.distanceMeters, 2000);
      expect(result.nextState.associations.length, 1);
      final reusedAlias = review(
        activity: health,
        session: target(id: 'other-session'),
        operation: 'association-2',
      );
      expect(
        () => confirm(review: reusedAlias, state: result.nextState),
        throwsA(hasProblem(ActivityProblem.activityAlreadyAssociated)),
      );
    },
  );

  test('un reintento devuelve la asociación original incluso tras cambios posteriores', () {
    final preview = review();
    final first = confirm(review: preview);
    final retry = confirm(
      review: preview,
      state: first.nextState,
      observations: [running(revision: 'r2')],
      session: target(
        revision: 'schedule-r2',
        status: RunningSessionStatus.retired,
      ),
    );
    expect(retry.isReplay, isTrue);
    expect(retry.association, same(first.association));
    expect(retry.nextState, same(first.nextState));
    expect(retry.association.review.primary.revision.token, 'r1');
  });

  test('la misma orden con otra cita no reutiliza una confirmación', () {
    final first = confirm(review: review());
    expect(
      () => confirm(
        review: review(session: target(id: 'other-session')),
        state: first.nextState,
      ),
      throwsA(hasProblem(ActivityProblem.reusedOperation)),
    );
  });

  test(
    'la asociación mantiene cardinalidad uno a uno entre órdenes diferentes',
    () {
      final first = confirm(review: review());
      expect(
        () => confirm(
          review: review(
            operation: 'other-operation',
            session: target(id: 'other-session'),
          ),
          state: first.nextState,
        ),
        throwsA(hasProblem(ActivityProblem.activityAlreadyAssociated)),
      );
      expect(
        () => confirm(
          review: review(
            operation: 'other-operation',
            activity: running(key: identity(id: 'other-run')),
          ),
          state: first.nextState,
        ),
        throwsA(hasProblem(ActivityProblem.sessionAlreadyAssociated)),
      );
      expect(first.nextState.associations.length, 1);
    },
  );

  test('otra revisión, contenido cambiado, borrado o ausencia invalidan la vista previa', () {
    final preview = review();
    final changes = <List<ActivityChange>>[
      [running(revision: 'r2')],
      [running(metrics: const ActivityMetrics(distanceMeters: 9000))],
      [
        ActivityDeletion(
          identity: preview.primary.identity,
          revision: ActivityRevision('deleted'),
        ),
      ],
      [],
    ];
    for (final observations in changes) {
      expect(
        () => confirm(review: preview, observations: observations),
        throwsA(hasProblem(ActivityProblem.staleReview)),
      );
    }
  });

  test('revisar exige otra vez los alias si cambia su observación', () {
    final health = running(key: identity(channel: ActivityChannel.appleHealth));
    final preview = review(aliases: [health]);
    expect(
      () => confirm(
        review: preview,
        observations: [
          preview.primary,
          running(key: health.identity, revision: 'r2'),
        ],
      ),
      throwsA(hasProblem(ActivityProblem.staleReview)),
    );
  });

  test(
    'cambio de receta, agenda, resultado o ejecución exige una nueva revisión',
    () {
      final preview = review();
      for (final changed in [
        target(templateVersion: 2),
        target(revision: 'schedule-r2'),
        target(executionId: 'new-execution'),
        target(executionId: 'execution', resultRevision: 'result-r2'),
        target(date: ActivityLocalDate(2026, 10, 22)),
        target(status: RunningSessionStatus.inProgress),
      ]) {
        expect(
          () => confirm(review: preview, session: changed),
          throwsA(hasProblem(ActivityProblem.staleReview)),
        );
      }
      expect(
        () => confirm(
          review: preview,
          session: target(status: RunningSessionStatus.retired),
        ),
        throwsA(hasProblem(ActivityProblem.unavailableSession)),
      );
    },
  );

  test('no abre datos de otro alumno ni al actor equivocado', () {
    expect(
      () => review(
        activity: running(key: identity(owner: 'other')),
      ),
      throwsA(hasProblem(ActivityProblem.wrongOwner)),
    );
    expect(
      () => review(session: target(owner: 'other')),
      throwsA(hasProblem(ActivityProblem.wrongOwner)),
    );
    expect(
      () => review(
        aliases: [running(key: identity(owner: 'other'))],
      ),
      throwsA(hasProblem(ActivityProblem.wrongOwner)),
    );
    expect(
      () => confirm(review: review(), owner: 'other'),
      throwsA(hasProblem(ActivityProblem.wrongOwner)),
    );
    expect(
      () => confirm(
        review: review(),
        session: target(owner: 'other'),
      ),
      throwsA(hasProblem(ActivityProblem.wrongOwner)),
    );
  });

  test('no acepta carrera incompleta, cita retirada o alias repetidos', () {
    expect(
      () => review(activity: running(missingEnd: true)),
      throwsA(hasProblem(ActivityProblem.invalidActivity)),
    );
    expect(
      () => review(session: target(status: RunningSessionStatus.retired)),
      throwsA(hasProblem(ActivityProblem.unavailableSession)),
    );
    expect(
      () => review(aliases: [running()]),
      throwsA(hasProblem(ActivityProblem.invalidActivity)),
    );
  });

  test(
    'una actualización o borrado de importación no cambia lo ya asociado',
    () {
      final preview = review();
      final association = confirm(review: preview).association;
      final deletion = ActivityDeletion(
        identity: preview.primary.identity,
        revision: ActivityRevision(
          'r2',
          modifiedAtUtc: modification.add(const Duration(seconds: 1)),
        ),
      );
      final imported = const PlanActivityImport()(
        ownerId: 'athlete',
        current: importState(records: [preview.primary]),
        page: page([deletion]),
      );
      expect(imported.nextState.activities, isEmpty);
      expect(association.review.primary.metrics.distanceMeters, 2000);
      expect(association.review.primary.revision.token, 'r1');
      expect(association.sessionId, 'session-1');
    },
  );
}
