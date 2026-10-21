import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

const userA = '10000000-0000-4000-8000-000000000001';
const userB = '10000000-0000-4000-8000-000000000002';
const payload = {
  'p_operation_id': 'stable-operation',
  'p_content': 'Contenido de A',
};

class RpcFixture {
  final requests = <http.Request>[];
  Future<http.Response> Function(http.Request)? respond;
  late final client = SupabaseClient(
    'https://rpc-fixture.example.invalid',
    'public-fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      if (respond != null) return respond!(request);
      return json(request, {'saved': true});
    }),
  );

  String token(String user, {String suffix = 'fixture', bool expired = false}) {
    final claims = base64Url
        .encode(
          utf8.encode(
            jsonEncode({'sub': user, 'exp': expired ? 1 : 4102444800}),
          ),
        )
        .replaceAll('=', '');
    return 'eyJhbGciOiJIUzI1NiJ9.$claims.$suffix';
  }

  Map<String, dynamic> sessionData(
    String user, {
    bool anonymous = false,
    String? accessToken,
    String? refreshToken = 'fixture-refresh',
  }) => {
    'access_token': accessToken ?? token(user),
    'refresh_token': refreshToken,
    'token_type': 'bearer',
    'user': {
      'id': user,
      'aud': 'authenticated',
      'role': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-10-21T00:00:00Z',
      'is_anonymous': anonymous,
    },
  };
  Future<void> session(
    String user, {
    bool anonymous = false,
    String? accessToken,
    String? refreshToken = 'fixture-refresh',
  }) => client.auth.setInitialSession(
    jsonEncode(
      sessionData(
        user,
        anonymous: anonymous,
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
    ),
  );

  http.Response json(http.Request request, Object? body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
}

void main() {
  late RpcFixture fixture;
  setUp(() {
    fixture = RpcFixture();
  });
  tearDown(() async {
    await fixture.client.dispose();
  });

  test(
    'renueva sesión expirada del mismo usuario antes de fijar token',
    () async {
      await fixture.session(
        userA,
        accessToken: fixture.token(userA, expired: true),
      );
      fixture.respond = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return fixture.json(
            request,
            fixture.sessionData(
              userA,
              accessToken: fixture.token(userA, suffix: 'fresh'),
            ),
          );
        }
        return fixture.json(request, {'saved': true});
      };
      expect(
        await authenticatedTrainerRpc(
          fixture.client,
          userA,
          'save_private',
          params: payload,
        ),
        {'saved': true},
      );
      final rpc = fixture.requests
          .where((r) => r.url.path.contains('/rpc/'))
          .single;
      expect(
        rpc.headers['authorization'],
        'Bearer ${fixture.token(userA, suffix: 'fresh')}',
      );
      expect(
        fixture.requests.where((r) => r.url.path == '/auth/v1/token'),
        hasLength(1),
      );
    },
  );

  for (final refreshAccepted in [false, true]) {
    test(
      'cambio a B durante renovación de A bloquea RPC · refreshAccepted=$refreshAccepted',
      () async {
        await fixture.session(
          userA,
          accessToken: fixture.token(userA, expired: true),
        );
        fixture.respond = (request) async {
          expect(request.url.path, '/auth/v1/token');
          await fixture.session(userB);
          if (!refreshAccepted) {
            return fixture.json(request, {
              'code': 'refresh_token_already_used',
              'msg': 'Refresh token already used',
            }, 400);
          }
          return fixture.json(
            request,
            fixture.sessionData(
              userA,
              accessToken: fixture.token(userA, suffix: 'fresh'),
            ),
          );
        };
        await expectLater(
          authenticatedTrainerRpc(
            fixture.client,
            userA,
            'save_private',
            params: payload,
          ),
          throwsStateError,
        );
        expect(
          fixture.requests.where((r) => r.url.path.contains('/rpc/')),
          isEmpty,
        );
        expect(fixture.client.auth.currentUser!.id, userB);
      },
    );
  }

  test('sesión expirada sin renovación no manda RPC', () async {
    await fixture.session(
      userA,
      accessToken: fixture.token(userA, expired: true),
      refreshToken: null,
    );
    await expectLater(
      authenticatedTrainerRpc(
        fixture.client,
        userA,
        'save_private',
        params: payload,
      ),
      throwsStateError,
    );
    expect(fixture.requests, isEmpty);
  });

  test('variantes Authorization heredadas se fijan por petición sin mutar globales', () async {
    await fixture.session(userA);
    final old = 'Bearer ${fixture.token(userB)}';
    fixture.client.rest.headers['authorization'] = old;
    fixture.client.rest.headers['Authorization'] = old;
    fixture.client.rest.headers['AUTHORIZATION'] = old;
    final headers = Map<String, String>.from(fixture.client.rest.headers);
    await authenticatedTrainerRpc(
      fixture.client,
      userA,
      'save_private',
      params: payload,
    );
    expect(
      fixture.requests.single.headers['authorization'],
      'Bearer ${fixture.token(userA)}',
    );
    expect(fixture.client.rest.headers, headers);
  });

  test('sesión normal fija Authorization y conserva el payload', () async {
    await fixture.session(userA);
    expect(
      await authenticatedTrainerRpc(
        fixture.client,
        userA,
        'save_private',
        params: payload,
      ),
      {'saved': true},
    );
    final request = fixture.requests.single;
    expect(request.method, 'POST');
    expect(request.headers['authorization'], 'Bearer ${fixture.token(userA)}');
    expect(jsonDecode(request.body), payload);
  });

  test(
    'control del SDK reproduce cambio de token sin cabecera fijada',
    () async {
      await fixture.session(
        userA,
        accessToken: fixture.token(userA, expired: true),
      );
      fixture.respond = (request) async {
        if (request.url.path == '/auth/v1/token') {
          await fixture.session(userB);
          return fixture.json(request, {
            'code': 'refresh_token_already_used',
            'msg': 'Refresh token already used',
          }, 400);
        }
        return fixture.json(request, {'saved': true});
      };
      Future<dynamic> unpinned() async =>
          await fixture.client.rpc('save_private', params: payload);
      final pending = unpinned();
      await pending;
      // La renovación asíncrona termina con otra cuenta ya válida. Sin fijar
      // token ni comprobar de nuevo, el transporte manda el payload con B.
      final rpc = fixture.requests
          .where((r) => r.url.path.contains('/rpc/'))
          .single;
      expect(rpc.headers['authorization'], 'Bearer ${fixture.token(userB)}');
      expect(jsonDecode(rpc.body), payload);
    },
  );

  test(
    'sin sesión, usuario distinto, anónimo o token vacío no envía RPC',
    () async {
      await expectLater(
        authenticatedTrainerRpc(fixture.client, userA, 'save_private'),
        throwsStateError,
      );
      await fixture.session(userB);
      await expectLater(
        authenticatedTrainerRpc(fixture.client, userA, 'save_private'),
        throwsStateError,
      );
      await fixture.session(userA, anonymous: true);
      await expectLater(
        authenticatedTrainerRpc(fixture.client, userA, 'save_private'),
        throwsStateError,
      );
      await fixture.session(userA, accessToken: '');
      await expectLater(
        authenticatedTrainerRpc(fixture.client, userA, 'save_private'),
        throwsStateError,
      );
      expect(fixture.requests, isEmpty);
    },
  );

  test(
    'cambio de cuenta en ventana async nunca envía contenido A con token B',
    () async {
      await fixture.session(userA);
      final pending = authenticatedTrainerRpc(
        fixture.client,
        userA,
        'save_private',
        params: payload,
      );
      final error = expectLater(pending, throwsStateError);
      await fixture.session(userB);
      await error;
      expect(fixture.requests, hasLength(1));
      expect(
        fixture.requests.single.headers['authorization'],
        'Bearer ${fixture.token(userA)}',
      );
      expect(jsonDecode(fixture.requests.single.body), payload);
    },
  );

  test(
    'cambio tras envío rechaza resultado aunque servidor confirmó A',
    () async {
      await fixture.session(userA);
      final sent = Completer<void>(), committed = Completer<void>();
      fixture.respond = (request) async {
        sent.complete();
        await committed.future;
        return fixture.json(request, {'saved': true});
      };
      final pending = authenticatedTrainerRpc(
        fixture.client,
        userA,
        'save_private',
        params: payload,
      );
      final error = expectLater(pending, throwsStateError);
      await sent.future;
      await fixture.session(userB);
      committed.complete();
      await error;
      expect(
        fixture.requests.single.headers['authorization'],
        'Bearer ${fixture.token(userA)}',
      );
    },
  );

  test(
    'fallo HTTP con cambio de cuenta también rechaza identidad y no reenvía',
    () async {
      await fixture.session(userA);
      fixture.respond = (request) async {
        await fixture.session(userB);
        return fixture.json(request, {
          'code': '42501',
          'message': 'Rechazado',
        }, 403);
      };
      await expectLater(
        authenticatedTrainerRpc(
          fixture.client,
          userA,
          'save_private',
          params: payload,
        ),
        throwsStateError,
      );
      await expectLater(
        authenticatedTrainerRpc(
          fixture.client,
          userA,
          'save_private',
          params: payload,
        ),
        throwsStateError,
      );
      expect(fixture.requests, hasLength(1));
      expect(
        fixture.requests.single.headers['authorization'],
        'Bearer ${fixture.token(userA)}',
      );
    },
  );

  test('fallo con misma cuenta conserva excepción y nuevo intento usa token actual A', () async {
    await fixture.session(userA);
    fixture.respond = (request) async =>
        fixture.json(request, {'code': '42501', 'message': 'Rechazado'}, 403);
    await expectLater(
      authenticatedTrainerRpc(
        fixture.client,
        userA,
        'save_private',
        params: payload,
      ),
      throwsA(isA<PostgrestException>()),
    );
    await fixture.session(
      userA,
      accessToken: fixture.token(userA, suffix: 'renovado'),
    );
    fixture.respond = null;
    expect(
      await authenticatedTrainerRpc(
        fixture.client,
        userA,
        'save_private',
        params: payload,
      ),
      {'saved': true},
    );
    expect(fixture.requests, hasLength(2));
    expect(
      fixture.requests.last.headers['authorization'],
      'Bearer ${fixture.token(userA, suffix: 'renovado')}',
    );
    expect(jsonDecode(fixture.requests.last.body), payload);
  });
}
