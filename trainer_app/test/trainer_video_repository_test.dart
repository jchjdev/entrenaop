import 'dart:convert';
import 'dart:typed_data';

import 'package:entrenaop_trainer/trainer_video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';
import 'package:workout_editor_ui/exercise_video_transport.dart';

import 'trainer_exercise_repository_test.dart' show ServerFixture, owner;

const asset = '20000000-0000-4000-8000-000000000001';
const video = '30000000-0000-4000-8000-000000000001';
const reference = 'https://fixture.b-cdn.net/$video/play_720p.mp4';

class VideoFixture extends ServerFixture {
  final videoCalls = <Map<String, dynamic>>[];
  bool failCreate = false;
  bool badThumbnail = false;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path.endsWith('/exercise-video')) {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      videoCalls.add(body);
      expect(body['expected_user_id'], owner);
      switch (body['action']) {
        case 'create':
          if (failCreate) {
            return super.json(request, {
              'error': 'video_creation_uncertain',
              'asset_id': asset,
            }, 503);
          }
          return super.json(request, {
            'id': asset,
            'video_id': video,
            'library_id': '42',
            'signature': List.filled(64, 'a').join(),
            'expiration': 4102444800,
            'scope': 'trainer_exercise',
            'source_limit': 100 * 1024 * 1024,
            'duration_limit': 180,
            'playback_limit': 50 * 1024 * 1024,
          });
        case 'status':
          return super.json(request, {
            'status': 'ready',
            'url': reference,
            'scope': 'trainer_exercise',
          });
        case 'playback':
          return super.json(request, {'url': '$reference?token=fixture'});
        case 'thumbnail':
          return super.json(request, {
            'url': badThumbnail
                ? 'https://evil.invalid/thumbnail.jpg'
                : 'https://fixture.b-cdn.net/$video/thumbnail.jpg?token=fixture',
          });
      }
    }
    return super.handle(request);
  }
}

void main() {
  late VideoFixture fixture;
  setUp(() async {
    fixture = VideoFixture();
    await fixture.client.auth.signInWithPassword(
      email: 'trainer@example.invalid',
      password: 'fixture',
    );
  });
  tearDown(() async => fixture.client.dispose());

  test(
    'reserva privada conserva operación tras error incierto y no pide ADMIN',
    () async {
      final repository = SupabaseTrainerVideoRepository(fixture.client, owner);
      fixture.failCreate = true;
      await expectLater(
        repository.create(1024),
        throwsA(isA<FunctionException>()),
      );
      fixture.failCreate = false;
      final upload = await repository.create(1024);
      expect(upload.id, asset);
      expect(
        fixture.videoCalls[0]['operation_id'],
        fixture.videoCalls[1]['operation_id'],
      );
      expect(
        fixture.videoCalls.every((p) => p['scope'] == 'trainer_exercise'),
        isTrue,
      );
      await repository.create(1024);
      expect(
        fixture.videoCalls.last['operation_id'],
        isNot(fixture.videoCalls.first['operation_id']),
      );
    },
  );
  test(
    'tras incertidumbre no cambia los datos del intento pendiente',
    () async {
      final repository = SupabaseTrainerVideoRepository(fixture.client, owner);
      fixture.failCreate = true;
      await expectLater(
        repository.create(1024),
        throwsA(isA<FunctionException>()),
      );
      await expectLater(repository.create(2048), throwsStateError);
      expect(fixture.videoCalls, hasLength(1));
    },
  );
  test('no transmite si la identidad o el archivo no coinciden', () async {
    final wrong = SupabaseTrainerVideoRepository(fixture.client, video);
    await expectLater(wrong.create(1024), throwsStateError);
    expect(fixture.videoCalls, isEmpty);
    final repository = SupabaseTrainerVideoRepository(fixture.client, owner);
    final upload = await repository.create(1024);
    await expectLater(
      repository.upload(upload, Uint8List(10), 'video/mp4', (_) {}),
      throwsFormatException,
    );
  });
  test(
    'transporte rechaza redirección TUS externa sin enviar fragmentos',
    () async {
      final requests = <http.Request>[];
      final transport = ExerciseVideoTransport(
        transport: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '',
            201,
            headers: {'location': 'https://evil.invalid/tusupload/asset'},
          );
        }),
      );
      final repository = SupabaseTrainerVideoRepository(
        fixture.client,
        owner,
        transport: transport,
      );
      final upload = await repository.create(10);
      await expectLater(
        repository.upload(upload, Uint8List(10), 'video/mp4', (_) {}),
        throwsStateError,
      );
      expect(requests, hasLength(1));
      expect(requests.single.followRedirects, isFalse);
      expect(requests.single.url.host, 'video.bunnycdn.com');
    },
  );
  test(
    'TUS recupera offset aceptado sin repetir fragmento tras perder respuesta',
    () async {
      var patches = 0;
      var heads = 0;
      final transport = ExerciseVideoTransport(
        transport: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              '',
              201,
              headers: {'location': '/tusupload/asset'},
            );
          }
          if (request.method == 'PATCH') {
            patches++;
            throw http.ClientException('Respuesta perdida después de aceptar');
          }
          heads++;
          return http.Response('', 200, headers: {'upload-offset': '10'});
        }),
      );
      final repository = SupabaseTrainerVideoRepository(
        fixture.client,
        owner,
        transport: transport,
      );
      final upload = await repository.create(10);
      await repository.upload(upload, Uint8List(10), 'video/mp4', (_) {});
      expect(patches, 1);
      expect(heads, 1);
    },
  );
  test('status y reproducción conservan recurso; portada externa nunca se descarga', () async {
    var downloads = 0;
    final transport = ExerciseVideoTransport(
      transport: MockClient((_) async {
        downloads++;
        return http.Response('', 200);
      }),
    );
    final repository = SupabaseTrainerVideoRepository(
      fixture.client,
      owner,
      transport: transport,
    );
    expect((await repository.status(asset)).status, 'ready');
    expect(
      (await repository.playback(reference)).path,
      '/$video/play_720p.mp4',
    );
    fixture.badThumbnail = true;
    await expectLater(repository.thumbnail(reference), throwsFormatException);
    expect(downloads, 0);
  });
  test('transporte comprueba cuenta antes de enviar un fragmento', () async {
    var identities = 0;
    var requests = 0;
    final transport = ExerciseVideoTransport(
      transport: MockClient((request) async {
        requests++;
        return http.Response(
          '',
          201,
          headers: {'location': '/tusupload/asset'},
        );
      }),
    );
    await expectLater(
      transport.upload(
        const ExerciseVideoUpload(id: asset, headers: {}),
        Uint8List(10),
        'video/mp4',
        (_) {},
        maxBytes: 100,
        checkIdentity: () {
          if (++identities >= 2) throw StateError('Cuenta cambiada');
        },
      ),
      throwsStateError,
    );
    expect(requests, 1);
  });
}
