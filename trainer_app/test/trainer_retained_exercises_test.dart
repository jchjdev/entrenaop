import 'package:entrenaop_trainer/trainer_exercise_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'trainer_exercise_repository_test.dart' as fixture;

class _Server extends fixture.ServerFixture {
  final retainedRequests = <http.Request>[];
  Future<void> Function()? beforeRetainedReply;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/rest/v1/exercises' &&
        request.url.queryParameters.containsKey('id')) {
      retainedRequests.add(request);
      if (beforeRetainedReply case final callback?) await callback();
      return super.json(request, [
        {
          'id': 'private-trashed',
          'name': 'Dominada conservada',
          'muscle_groups': ['espalda'],
          'equipment': ['barra'],
          'origin': 'coach',
          'created_by': fixture.owner,
          'image_path': '${fixture.owner}/private-trashed.jpg',
        },
        {
          'id': 'official-trashed',
          'name': 'Oficial conservado',
          'muscle_groups': ['piernas'],
          'equipment': [],
          'origin': 'system',
          'created_by': null,
          'image_path': 'official-trashed.jpg',
        },
        // El servidor no devuelve los IDs ajenos sin permiso de lectura.
      ]);
    }
    return super.handle(request);
  }
}

void main() {
  test('receta antigua conserva nombre, foto y origen sin ofrecer retirados para añadir', () async {
    final server = _Server();
    addTearDown(server.client.dispose);
    await server.login();
    final repository = SupabaseTrainerWorkoutRepository(
      server.client,
      fixture.owner,
    );
    final exercises = await repository.exercises(
      retainedIds: {'private-trashed', 'official-trashed', 'inaccesible'},
    );
    final private = exercises.singleWhere((e) => e.id == 'private-trashed');
    final official = exercises.singleWhere((e) => e.id == 'official-trashed');
    expect(private.name, 'Dominada conservada');
    expect(private.thumbnailUrl, contains('token=fixture'));
    expect(private.catalogScope, 'Míos');
    expect(private.selectable, isFalse);
    expect(
      official.thumbnailUrl,
      contains('/exercise-images-public/official-trashed.jpg'),
    );
    expect(official.catalogScope, 'EntrenaOP');
    expect(official.selectable, isFalse);
    expect(exercises.any((e) => e.id == 'inaccesible'), isFalse);
    final request = server.retainedRequests.single;
    expect(request.url.queryParameters['id'], contains('private-trashed'));
    expect(request.headers['Authorization'], contains('Bearer '));
    final fresh = await repository.exercises();
    expect(fresh.any((e) => !e.selectable), isFalse);
    expect(fresh.any((e) => e.id.endsWith('-trashed')), isFalse);
    expect(server.retainedRequests, hasLength(1));
  });

  test('cambio de cuenta durante lectura retenida no devuelve ni firma metadatos anteriores', () async {
    final server = _Server();
    addTearDown(server.client.dispose);
    await server.login();
    server.beforeRetainedReply = () => server.client.auth.signOut();
    final repository = SupabaseTrainerExerciseRepository(
      server.client,
      fixture.owner,
    );
    await expectLater(
      repository.retainedForEditor({'private-trashed'}),
      throwsStateError,
    );
    expect(server.retainedRequests, hasLength(1));
    expect(
      server.requests.where((r) => r.url.path.contains('/object/sign/')),
      isEmpty,
    );
  });
}
