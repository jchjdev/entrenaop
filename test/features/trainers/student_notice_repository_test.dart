import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/trainers/data/supabase_student_notice_repository.dart';
import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const pupil = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';

class NoticeServer {
  String account = pupil;
  final requests = <http.Request>[];
  Completer<void>? hold;
  Completer<void>? started;
  final responses = <String, dynamic>{
    'get_my_trainer_notices': {
      'items': [
        {
          'id': 'notice',
          'kind': 'message',
          'source_revision': 0,
          'created_at': '2026-10-21T10:00:00Z',
          'read_at': null,
          'body': 'Texto privado inesperado',
        },
      ],
      'has_more': true,
      'unread_count': 99,
      'resources': {
        'has_forms': true,
        'has_assessments': false,
        'has_conversations': true,
        'has_technique': true,
        'has_assigned_workouts': true,
        'conversation_relation_id': 'relation',
      },
    },
    'ack_my_trainer_notice': null,
    'resolve_my_trainer_notice': {
      'kind': 'workout',
      'target_id': 'scheduled',
      'scheduled_date': '2026-10-22',
    },
    'list_my_trainer_technique': {
      'items': [
        {
          'execution_id': 'execution',
          'started_at': '2026-10-21T10:00:00Z',
          'session_name': 'Sesión propia',
        },
      ],
      'has_more': false,
    },
  };
  late final client = SupabaseClient(
    'https://notices.example.invalid',
    'fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handle),
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    dynamic result;
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': account, 'exp': 4102444800})))
          .replaceAll('=', '');
      result = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': account,
          'aud': 'authenticated',
          'role': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-21T00:00:00Z',
        },
      };
    } else {
      final name = request.url.pathSegments.last;
      if (!responses.containsKey(name)) {
        throw StateError('RPC inesperada: $name');
      }
      result = responses[name];
      started?.complete();
      await hold?.future;
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Future<void> login() => client.auth.signInWithPassword(
    email: '$account@example.invalid',
    password: 'fixture',
  );
}

void main() {
  late NoticeServer server;
  late SupabaseStudentNoticeRepository repository;
  setUp(() async {
    server = NoticeServer();
    await server.login();
    server.requests.clear();
    repository = SupabaseStudentNoticeRepository(server.client, pupil);
  });
  tearDown(() async => server.client.dispose());

  test('resumen conserva total servidor y no presenta texto privado', () async {
    final result = await repository.snapshot(kind: StudentNoticeKind.message);
    expect(result.unreadCount, 99);
    expect(result.items, hasLength(1));
    expect(result.items.single.title, 'Mensaje de tu preparador');
    expect(result.hasMore, isTrue);
    expect(result.resources.hasContent, isTrue);
    expect(result.resources.conversationRelationId, 'relation');
    final body = jsonDecode(server.requests.single.body) as Map;
    expect(body['p_expected_owner'], pupil);
    expect(body['p_kind'], 'message');
    await repository.snapshot(before: result.items.single);
    final cursor = jsonDecode(server.requests.last.body) as Map;
    expect(cursor['p_before_id'], 'notice');
    expect(
      DateTime.parse(cursor['p_before_at'] as String),
      result.items.single.createdAt,
    );
  });

  test(
    'resolver no acusa lectura y conserva pauta/fecha autorizadas',
    () async {
      final target = (await repository.resolve('notice'))!;
      expect(target.kind, StudentNoticeTargetKind.workout);
      expect(target.targetId, 'scheduled');
      expect(target.scheduledDate, DateTime(2026, 10, 22));
      expect(server.requests, hasLength(1));
      expect(
        server.requests.single.url.path,
        endsWith('/resolve_my_trainer_notice'),
      );
      server.responses['resolve_my_trainer_notice'] = null;
      expect(await repository.resolve('notice'), isNull);
      await repository.ack('notice');
      expect(jsonDecode(server.requests.last.body), {
        'p_expected_owner': pupil,
        'p_notice_id': 'notice',
      });
    },
  );

  test('rechaza destino desconocido o pauta sin fecha', () async {
    server.responses['resolve_my_trainer_notice'] = {
      'kind': 'url',
      'target_id': 'https://foreign.invalid',
    };
    await expectLater(repository.resolve('notice'), throwsFormatException);
    server.responses['resolve_my_trainer_notice'] = {
      'kind': 'workout',
      'target_id': 'scheduled',
    };
    await expectLater(repository.resolve('notice'), throwsFormatException);
  });

  test(
    'índice técnico conserva cursor de ejecución y propietario esperado',
    () async {
      final page = await repository.listTechnique();
      expect(page.hasMore, isFalse);
      expect(page.items.single.executionId, 'execution');
      await repository.listTechnique(before: page.items.single);
      final body = jsonDecode(server.requests.last.body) as Map;
      expect(body['p_expected_owner'], pupil);
      expect(body['p_before_id'], 'execution');
      expect(
        DateTime.parse(body['p_before_at'] as String),
        page.items.single.startedAt,
      );
    },
  );

  test('repositorio retenido de A no envía operaciones con cuenta B', () async {
    server.account = other;
    await server.login();
    server.requests.clear();
    await expectLater(repository.snapshot(), throwsStateError);
    await expectLater(repository.ack('notice'), throwsStateError);
    await expectLater(repository.resolve('notice'), throwsStateError);
    await expectLater(repository.listTechnique(), throwsStateError);
    expect(server.requests, isEmpty);
  });

  for (final writing in [false, true]) {
    test(
      'cambio A/B en vuelo descarta ${writing ? 'acuse' : 'lectura'} tardía',
      () async {
        final token = server.client.auth.currentSession!.accessToken;
        server.hold = Completer<void>();
        server.started = Completer<void>();
        final pending = writing
            ? repository.ack('notice')
            : repository.snapshot();
        final rejected = expectLater(pending, throwsStateError);
        await server.started!.future;
        final request = server.requests.single;
        expect(request.headers['Authorization'], 'Bearer $token');
        server.account = other;
        await server.login();
        server.hold!.complete();
        await rejected;
        expect(jsonDecode(request.body)['p_expected_owner'], pupil);
      },
    );
  }
}
