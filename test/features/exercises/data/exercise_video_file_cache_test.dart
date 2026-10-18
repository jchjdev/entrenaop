import 'dart:io';
import 'dart:typed_data';

import 'package:entrenaop/features/exercises/data/services/exercise_video_file_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory directory;
  final bytes = Uint8List.fromList([
    0,
    0,
    0,
    24,
    102,
    116,
    121,
    112,
    105,
    115,
    111,
    109,
  ]);
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'entrenaop-video-test-',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));
  test(
    'cambiar firma no descarga de nuevo; cuenta o versión diferente sí',
    () async {
      var downloads = 0;
      final cache = ExerciseVideoFileCache(
        directory,
        transport: MockClient((_) async {
          downloads++;
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'video/mp4'},
          );
        }),
      );
      final first = await cache.get(
        Uri.parse('https://fixture.b-cdn.net/clip.mp4?token=one'),
        'dev|user1|asset1',
      );
      final same = await cache.get(
        Uri.parse('https://fixture.b-cdn.net/clip.mp4?token=two'),
        'dev|user1|asset1',
      );
      expect(same.path, first.path);
      expect(downloads, 1);
      await cache.get(
        Uri.parse('https://fixture.b-cdn.net/clip.mp4'),
        'dev|user2|asset1',
      );
      await cache.get(
        Uri.parse('https://fixture.b-cdn.net/clip2.mp4'),
        'dev|user1|asset2',
      );
      expect(downloads, 3);
    },
  );
  test(
    'descarta respuestas inválidas sin guardar archivos parciales',
    () async {
      final cache = ExerciseVideoFileCache(
        directory,
        transport: MockClient(
          (_) async => http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'text/html'},
          ),
        ),
      );
      await expectLater(
        cache.get(Uri.parse('https://fixture.b-cdn.net/clip.mp4'), 'bad'),
        throwsFormatException,
      );
      expect(await directory.list().toList(), isEmpty);
    },
  );
  test('rechaza destinos externos antes de enviar la firma', () async {
    var requests = 0;
    final cache = ExerciseVideoFileCache(
      directory,
      transport: MockClient((_) async {
        requests++;
        return http.Response('', 200);
      }),
    );
    await expectLater(
      cache.get(Uri.parse('https://evil.invalid/clip.mp4'), 'bad'),
      throwsFormatException,
    );
    expect(requests, 0);
  });
  test('mantiene el límite de veinte clips y elimina caché caducada', () async {
    final cache = ExerciseVideoFileCache(
      directory,
      transport: MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'video/mp4'},
        ),
      ),
    );
    final uri = Uri.parse('https://fixture.b-cdn.net/clip.mp4');
    for (var i = 0; i < 22; i++) {
      await cache.get(uri, 'asset$i');
    }
    expect(
      (await directory.list().toList()).length,
      ExerciseVideoFileCache.maxFiles,
    );
    final stale = (await directory.list().toList()).first as File;
    await stale.setLastModified(
      DateTime.now().subtract(const Duration(days: 16)),
    );
    await cache.get(uri, 'new');
    expect(await stale.exists(), isFalse);
    expect((await directory.list().toList()).length, lessThanOrEqualTo(20));
  });
}
