import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/guided_programs/data/supabase_guided_program_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/guided_program_codec.dart';

import '../../support/guided_program_fixture.dart';

void main() {
  late HttpServer server;
  late _Client client;
  late SupabaseGuidedProgramRepository repository;
  final requests = <Uri>[];
  Completer<void>? gate;
  Completer<void>? arrived;
  bool showCover = false;
  bool abandonedDetail = false;
  setUp(() async {
    requests.clear();
    gate = null;
    arrived = null;
    showCover = false;
    abandonedDetail = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      if (arrived != null && !arrived!.isCompleted) arrived!.complete();
      await gate?.future;
      request.response.headers.contentType = ContentType.json;
      if (abandonedDetail &&
          !request.uri.path.endsWith('/guided_program_covers')) {
        final Object response;
        if (request.uri.path.endsWith('/guided_programs')) {
          response = {
            'id': 'program',
            'family_id': 'family',
            'version': 1,
            'status': 'published',
            'content': guidedProgramToJson(guidedFixture),
          };
        } else if (request.uri.path.endsWith('/guided_program_follows')) {
          response = [
            {
              'id': 'follow',
              'phase_index': 0,
              'completed_at': null,
              'abandoned_at': '2026-10-18T00:00:00Z',
            },
          ];
        } else {
          response = [
            {
              'phase_index': 0,
              'session_index': 0,
              'execution_id': 'execution',
              'workout_executions': {'status': 'completed'},
            },
          ];
        }
        request.response.write(jsonEncode(response));
        await request.response.close();
        return;
      }
      request.response.write(
        jsonEncode(
          request.uri.path.endsWith('/guided_program_covers')
              ? (showCover
                    ? [
                        {
                          'program_id': 'family',
                          'card_image_path': 'guided/family/card.jpg',
                          'header_image_path': 'guided/family/header.jpg',
                          'focal_x': 0.8,
                          'focal_y': 0.2,
                          'header_focal_x': 0.3,
                          'header_focal_y': 0.7,
                        },
                      ]
                    : [])
              : [
                  {
                    'phase_index': 0,
                    'guided_programs': {
                      'id': 'program',
                      'family_id': 'family',
                      'version': 1,
                      'status': 'published',
                      'content': guidedProgramToJson(guidedFixture),
                    },
                  },
                ],
        ),
      );
      await request.response.close();
    });
    client = _Client('http://127.0.0.1:${server.port}');
    repository = SupabaseGuidedProgramRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  test(
    'Inicio consulta los tres últimos seguimientos activos del propietario',
    () async {
      final result = await repository.startedPrograms();
      final params = requests
          .where((r) => r.path.endsWith('/guided_program_follows'))
          .single
          .queryParameters;
      expect(params['user_id'], 'eq.owner');
      expect(params['completed_at'], 'is.null');
      expect(params['abandoned_at'], 'is.null');
      expect(params['limit'], '3');
      expect(params['order'], 'started_at.desc.nullslast,id.desc.nullslast');
      expect(params['select'], 'phase_index,guided_programs!inner(*)');
      expect(result.single.program.id, 'program');
      expect(result.single.program.name, 'Hipertrofia básica');
      expect(result.single.phaseIndex, 0);
    },
  );
  test('resuelve una portada por familia aunque la versión tenga otro identificador', () async {
    showCover = true;
    final result = await repository.startedPrograms();
    expect(
      result.single.program.cover!.cardUrl,
      contains('/program-covers-public/guided/family/card.jpg'),
    );
    expect(result.single.program.cover!.focalX, 0.8);
    expect(result.single.program.cover!.headerFocalY, 0.7);
    final coverQuery = requests
        .where((r) => r.path.endsWith('/guided_program_covers'))
        .single;
    expect(coverQuery.queryParameters['program_id'], 'in.("family")');
  });
  test(
    'la ficha interpreta abandono y conserva las referencias a resultados',
    () async {
      abandonedDetail = true;
      final detail = await repository.detail('program');
      expect(detail.follow!.abandoned, isTrue);
      expect(detail.follow!.completed, isFalse);
      expect(detail.follow!.active, isFalse);
      expect(detail.runs.single.executionId, 'execution');
      expect(detail.runs.single.status, 'completed');
    },
  );
  test(
    'sin sesión no consulta; cambiar de cuenta descarta una respuesta anterior',
    () async {
      client.testAuth.user = null;
      expect(await repository.startedPrograms(), isEmpty);
      expect(requests, isEmpty);
      client.testAuth.user = _owner();
      gate = Completer<void>();
      arrived = Completer<void>();
      final pending = repository.startedPrograms();
      await arrived!.future;
      client.testAuth.user = _owner('another');
      gate!.complete();
      expect(await pending, isEmpty);
    },
  );
}

class _Client extends SupabaseClient {
  _Client(String url)
    : super(
        url,
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
  final testAuth = _Auth();
  @override
  GoTrueClient get auth => testAuth;
}

class _Auth extends GoTrueClient {
  _Auth() : super(autoRefreshToken: false);
  User? user = _owner();
  @override
  User? get currentUser => user;
}

User _owner([String id = 'owner']) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-18T00:00:00Z',
);
