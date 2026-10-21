import 'package:entrenaop/features/exercises/data/services/exercise_video_playback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference = Uri.parse('https://fixture.b-cdn.net/asset/play_720p.mp4');
  Map<String, dynamic> response({
    String? scope,
    int bytes = 1000,
    int? limit,
  }) => {
    'url': '$reference?token=fixture&expires=4102444800',
    'cache_key': 'asset',
    'bytes': bytes,
    'scope': ?scope,
    'playback_limit': ?limit,
  };
  test('respuestas oficiales previas conservan cota de cinco MiB', () {
    expect(
      ExerciseVideoAuthorization.fromResponse(reference, response()).limitBytes,
      5 * 1024 * 1024,
    );
    expect(
      () => ExerciseVideoAuthorization.fromResponse(
        reference,
        response(bytes: 6 * 1024 * 1024),
      ),
      throwsFormatException,
    );
    expect(
      () => ExerciseVideoAuthorization.fromResponse(
        reference,
        response(scope: 'official', limit: 50 * 1024 * 1024),
      ),
      throwsFormatException,
    );
  });
  test('solo scopes privados conocidos admiten cota autorizada de hasta cincuenta MiB', () {
    for (final scope in ['trainer_exercise', 'client_technique']) {
      final data = response(
        scope: scope,
        bytes: 6 * 1024 * 1024,
        limit: 50 * 1024 * 1024,
      );
      expect(
        ExerciseVideoAuthorization.fromResponse(reference, data).limitBytes,
        50 * 1024 * 1024,
      );
      expect(
        () => ExerciseVideoAuthorization.fromResponse(
          reference,
          response(scope: scope),
        ),
        throwsFormatException,
      );
      expect(
        () => ExerciseVideoAuthorization.fromResponse(
          reference,
          response(scope: scope, limit: 51 * 1024 * 1024),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => ExerciseVideoAuthorization.fromResponse(
        reference,
        response(scope: 'admin', limit: 50 * 1024 * 1024),
      ),
      throwsFormatException,
    );
  });
  test('la firma no autoriza otro destino ni bytes fuera de la cota', () {
    final valid = response(scope: 'trainer_exercise', limit: 50 * 1024 * 1024);
    for (final changes in [
      {'url': 'https://evil.invalid/asset/play_720p.mp4?token=fixture'},
      {'url': 'https://fixture.b-cdn.net/other/play_720p.mp4?token=fixture'},
      {
        'url':
            'https://user@fixture.b-cdn.net/asset/play_720p.mp4?token=fixture',
      },
      {
        'url':
            'https://fixture.b-cdn.net:444/asset/play_720p.mp4?token=fixture',
      },
      {'bytes': 50 * 1024 * 1024 + 1},
      {'bytes': 0},
      {'cache_key': ''},
    ]) {
      expect(
        () => ExerciseVideoAuthorization.fromResponse(reference, {
          ...valid,
          ...changes,
        }),
        throwsFormatException,
      );
    }
  });
}
