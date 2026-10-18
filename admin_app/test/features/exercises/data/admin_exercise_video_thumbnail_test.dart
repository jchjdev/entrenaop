import 'dart:convert';
import 'dart:typed_data';

import 'package:entrenaop_admin/features/exercises/data/admin_exercise_video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '10000000-0000-4000-8000-000000000001';
const _reference = 'https://fixture.b-cdn.net/video/play_360p.mp4';

void main() {
  for (final scenario in ['valid', 'other-host', 'html', 'too-large']) {
    test('miniatura: $scenario', () async {
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            final payload = base64Url
                .encode(
                  utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})),
                )
                .replaceAll('=', '');
            return http.Response(
              jsonEncode({
                'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
                'refresh_token': 'fixture',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': _owner,
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-10-18T00:00:00Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          expect(request.url.path, '/functions/v1/exercise-video');
          expect(jsonDecode(request.body)['action'], 'thumbnail');
          return http.Response(
            jsonEncode({
              'url': scenario == 'other-host'
                  ? 'https://evil.invalid/video/thumbnail.jpg'
                  : 'https://fixture.b-cdn.net/video/thumbnail.jpg?token=fixture',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'fixture',
      );
      var downloads = 0;
      final transport = MockClient((request) async {
        downloads++;
        expect(request.followRedirects, false);
        expect(request.url.host, 'fixture.b-cdn.net');
        return http.Response.bytes(
          scenario == 'too-large'
              ? Uint8List(2 * 1024 * 1024 + 1)
              : [255, 216, 255, 217],
          200,
          headers: {
            'content-type': scenario == 'html' ? 'text/html' : 'image/jpeg',
          },
        );
      });
      final repository = SupabaseAdminExerciseVideoRepository(
        client,
        transport: transport,
      );
      if (scenario == 'valid') {
        expect(await repository.thumbnail(_reference), [255, 216, 255, 217]);
      } else {
        await expectLater(
          repository.thumbnail(_reference),
          throwsFormatException,
        );
      }
      expect(downloads, scenario == 'other-host' ? 0 : 1);
    });
  }
}
