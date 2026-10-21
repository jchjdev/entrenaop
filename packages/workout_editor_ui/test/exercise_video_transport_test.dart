import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';
import 'package:workout_editor_ui/exercise_video_transport.dart';

void main() {
  test(
    'fallo de red conserva etapa sin revelar mensaje ni destino privado',
    () async {
      final client = MockClient(
        (_) async => throw http.ClientException(
          'firma-privada https://private.invalid/?token=secret',
        ),
      );
      await expectLater(
        ExerciseVideoTransport(transport: client).upload(
          const ExerciseVideoUpload(id: 'asset', headers: {}),
          Uint8List(10),
          'video/mp4',
          (_) {},
          maxBytes: 100,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mensaje seguro',
            allOf(
              contains('INICIO/CONEXION'),
              isNot(contains('privada')),
              isNot(contains('secret')),
            ),
          ),
        ),
      );
    },
  );
  test(
    'rechazo al iniciar explica el estado sin mostrar el cuerpo del proveedor',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('detalle privado del proveedor', 401);
      });
      await expectLater(
        ExerciseVideoTransport(transport: client).upload(
          const ExerciseVideoUpload(id: 'asset', headers: {}),
          Uint8List(10),
          'video/mp4',
          (_) {},
          maxBytes: 100,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'error seguro',
            allOf(contains('HTTP 401'), isNot(contains('detalle privado'))),
          ),
        ),
      );
      expect(requests, 1);
    },
  );

  test(
    'TUS envía título técnico y MIME antes de transferir todos los fragmentos',
    () async {
      const id = '20000000-0000-4000-8000-000000000001';
      final bytes = Uint8List(1024 * 1024 + 17);
      var offset = 0, creations = 0, patches = 0;
      final progress = <double>[];
      final client = MockClient((request) async {
        expect(request.followRedirects, isFalse);
        expect(request.url.host, 'video.bunnycdn.com');
        if (request.method == 'POST') {
          creations++;
          final metadata = <String, String>{
            for (final part in request.headers['upload-metadata']!.split(','))
              part.split(' ').first: utf8.decode(
                base64Decode(part.split(' ').last),
              ),
          };
          expect(metadata, {'filetype': 'video/mp4', 'title': 'EntrenaOP $id'});
          expect(request.headers['upload-length'], '${bytes.length}');
          return http.Response(
            '',
            201,
            headers: {'location': '/tusupload/asset'},
          );
        }
        expect(request.method, 'PATCH');
        expect(request.headers['upload-offset'], '$offset');
        expect(
          request.headers['content-type'],
          'application/offset+octet-stream',
        );
        offset += request.bodyBytes.length;
        patches++;
        return http.Response('', 204, headers: {'upload-offset': '$offset'});
      });
      await ExerciseVideoTransport(transport: client).upload(
        const ExerciseVideoUpload(id: id, headers: {'Tus-Resumable': '1.0.0'}),
        bytes,
        'video/mp4',
        progress.add,
        maxBytes: 100 * 1024 * 1024,
      );
      expect(creations, 1);
      expect(patches, 3);
      expect(offset, bytes.length);
      expect(progress.last, 1);
    },
  );
}
