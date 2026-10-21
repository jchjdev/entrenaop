import 'dart:convert';

import 'package:entrenaop/features/workouts/data/services/client_technique_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const pupil = '10000000-0000-4000-8000-000000000001';
const asset = '20000000-0000-4000-8000-000000000001';
const video = '30000000-0000-4000-8000-000000000001';

class TechniqueServer {
  bool assigned = true;
  final calls = <http.Request>[];
  late final client = SupabaseClient(
    'https://technique.example.invalid',
    'fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handle),
  );
  Future<http.Response> handle(http.Request request) async {
    calls.add(request);
    Object? result;
    final path = request.url.path;
    if (path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': pupil, 'exp': 4102444800})))
          .replaceAll('=', '');
      result = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': pupil,
          'aud': 'authenticated',
          'role': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-21T00:00:00Z',
        },
      };
    } else if (path == '/rest/v1/scheduled_workouts') {
      result = assigned
          ? [
              {'id': 'assignment'},
            ]
          : [];
    } else if (path.endsWith('/get_client_technique_context')) {
      result = {
        'assignment_id': 'assignment',
        'execution_id': 'execution',
        'can_upload': true,
        'source_limit': 100 * 1024 * 1024,
        'duration_limit': 180,
      };
    } else if (path.endsWith('/list_client_technique_videos')) {
      result = [];
    } else if (path.endsWith('/set_client_technique_shared')) {
      result = null;
    } else if (path.endsWith('/exercise-video')) {
      final body = jsonDecode(request.body) as Map;
      if (body['action'] == 'create') {
        result = {
          'id': asset,
          'video_id': video,
          'library_id': 42,
          'expiration': 4102444800,
          'signature': List.filled(64, 'a').join(),
          'scope': 'client_technique',
          'source_limit': 100 * 1024 * 1024,
        };
      } else {
        result = {'status': 'ready'};
      }
    } else {
      throw StateError('Solicitud inesperada: $path');
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  late TechniqueServer server;
  late SupabaseClientTechniqueRepository repository;
  setUp(() async {
    server = TechniqueServer();
    await server.client.auth.signInWithPassword(
      email: 'pupil@example.invalid',
      password: 'fixture',
    );
    repository = SupabaseClientTechniqueRepository(server.client, pupil);
    server.calls.clear();
  });
  tearDown(() async => server.client.dispose());
  test('historial personal no consulta recursos profesionales y filtra cuenta propia', () async {
    server.assigned = false;
    expect(await repository.context('execution'), isNull);
    expect(server.calls, hasLength(1));
    final query = server.calls.single.url.queryParameters;
    expect(query['user_id'], 'eq.$pupil');
    expect(query['execution_id'], 'eq.execution');
    expect(query['source'], 'eq.coach');
  });
  test(
    'subida vincula asignación, ejecución y serie sin elegir preparador',
    () async {
      final context = (await repository.context('execution'))!;
      final source = repository.uploader(context, executionSetId: 'set');
      await source.create(123);
      final body = jsonDecode(server.calls.last.body) as Map;
      expect(body['scope'], 'client_technique');
      expect(body['assignment_id'], 'assignment');
      expect(body['execution_id'], 'execution');
      expect(body['execution_set_id'], 'set');
      expect(body['expected_user_id'], pupil);
      expect(body.containsKey('trainer_id'), isFalse);
      expect(body.containsKey('client_id'), isFalse);
    },
  );
  test('reanudación no permite cambiar la ejecución de una reserva', () async {
    final context = (await repository.context('execution'))!;
    final before = server.calls.length;
    expect(
      () => repository.uploader(
        context,
        resume: {
          'scope': 'client_technique',
          'assignment_id': 'other',
          'execution_id': 'execution',
        },
      ),
      throwsFormatException,
    );
    expect(server.calls.length, before);
  });
  test(
    'otra identidad no solicita contexto y compartir mantiene la operación',
    () async {
      final wrong = SupabaseClientTechniqueRepository(server.client, video);
      await expectLater(wrong.context('execution'), throwsStateError);
      expect(server.calls, isEmpty);
      await repository.setShared('operation', asset, false);
      final body = jsonDecode(server.calls.single.body) as Map;
      expect(body, {
        'p_operation_id': 'operation',
        'p_id': asset,
        'p_shared': false,
      });
    },
  );
}
