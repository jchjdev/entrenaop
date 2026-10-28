import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/coach_workspace/data/supabase_coach_workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';

class CoachServer {
  String account = owner;
  final requests = <http.Request>[];
  final responses = <String, Object?>{};
  Completer<void>? hold, started;
  late final client = SupabaseClient(
    'https://coach.example.invalid',
    'fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      Object? response;
      if (request.url.path == '/auth/v1/token') {
        final claims = base64Url
            .encode(
              utf8.encode(jsonEncode({'sub': account, 'exp': 4102444800})),
            )
            .replaceAll('=', '');
        response = {
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.fixture',
          'refresh_token': 'fixture',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': account,
            'aud': 'authenticated',
            'role': 'authenticated',
            'app_metadata': {},
            'user_metadata': {'role': 'admin', 'pro': true},
            'created_at': '2026-10-28T00:00:00Z',
          },
        };
      } else {
        final name = request.url.pathSegments.last;
        if (!responses.containsKey(name)) {
          throw StateError('RPC inesperada: $name');
        }
        response = responses[name];
        if (started?.isCompleted == false) {
          started!.complete();
        }
        await hold?.future;
      }
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  Future<void> login() => client.auth
      .signInWithPassword(email: 'persona@example.invalid', password: 'fixture')
      .then((_) {});
  Map<String, dynamic> get payload =>
      jsonDecode(requests.last.body) as Map<String, dynamic>;
}

void main() {
  test('el estado profesional procede del servidor, nunca del Pro o metadata editable', () async {
    final api = CoachServer();
    addTearDown(api.client.dispose);
    api.responses['get_my_trainer_account_status'] = {
      'professional_account': true,
      'enabled': false,
    };
    await api.login();
    final repo = SupabaseCoachWorkspaceRepository(api.client, owner);
    expect((await repo.account()).enabled, false);
    expect(api.payload['p_expected_owner'], owner);
  });
  test(
    'agenda conserva fechas locales y cursor completo con propietario fijado',
    () async {
      final api = CoachServer();
      addTearDown(api.client.dispose);
      api.responses['list_trainer_agenda_filtered'] = [
        {
          'id': 'session',
          'template_name': 'Series',
          'scheduled_date': '2026-10-25',
          'created_at': '2026-10-20T10:00:00Z',
          'client_id': other,
          'client_name': 'Isabel',
          'status': 'planned',
        },
      ];
      await api.login();
      final repo = SupabaseCoachWorkspaceRepository(api.client, owner);
      final rows = await repo.agenda(
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 31),
      );
      expect(rows.single.name, 'Series');
      expect(api.payload['p_from'], '2026-10-25');
      expect(api.payload['p_to'], '2026-10-31');
      expect(api.payload['p_expected_owner'], owner);
      expect(api.payload['p_visibility'], 'current');
      await repo.agenda(
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 31),
        after: rows.single,
      );
      expect(api.payload['p_after_date'], '2026-10-25');
      expect(api.payload['p_after_id'], 'session');
    },
  );
  test(
    'la bandeja de vídeos pagina por fecha e identidad sin pedir reproducción',
    () async {
      final api = CoachServer();
      addTearDown(api.client.dispose);
      api.responses['list_trainer_technique_inbox'] = [
        {
          'id': 'clip',
          'assignment_id': 'session',
          'client_name': 'Isabel',
          'template_name': 'Fuerza',
          'created_at': '2026-10-28T10:00:00Z',
        },
      ];
      await api.login();
      final repo = SupabaseCoachWorkspaceRepository(api.client, owner);
      final rows = await repo.pendingTechnique();
      expect(rows.single.assignmentId, 'session');
      await repo.pendingTechnique(before: rows.single);
      expect(api.payload['p_before_id'], 'clip');
      expect(api.payload['p_before_at'], '2026-10-28T10:00:00.000Z');
      expect(
        api.requests.where((r) => r.url.path.contains('functions')),
        isEmpty,
      );
    },
  );
  test('una lectura tardía de otra cuenta no entrega datos privados y fija el token de origen', () async {
    final api = CoachServer();
    addTearDown(api.client.dispose);
    api.responses['get_my_trainer_account_status'] = {'enabled': true};
    await api.login();
    final token = api.client.auth.currentSession!.accessToken;
    final repo = SupabaseCoachWorkspaceRepository(api.client, owner);
    api.started = Completer<void>();
    api.hold = Completer<void>();
    final request = repo.account();
    final expectation = expectLater(request, throwsStateError);
    await api.started!.future;
    final rpc = api.requests.last;
    api.account = other;
    await api.login();
    api.hold!.complete();
    await expectation;
    expect(
      rpc.headers['Authorization'] ?? rpc.headers['authorization'],
      'Bearer $token',
    );
  });
  test(
    'sin identidad válida no se consultan alumnos, resultados ni vídeos',
    () async {
      final api = CoachServer();
      addTearDown(api.client.dispose);
      final repo = SupabaseCoachWorkspaceRepository(api.client, owner);
      await expectLater(repo.account(), throwsStateError);
      await expectLater(repo.clients(), throwsStateError);
      await expectLater(repo.client(other), throwsStateError);
      await expectLater(repo.result('session'), throwsStateError);
      await expectLater(repo.technique('session'), throwsStateError);
      await expectLater(repo.pendingTechnique(), throwsStateError);
      expect(api.requests, isEmpty);
    },
  );
  test(
    'revisión y corrección conservan operación, revisión e instante del envío',
    () async {
      final api = CoachServer();
      addTearDown(api.client.dispose);
      api.responses['mark_trainer_assignment_reviewed'] = null;
      api.responses['add_trainer_video_feedback'] = 'operation';
      await api.login();
      final repo = SupabaseCoachWorkspaceRepository(api.client, owner);
      await repo.review('operation', 'session', 3, 'Revisar progresión');
      expect(api.payload, {
        'p_operation_id': 'operation',
        'p_id': 'session',
        'p_seen_revision': 3,
        'p_private_note': 'Revisar progresión',
      });
      await repo.feedback('operation', 'clip', 12.5, 'Controla la bajada');
      expect(api.payload, {
        'p_operation_id': 'operation',
        'p_id': 'clip',
        'p_second': 12.5,
        'p_body': 'Controla la bajada',
      });
    },
  );
}
