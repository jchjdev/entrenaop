import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/run_app.dart';

void main() {
  final revision = 'a' * 40;
  final root = Directory.current;
  final preparedAt = DateTime.utc(2026, 10, 22, 8, 30);
  List<String> stamp(List<String> args) => stampFlutterArguments(
    args,
    revision: revision,
    preparedAt: preparedAt,
    modifiedSources: true,
    root: root,
  );

  test('conserva destino y build nativo y estampa identidad inmutable', () {
    final args = stamp([
      'run',
      '--release',
      '-d',
      'device',
      '--build-number=42',
      '--dart-define=APP_ENV=development',
    ]);
    expect(args, contains('--build-number=42'));
    expect(args, contains('--dart-define=APP_REVISION=$revision'));
    expect(
      args,
      contains('--dart-define=APP_BUILD_TIME=2026-10-22T08:30:00.000Z'),
    );
    expect(args, contains('--dart-define=APP_SOURCE_DIRTY=true'));
  });

  test('rechaza sobrescribir identidad por parámetro junto o separado', () {
    expect(
      () => stamp(['build', 'apk', '--dart-define=APP_REVISION=other']),
      throwsFormatException,
    );
    expect(
      () => stamp(['run', '--dart-define', 'APP_SOURCE_DIRTY=false']),
      throwsFormatException,
    );
  });

  test(
    'rechaza sobrescribir identidad mediante archivo sin revelar su contenido',
    () {
      final directory = Directory.systemTemp.createTempSync(
        'entrenaop-identity-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final config = File('${directory.path}/config.json')
        ..writeAsStringSync('{"APP_BUILD_TIME":"fake","SECRET":"test-only"}');
      expect(
        () => stamp(['run', '--dart-define-from-file=${config.path}']),
        throwsFormatException,
      );
    },
  );

  test('no ejecuta comandos distintos de run/build', () {
    expect(() => stamp(['clean']), throwsFormatException);
    expect(() => stamp([]), throwsFormatException);
  });
}
