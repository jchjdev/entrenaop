import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/data/repositories/workout_repository_impl.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_editor_draft_store.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_mutation_queue.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  String? userId;
  late SharedPreferencesWorkoutMutationQueue queue;
  late _Remote remote;
  late WorkoutRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    userId = 'A';
    queue = SharedPreferencesWorkoutMutationQueue(
      preferences,
      currentUserId: () => userId,
    );
    remote = _Remote();
    repository = WorkoutRepositoryImpl(
      remoteDataSource: remote,
      mutationQueue: queue,
      currentUserId: () => userId,
    );
  });

  test('B sincroniza lo suyo y A conserva sus pendientes al volver', () async {
    await queue.enqueue(_mutation('A'));
    userId = 'B';
    await queue.enqueue(_mutation('B'));
    expect(await repository.getPendingMutationCount(), 1);
    await repository.syncPendingMutations();
    expect(remote.sent, ['result-B']);
    expect(await queue.readAll(), isEmpty);
    userId = 'A';
    expect(await queue.readAll(), [_mutation('A')]);
    await repository.syncPendingMutations();
    expect(remote.sent, ['result-B', 'result-A']);
  });

  test('un fallo offline tras cambiar de cuenta se guarda para A', () async {
    final started = Completer<void>();
    final send = Completer<void>();
    remote.beforeSend = () {
      started.complete();
      return send.future;
    };
    final result = repository.completeSet(
      const WorkoutSetResultInput(resultId: 'result-A', actualReps: 8),
    );
    await started.future;
    userId = 'B';
    send.completeError(StateError('Sin conexión'));
    expect(await result, WorkoutMutationDisposition.queued);
    expect(await queue.readAll(), isEmpty);
    userId = 'A';
    expect((await queue.readAll()).single.resourceId, 'result-A');
  });

  test('cambiar de cuenta detiene los siguientes envíos de la cola', () async {
    await queue.enqueue(_mutation('A'));
    await queue.enqueue(_mutation('A', operation: 'second'));
    remote.beforeSend = () async {
      userId = 'B';
    };
    await expectLater(
      repository.syncPendingMutations(),
      throwsA(isA<AuthException>()),
    );
    expect(remote.sent, ['result-A']);
    userId = 'A';
    expect((await queue.readAll()).single.operationId, 'second');
  });

  test(
    'sin sesión no expone pendientes ni registra operaciones nuevas',
    () async {
      await queue.enqueue(_mutation('A'));
      userId = null;
      expect(await queue.readAll(), isEmpty);
      expect(
        () => repository.skipSet('result-A'),
        throwsA(isA<AuthException>()),
      );
      expect(remote.sent, isEmpty);
    },
  );

  test('los registros simultáneos no pierden operaciones', () async {
    await Future.wait(
      List.generate(20, (i) => queue.enqueue(_mutation('A', operation: '$i'))),
    );
    expect(await queue.readAll(), hasLength(20));
    await Future.wait([
      queue.remove('0', userId: 'A'),
      queue.enqueue(_mutation('A', operation: 'new')),
    ]);
    expect(await queue.readAll(), hasLength(20));
    expect((await queue.readAll()).map((m) => m.operationId), contains('new'));
  });

  test(
    'v1 se recupera solo para su dueño y no resucita tras enviarse',
    () async {
      final encoded = _legacy([_mutation('A'), _mutation('B')]);
      await preferences.setString('workout.pending_mutations.v1', encoded);
      queue = SharedPreferencesWorkoutMutationQueue(
        preferences,
        currentUserId: () => userId,
        ownsLegacyMutation: (mutation, owner) async =>
            mutation.resourceId == 'result-$owner',
      );
      userId = 'B';
      expect(await queue.readAll(), [_mutation('B')]);
      await queue.remove('operation-B', userId: 'B');
      expect(await queue.readAll(), isEmpty);
      userId = 'A';
      expect(await queue.readAll(), [_mutation('A')]);
      expect(preferences.getString('workout.pending_mutations.v1'), encoded);
    },
  );

  test('sin red conserva v1 y permite trabajar con la cola nueva', () async {
    final encoded = _legacy([_mutation('A')]);
    await preferences.setString('workout.pending_mutations.v1', encoded);
    var online = false;
    queue = SharedPreferencesWorkoutMutationQueue(
      preferences,
      currentUserId: () => userId,
      ownsLegacyMutation: (mutation, owner) async {
        if (!online) throw StateError('Sin red');
        return true;
      },
    );
    await queue.enqueue(_mutation('A', operation: 'new'));
    expect((await queue.readAll()).map((m) => m.operationId), ['new']);
    expect(preferences.getString('workout.pending_mutations.v1'), encoded);
    online = true;
    expect(await queue.readAll(), hasLength(2));
  });

  test('un cambio de cuenta durante la recuperación no mezcla datos', () async {
    await preferences.setString(
      'workout.pending_mutations.v1',
      _legacy([_mutation('A')]),
    );
    queue = SharedPreferencesWorkoutMutationQueue(
      preferences,
      currentUserId: () => userId,
      ownsLegacyMutation: (mutation, owner) async {
        userId = 'B';
        return true;
      },
    );
    expect(await queue.readAll(), isEmpty);
    expect(preferences.containsKey('workout.pending_mutations.v2:A'), isFalse);
    expect(preferences.containsKey('workout.pending_mutations.v2:B'), isFalse);
  });

  test(
    'una cola ilegible no se borra ni se sobrescribe al registrar',
    () async {
      await preferences.setString('workout.pending_mutations.v2:A', 'ilegible');
      await expectLater(queue.readAll(), throwsFormatException);
      await expectLater(queue.enqueue(_mutation('A')), throwsFormatException);
      expect(
        preferences.getString('workout.pending_mutations.v2:A'),
        'ilegible',
      );
      await preferences.remove('workout.pending_mutations.v2:A');
      await queue.enqueue(_mutation('A'));
      expect(await queue.readAll(), hasLength(1));
    },
  );

  test(
    'borradores de fuerza y carrera se separan y se conservan por cuenta',
    () async {
      final storeA = SharedPreferencesWorkoutEditorDraftStore(
        preferences,
        userId: 'A',
      );
      final storeB = SharedPreferencesWorkoutEditorDraftStore(
        preferences,
        userId: 'B',
      );
      for (final id in ['new', 'new-running', 'template-1']) {
        await storeA.write(id, _draft('A'));
        expect(await storeB.read(id), isNull);
        await storeB.write(id, _draft('B'));
        await storeB.clear(id);
        expect(await storeA.read(id), _draft('A'));
      }
      final restoredA = SharedPreferencesWorkoutEditorDraftStore(
        preferences,
        userId: 'A',
      );
      expect(await restoredA.read('new'), _draft('A'));
    },
  );

  test('v1 sin propietario se conserva sin ofrecerse a otra cuenta', () async {
    final encoded = jsonEncode({
      'saved_at': DateTime.utc(2026).toIso8601String(),
      'input': {'name': 'Antiguo', 'blocks': []},
    });
    await preferences.setString('workout_editor_draft_v1:new', encoded);
    final store = SharedPreferencesWorkoutEditorDraftStore(
      preferences,
      userId: 'B',
    );
    expect(await store.read('new'), isNull);
    await store.write('new', _draft('B'));
    await store.clear('new');
    expect(preferences.getString('workout_editor_draft_v1:new'), encoded);
  });

  test('un guardado tardío del editor de A no sobrescribe el de B', () async {
    final storeA = SharedPreferencesWorkoutEditorDraftStore(
      preferences,
      userId: 'A',
    );
    userId = 'B';
    final storeB = SharedPreferencesWorkoutEditorDraftStore(
      preferences,
      userId: 'B',
    );
    await storeB.write('new', _draft('B'));
    await storeA.write('new', _draft('A'));
    expect(await storeB.read('new'), _draft('B'));
    expect(await storeA.read('new'), _draft('A'));
  });
}

PendingWorkoutMutation _mutation(String user, {String? operation}) =>
    PendingWorkoutMutation(
      userId: user,
      operationId: operation ?? 'operation-$user',
      type: WorkoutMutationType.completeSet,
      resourceId: 'result-$user',
      values: {'p_result_id': 'result-$user'},
      createdAt: DateTime.utc(2026, 10, 6),
    );

String _legacy(List<PendingWorkoutMutation> mutations) => jsonEncode(
  mutations
      .map(
        (m) => {
          'operation_id': m.operationId,
          'type': m.type.name,
          'resource_id': m.resourceId,
          'values': m.values,
          'created_at': m.createdAt.toIso8601String(),
        },
      )
      .toList(),
);

WorkoutEditorDraftSnapshot _draft(String user) => WorkoutEditorDraftSnapshot(
  savedAt: DateTime.utc(2026),
  input: CreatePersonalWorkoutInput(name: 'Sesión $user', blocks: const []),
);

class _Remote implements WorkoutRemoteDataSource {
  final sent = <String>[];
  Future<void> Function()? beforeSend;

  @override
  Future<void> completeSet(
    String operationId,
    Map<String, dynamic> values,
  ) async {
    await beforeSend?.call();
    sent.add(values['p_result_id'] as String);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
