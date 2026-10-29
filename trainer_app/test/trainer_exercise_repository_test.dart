import 'dart:convert';
import 'dart:typed_data';

import 'package:entrenaop_trainer/trainer_exercise_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

const owner = '10000000-0000-4000-8000-000000000001';
const operation = '20000000-0000-4000-8000-000000000001';
const draft = ExerciseDraft(
  name: 'Dominada propia',
  muscleGroups: ['espalda'],
  equipment: ['barra'],
  difficulty: 'intermedio',
  exerciseType: 'repeticiones',
);

Map<String, dynamic> row(String id, {bool current = true}) => {
  'id': id,
  'name': id,
  'version': 1,
  'current': current,
  'image_path': '$owner/$id.jpg',
  'muscle_groups': ['espalda'],
  'equipment': ['barra'],
  'difficulty': 'intermedio',
  'exercise_type': 'repeticiones',
};

class ServerFixture {
  final requests = <http.Request>[];
  final payloads = <Map<String, dynamic>>[];
  Uint8List? stored;
  bool failSave = true;
  bool failUploadOnce = false;
  int uploads = 0;
  List<Map<String, dynamic>> workoutRows = [], workoutDetails = [];
  List<Map<String, dynamic>> officialRows = [
    {
      'id': 'official',
      'name': 'Oficial',
      'muscle_groups': ['espalda'],
      'equipment': [],
      'difficulty': 'inicial',
      'exercise_type': 'repeticiones',
      'image_path': null,
    },
  ];
  late final client = SupabaseClient(
    'https://trainer-fixture.example.com',
    'fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handle),
  );

  http.Response json(http.Request request, Object? body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/auth/v1/logout') return json(request, {});
    if (path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      return json(request, {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'role': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-21T00:00:00Z',
        },
      });
    }
    if (path.endsWith('/rpc/reserve_trainer_exercise_image')) {
      return json(request, '$owner/$operation.jpg');
    }
    if (path.endsWith('/rpc/save_trainer_exercise')) {
      payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (failSave) {
        return json(request, {
          'message': 'Conexión interrumpida',
          'code': 'PGRST000',
        }, 503);
      }
      return json(request, 'saved');
    }
    if (path.endsWith('/rpc/list_trainer_exercises')) {
      return json(request, [row('current'), row('old', current: false)]);
    }
    if (path.endsWith('/rpc/list_trainer_workouts')) {
      return json(request, workoutRows);
    }
    if (path == '/rest/v1/workout_templates') {
      return json(request, workoutDetails);
    }
    if (path == '/rest/v1/exercises') {
      final offset =
          int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;
      return json(request, officialRows.skip(offset).take(500).toList());
    }
    if (path.endsWith('/object/sign/trainer-exercise-images')) {
      final paths = (jsonDecode(request.body) as Map)['paths'] as List;
      return json(request, [
        for (final value in paths)
          {
            'path': value,
            'signedURL':
                '/object/sign/trainer-exercise-images/$value?token=fixture',
          },
      ]);
    }
    if (path.contains('/object/trainer-exercise-images/')) {
      if (request.method == 'POST') {
        uploads++;
        // El SDK envía multipart: el servidor guarda los bytes del archivo,
        // no la envoltura con cacheControl y los separadores MIME.
        expect(request.bodyBytes, containsAllInOrder([1, 2, 3]));
        stored = Uint8List.fromList([1, 2, 3]);
        if (failUploadOnce) {
          failUploadOnce = false;
          return json(request, {
            'statusCode': '503',
            'error': 'timeout',
            'message': 'Respuesta perdida tras almacenar',
          }, 503);
        }
        return json(request, {'Key': '$owner/$operation.jpg'});
      }
      if (stored == null) {
        return json(request, {
          'statusCode': '404',
          'error': 'not_found',
          'message': 'Object not found',
        }, 400);
      }
      return http.Response.bytes(stored!, 200, request: request);
    }
    throw StateError('Petición inesperada: $path');
  }

  Future<void> login() => client.auth.signInWithPassword(
    email: 'trainer@example.invalid',
    password: 'fixture',
  );
}

void main() {
  test(
    'biblioteca lee formatos y ejercicios en lote limitado a los IDs propios',
    () async {
      final server = ServerFixture()
        ..workoutRows = [
          {
            'id': 'session',
            'name': 'Mesociclo A',
            'version': 1,
            'created_at': '2026-10-29T10:00:00Z',
            'is_running': false,
          },
        ]
        ..workoutDetails = [
          {
            'id': 'session',
            'description': 'Plan privado',
            'workout_blocks': [
              {
                'name': 'Bloque principal',
                'format': 'amrap',
                'workout_items': [
                  {
                    'exercises': {'name': 'Dominadas'},
                  },
                ],
              },
              {'name': 'Final', 'format': 'tabata', 'workout_items': []},
            ],
          },
        ];
      addTearDown(server.client.dispose);
      await server.login();
      final items = await SupabaseTrainerWorkoutRepository(
        server.client,
        owner,
      ).workouts();
      expect(items.single.formats, ['amrap', 'tabata']);
      expect(items.single.searchContent, contains('Dominadas'));
      final requests = server.requests
          .where((r) => r.url.path == '/rest/v1/workout_templates')
          .toList();
      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters['owner_user_id'], 'eq.$owner');
      expect(requests.single.url.queryParameters['origin'], 'eq.coach');
      expect(requests.single.url.queryParameters['id'], contains('session'));
    },
  );

  test(
    'catálogo público paginado mantiene fotos y origen sin firmar ni copiar',
    () async {
      final server = ServerFixture();
      server.officialRows = List.generate(
        501,
        (i) => {
          ...server.officialRows.first,
          'id': 'official-$i',
          'image_path': i == 0 ? 'official/photo.jpg' : null,
          'description': 'Técnica oficial',
        },
      );
      addTearDown(server.client.dispose);
      await server.login();
      final repository = SupabaseTrainerExerciseRepository(
        server.client,
        owner,
      );
      final items = await repository.officialCatalog();
      expect(items, hasLength(501));
      expect(items.every((e) => e.official), isTrue);
      expect(items.first.draft.description, 'Técnica oficial');
      expect(
        items.singleWhere((e) => e.id == 'official-0').imageUrl,
        contains('/object/public/exercise-images-public/official/photo.jpg'),
      );
      final requests = server.requests
          .where((r) => r.url.path == '/rest/v1/exercises')
          .toList();
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.url.queryParameters['origin'], 'eq.system');
        expect(request.url.queryParameters['is_public'], 'eq.true');
        expect(request.method, 'GET');
      }
      await expectLater(
        repository.save(
          operation,
          const ExerciseFormSubmission(draft: draft),
          previous: items.first,
        ),
        throwsStateError,
      );
      expect(server.payloads, isEmpty);
      expect(server.uploads, 0);
      expect(
        server.requests.where((r) => r.url.path.contains('/object/sign/')),
        isEmpty,
      );
      await server.client.auth.signOut(scope: SignOutScope.local);
      await expectLater(repository.officialCatalog(), throwsStateError);
    },
  );

  test(
    'una subida confirmada tarde se recupera sin sobrescribir la imagen',
    () async {
      final server = ServerFixture()
        ..failSave = false
        ..failUploadOnce = true;
      addTearDown(server.client.dispose);
      await server.login();
      final repository = SupabaseTrainerExerciseRepository(
        server.client,
        owner,
      );
      final submission = ExerciseFormSubmission(
        draft: draft,
        image: ExerciseImageUpload(bytes: Uint8List.fromList([1, 2, 3])),
      );
      await expectLater(
        repository.save(operation, submission),
        throwsA(isA<StorageException>()),
      );
      expect(await repository.save(operation, submission), 'saved');
      expect(server.uploads, 1);
      expect(server.payloads, hasLength(1));
    },
  );
  test(
    'reintentar conserva la misma imagen, ruta y contenido sin subir dos veces',
    () async {
      final server = ServerFixture();
      addTearDown(server.client.dispose);
      await server.login();
      final repository = SupabaseTrainerExerciseRepository(
        server.client,
        owner,
      );
      final submission = ExerciseFormSubmission(
        draft: draft,
        image: ExerciseImageUpload(bytes: Uint8List.fromList([1, 2, 3])),
      );
      await expectLater(
        repository.save(operation, submission),
        throwsA(isA<PostgrestException>()),
      );
      server.failSave = false;
      expect(await repository.save(operation, submission), 'saved');
      expect(server.uploads, 1);
      expect(server.payloads, hasLength(2));
      expect(server.payloads[0], server.payloads[1]);
      expect(
        server.payloads.last['p_payload']['image_path'],
        '$owner/$operation.jpg',
      );
    },
  );

  test('no confirma una foto distinta bajo una operación ya subida', () async {
    final server = ServerFixture()..stored = Uint8List.fromList([9]);
    addTearDown(server.client.dispose);
    await server.login();
    final repository = SupabaseTrainerExerciseRepository(server.client, owner);
    await expectLater(
      repository.save(
        operation,
        ExerciseFormSubmission(
          draft: draft,
          image: ExerciseImageUpload(bytes: Uint8List.fromList([1])),
        ),
      ),
      throwsStateError,
    );
    expect(server.payloads, isEmpty);
    expect(server.uploads, 0);
  });

  test('el selector mezcla públicos y propios y conserva solo la revisión antigua fijada', () async {
    final server = ServerFixture();
    addTearDown(server.client.dispose);
    await server.login();
    final repository = SupabaseTrainerWorkoutRepository(server.client, owner);
    expect((await repository.exercises()).map((e) => e.id), [
      'official',
      'current',
    ]);
    final retained = await repository.exercises(retainedIds: {'old'});
    expect(retained.first.catalogScope, 'EntrenaOP');
    expect(retained.skip(1).every((e) => e.catalogScope == 'Míos'), isTrue);
    expect(retained.map((e) => e.id), ['official', 'current', 'old']);
    expect(
      retained.last.thumbnailUrl,
      contains('/sign/trainer-exercise-images/'),
    );
    expect(
      server.requests.where(
        (r) => r.url.path.contains('exercise-images-public'),
      ),
      isEmpty,
    );
  });
}
