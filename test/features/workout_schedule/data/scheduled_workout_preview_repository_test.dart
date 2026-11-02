import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/pro/domain/pro_access.dart';

import 'package:entrenaop/features/workout_schedule/data/repositories/supabase_scheduled_workout_preview_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '10000000-0000-4000-8000-000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Server server;
  late SupabaseScheduledWorkoutPreviewRepository repository;
  setUp(() async {
    server = _Server();
    await server.client.auth.signInWithPassword(
      email: 'athlete@example.invalid',
      password: 'fixture',
    );
    repository = SupabaseScheduledWorkoutPreviewRepository(
      server.client,
      _owner,
    );
  });
  tearDown(() async => server.client.dispose());

  test(
    'lee el bloqueo Pro sin ocultar ni cambiar la versión pautada',
    () async {
      server.payload['pro_required'] = true;
      final preview = await repository.get('scheduled');
      expect(preview.proRequired, isTrue);
      expect(preview.canStart, isFalse);
      expect(preview.workout.blocks, isNotEmpty);
      expect(preview.revision, server.payload['revision']);
      expect(server.requests, hasLength(1));
    },
  );

  test('traduce Pro retirado al iniciar y no reintenta el RPC', () async {
    server.code = 'P0001';
    server.details = 'pro_required';
    await expectLater(
      repository.startReviewed('scheduled', 'revision'),
      throwsA(
        isA<ProAccessDenied>().having(
          (e) => e.restriction,
          'restricción',
          ProRestriction.adaptiveProgram,
        ),
      ),
    );
    expect(server.requests, hasLength(1));
  });

  test(
    'consulta sólo scheduled_id y convierte la versión pautada completa',
    () async {
      final preview = await repository.get('scheduled');
      expect(preview.scheduled.id, 'scheduled');
      expect(preview.scheduled.coachNote, 'Cuida la técnica');
      expect(preview.scheduled.coachName, 'Ervi');
      expect(preview.workout.version, 3);
      expect(
        preview.workout.blocks.single.items.single.sets.single.targetReps,
        8,
      );
      expect(
        preview.workout.blocks.single.items.single.sets.single.targetLoadKg,
        25,
      );
      expect(
        preview.workout.blocks.single.items.single.sets.single.restAfterSeconds,
        90,
      );
      expect(server.requests, hasLength(1));
      expect(
        server.requests.single.url.path,
        '/rest/v1/rpc/get_scheduled_workout_preview',
      );
      expect(jsonDecode(server.requests.single.body), {
        'p_expected_owner': _owner,
        'p_scheduled_id': 'scheduled',
      });
      expect(
        server.requests.single.headers['Authorization'],
        startsWith('Bearer '),
      );
    },
  );

  test(
    'rechaza una respuesta de otra pauta o versión sin consultar latest',
    () async {
      (server.payload['template'] as Map)['version'] = 4;
      await expectLater(repository.get('scheduled'), throwsFormatException);
      (server.payload['template'] as Map)['version'] = 3;
      (server.payload['scheduled_workout'] as Map)['id'] = 'other';
      await expectLater(repository.get('scheduled'), throwsFormatException);
      expect(server.requests, hasLength(2));
      expect(
        server.requests.every(
          (request) =>
              request.url.path.endsWith('/get_scheduled_workout_preview'),
        ),
        isTrue,
      );
    },
  );

  test(
    'comenzar envía la revisión exacta y traduce conflicto sin reintentar',
    () async {
      expect(
        await repository.startReviewed('scheduled', 'reviewed-hash'),
        'execution',
      );
      expect(jsonDecode(server.requests.single.body), {
        'p_expected_owner': _owner,
        'p_scheduled_id': 'scheduled',
        'p_expected_revision': 'reviewed-hash',
      });
      server.code = '40001';
      await expectLater(
        repository.startReviewed('scheduled', 'old-hash'),
        throwsA(isA<ScheduledWorkoutPreviewChanged>()),
      );
      expect(server.requests, hasLength(2));
      expect(
        server.requests.last.url.path,
        '/rest/v1/rpc/start_reviewed_scheduled_workout',
      );
    },
  );

  test(
    'una denegación no consulta otra plantilla ni intenta iniciar',
    () async {
      server.code = '42501';
      await expectLater(
        repository.get('scheduled'),
        throwsA(isA<PostgrestException>()),
      );
      expect(server.requests, hasLength(1));
      expect(
        server.requests.single.url.path,
        endsWith('/get_scheduled_workout_preview'),
      );
    },
  );

  test(
    'rechaza la respuesta si cambia la identidad durante la lectura',
    () async {
      server.pending = Completer<http.Response>();
      final reading = repository.get('scheduled');
      final rejected = expectLater(reading, throwsStateError);
      await server.sent.future;
      await server.client.auth.signOut();
      server.pending!.complete(
        _response(server.payload, server.requests.single),
      );
      await rejected;
      expect(server.requests, hasLength(1));
      await expectLater(repository.get('scheduled'), throwsStateError);
      expect(server.requests, hasLength(1));
    },
  );
}

class _Server {
  final requests = <http.Request>[];
  final sent = Completer<void>();
  Completer<http.Response>? pending;
  String? code;
  String? details;
  final payload = _payload();
  late final client = SupabaseClient(
    'https://scheduled-preview.example.invalid',
    'fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(_handle),
  );

  Future<http.Response> _handle(http.Request request) async {
    if (request.url.path == '/auth/v1/token') {
      final token = base64Url
          .encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      return _response({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$token.fixture',
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': _owner,
          'aud': 'authenticated',
          'role': 'authenticated',
          'created_at': '2026-11-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        },
      }, request);
    }
    if (request.url.path == '/auth/v1/logout') return _response({}, request);
    requests.add(request);
    if (!sent.isCompleted) sent.complete();
    if (code != null) {
      return http.Response(
        jsonEncode({
          'code': code,
          'message': 'No disponible',
          'details': details,
        }),
        code == '40001' ? 409 : 403,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    if (pending != null) return pending!.future;
    if (request.url.path.endsWith('/get_scheduled_workout_preview')) {
      return _response(payload, request);
    }
    if (request.url.path.endsWith('/start_reviewed_scheduled_workout')) {
      return _response('execution', request);
    }
    throw StateError('Petición inesperada: ${request.url.path}');
  }
}

http.Response _response(Object? data, [http.Request? request]) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, dynamic> _payload() => {
  'revision': List.filled(64, 'a').join(),
  'scheduled_workout': {
    'id': 'scheduled',
    'template_id': 'private',
    'template_name': 'Fuerza pautada',
    'template_version': 3,
    'scheduled_date': '2026-09-23',
    'source': 'coach',
    'status': 'planned',
    'trainer_name': 'Ervi',
    'trainer_assignments': {'note': 'Cuida la técnica'},
  },
  'template': {
    'id': 'private',
    'name': 'Fuerza pautada',
    'version': 3,
    'workout_blocks': [
      {
        'id': 'block',
        'name': 'Fuerza',
        'format': 'straight_sets',
        'rounds': 1,
        'order_index': 0,
        'rest_after_seconds': 60,
        'workout_items': [
          {
            'id': 'item',
            'order_index': 0,
            'exercises': {'id': 'exercise', 'name': 'Sentadilla'},
            'workout_sets': [
              {
                'id': 'set',
                'order_index': 0,
                'target_reps': 8,
                'target_load_kg': 25,
                'rest_after_seconds': 90,
              },
            ],
          },
        ],
      },
    ],
  },
};
