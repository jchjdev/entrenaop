import 'dart:convert';

import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource_impl.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '10000000-0000-4000-8000-000000000001';

void main() {
  test(
    'una cuenta admin ve públicos y propios sin pedir fotos ajenas',
    () async {
      final requests = <http.Request>[];
      final client = _client(requests);
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'admin@example.invalid',
        password: 'fixture',
      );

      final exercises =
          await ExerciseRemoteDataSourceImpl(supabaseClient: client)
              .getExercises()
              .catchError(
                (error) =>
                    fail(error is ServerException ? error.message : '$error'),
              );

      expect(exercises.map((e) => e.id), ['official', 'own']);
      expect(exercises.last.createdBy, _owner);
      expect(
        requests.last.url.queryParameters['or'],
        contains('and(origin.eq.user,created_by.eq.$_owner)'),
      );
      expect(
        requests.where((r) => r.url.path.startsWith('/storage/')),
        isEmpty,
      );
    },
  );

  test('sin sesión consulta únicamente el catálogo público', () async {
    final requests = <http.Request>[];
    final client = _client(requests);
    addTearDown(client.dispose);

    final exercises = await ExerciseRemoteDataSourceImpl(supabaseClient: client)
        .getExercises()
        .catchError(
          (error) => fail(error is ServerException ? error.message : '$error'),
        );

    expect(exercises.map((e) => e.id), ['official']);
    expect(requests.where((r) => r.url.path.startsWith('/storage/')), isEmpty);
  });

  test(
    'un ejercicio pautado usa origen profesional y firma su imagen privada',
    () async {
      final requests = <http.Request>[];
      final client = _client(requests);
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'admin@example.invalid',
        password: 'fixture',
      );
      final exercise =
          await ExerciseRemoteDataSourceImpl(supabaseClient: client)
              .getExerciseById('coach')
              .catchError(
                (error) =>
                    fail(error is ServerException ? error.message : '$error'),
              );
      expect(exercise?.origin, ExerciseOrigin.coach);
      expect(
        exercise?.thumbnailUrl,
        contains('/storage/v1/object/sign/trainer-exercise-images/'),
      );
      expect(
        requests.where((r) => r.url.path.contains('exercise-images-private')),
        isEmpty,
      );
    },
  );
}

SupabaseClient _client(List<http.Request> requests) => SupabaseClient(
  'https://catalog-fixture.example.com',
  'fixture-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    requests.add(request);
    final headers = {'content-type': 'application/json'};
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      return http.Response(
        jsonEncode({
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
          'refresh_token': 'fixture-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': _owner,
            'aud': 'authenticated',
            'role': 'authenticated',
            'app_metadata': {'role': 'admin'},
            'user_metadata': {},
            'created_at': '2026-10-18T00:00:00Z',
          },
        }),
        200,
        headers: headers,
        request: request,
      );
    }
    if (request.url.path == '/rest/v1/exercises') {
      if (request.url.queryParameters['id'] == 'eq.coach') {
        return http.Response(
          jsonEncode(
            _exercise('coach', owner: 'trainer')
              ..['origin'] = 'coach'
              ..['image_path'] = 'trainer/image.jpg',
          ),
          200,
          headers: headers,
          request: request,
        );
      }
      final rows = [
        _exercise('official', public: true),
        _exercise('own', owner: _owner),
        _exercise('own-professional', owner: _owner)..['origin'] = 'coach',
        _exercise('foreign', owner: 'another-user')
          ..['image_path'] = 'another-user/foreign/photo.jpg',
      ];
      // Simula la lectura administrativa amplia y los filtros de PostgREST.
      final filter = request.url.queryParameters;
      final scoped = filter['or']?.contains('created_by.eq.$_owner') == true;
      final publicOnly = filter['is_public'] == 'eq.true';
      return http.Response(
        jsonEncode(
          rows
              .where(
                (row) => publicOnly
                    ? row['is_public'] == true
                    : !scoped ||
                          row['is_public'] == true ||
                          (row['created_by'] == _owner &&
                              row['origin'] == 'user'),
              )
              .toList(),
        ),
        200,
        headers: headers,
        request: request,
      );
    }
    if (request.url.path.startsWith('/storage/')) {
      if (request.url.path.contains('trainer-exercise-images')) {
        return http.Response(
          jsonEncode({
            'signedURL': '/object/sign/trainer-exercise-images/trainer/image.jpg?token=fixture',
          }),
          200,
          headers: headers,
          request: request,
        );
      }
      return http.Response(
        jsonEncode({
          'statusCode': '404',
          'error': 'not_found',
          'message': 'Object not found',
        }),
        404,
        headers: headers,
        request: request,
      );
    }
    throw StateError('Petición inesperada: ${request.url.path}');
  }),
);

Map<String, Object?> _exercise(
  String id, {
  bool public = false,
  String? owner,
}) => {
  'id': id,
  'name': id,
  'muscle_groups': ['pecho'],
  'equipment': ['peso corporal'],
  'difficulty': 'inicial',
  'exercise_type': 'repeticiones',
  'is_public': public,
  'origin': public ? 'system' : 'user',
  'created_by': owner,
};
