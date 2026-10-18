import 'dart:typed_data';

import 'package:entrenaop_admin/features/exercises/data/admin_exercise_video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const upload = AdminVideoUpload(
    id: 'fixture',
    headers: {
      'AuthorizationSignature': 'fixture-signature',
      'VideoId': 'fixture-video',
      'LibraryId': '42',
      'AuthorizationExpire': '1800000000',
      'Tus-Resumable': '1.0.0',
    },
  );
  test('recupera offset tras perder la respuesta sin duplicar el fragmento recibido', () async {
    final supabase = SupabaseClient('https://fixture.invalid', 'fixture-key');
    addTearDown(supabase.dispose);
    var patches = 0;
    var heads = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.followRedirects, false);
        return http.Response(
          '',
          201,
          headers: {'location': '/tusupload/fixture'},
        );
      }
      if (request.method == 'PATCH') {
        patches++;
        expect(request.headers['Upload-Offset'], '0');
        throw http.ClientException(
          'Respuesta perdida después de recibir los bytes',
        );
      }
      heads++;
      return http.Response('', 200, headers: {'upload-offset': '3'});
    });
    final repository = SupabaseAdminExerciseVideoRepository(
      supabase,
      transport: client,
    );
    await repository.upload(
      upload,
      Uint8List.fromList([1, 2, 3]),
      'video/mp4',
      (_) {},
    );
    expect(patches, 1);
    expect(heads, 1);
  });
  test(
    'rechaza una redirección a otro host sin enviarle credenciales de subida',
    () async {
      final supabase = SupabaseClient('https://fixture.invalid', 'fixture-key');
      addTearDown(supabase.dispose);
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response(
          '',
          201,
          headers: {'location': 'https://evil.invalid/tusupload/fixture'},
        );
      });
      final repository = SupabaseAdminExerciseVideoRepository(
        supabase,
        transport: client,
      );
      await expectLater(
        repository.upload(upload, Uint8List.fromList([1]), 'video/mp4', (_) {}),
        throwsStateError,
      );
      expect(requests, 1);
    },
  );
}
