// Desde la raíz: dart run tools/run_app.dart run --release -d ID_DEL_IPHONE
// También: dart run tools/run_app.dart build apk --debug
import 'dart:convert';
import 'dart:io';

const _identityKeys = {'APP_REVISION', 'APP_BUILD_TIME', 'APP_SOURCE_DIRTY'};

List<String> stampFlutterArguments(
  List<String> arguments, {
  required String revision,
  required DateTime preparedAt,
  required bool modifiedSources,
  required Directory root,
}) {
  if (arguments.isEmpty || !{'run', 'build'}.contains(arguments.first)) {
    throw const FormatException(
      'Usa run o build después de tools/run_app.dart.',
    );
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
    throw const FormatException('La revisión Git no es válida.');
  }
  // No permitir que parámetros posteriores sustituyan la identidad calculada.
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    String? value(String flag) {
      if (argument.startsWith('$flag=')) {
        return argument.substring(flag.length + 1);
      }
      if (argument == flag && index + 1 < arguments.length) {
        return arguments[index + 1];
      }
      return null;
    }

    final define = value('--dart-define');
    if (define != null && _identityKeys.contains(define.split('=').first)) {
      throw const FormatException(
        'La herramienta calcula los datos APP de versión.',
      );
    }
    final file = value('--dart-define-from-file');
    if (file != null) {
      final configFile = File(file);
      final config = jsonDecode(
        (configFile.isAbsolute
                ? configFile
                : File.fromUri(root.uri.resolve(file.replaceAll('\\', '/'))))
            .readAsStringSync(),
      );
      if (config is! Map || config.keys.any(_identityKeys.contains)) {
        throw const FormatException(
          'El archivo de configuración no puede sustituir la identidad APP.',
        );
      }
    }
  }
  return [
    ...arguments,
    '--dart-define=APP_REVISION=$revision',
    '--dart-define=APP_BUILD_TIME=${preparedAt.toUtc().toIso8601String()}',
    '--dart-define=APP_SOURCE_DIRTY=$modifiedSources',
  ];
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.contains('--help')) {
    stdout.writeln(
      'dart run tools/run_app.dart run --release -d ID_DEL_IPHONE --dart-define=APP_ENV=development',
    );
    stdout.writeln('dart run tools/run_app.dart build apk --debug');
    stdout.writeln(
      'Añade --dry-run para comprobar la identidad sin ejecutar Flutter.',
    );
    return;
  }
  final root = File.fromUri(Platform.script).parent.parent;
  Future<String> git(List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: root.path);
    if (result.exitCode != 0) {
      throw const FormatException('No se pudo identificar el código con Git.');
    }
    return (result.stdout as String).trim();
  }

  try {
    final revision = await git(['rev-parse', 'HEAD']);
    final status = await git([
      'status',
      '--porcelain',
      '--',
      'lib',
      'assets',
      'packages',
      'android',
      'ios',
      'web',
      'linux',
      'macos',
      'windows',
      'pubspec.yaml',
      'pubspec.lock',
      'tools/run_app.dart',
    ]);
    final preparedAt = DateTime.now().toUtc();
    final args = stampFlutterArguments(
      arguments.where((arg) => arg != '--dry-run').toList(),
      revision: revision,
      preparedAt: preparedAt,
      modifiedSources: status.isNotEmpty,
      root: root,
    );
    // Solo metadatos propios: no imprimir argumentos que puedan contener secretos.
    stdout.writeln(
      'EntrenaOP · $revision · ${preparedAt.toIso8601String()} · cambios locales: ${status.isNotEmpty}',
    );
    if (arguments.contains('--dry-run')) return;
    var sdkDirectory = File(Platform.resolvedExecutable).parent;
    File? flutter;
    for (var depth = 0; depth < 8; depth++) {
      final candidate = File.fromUri(
        sdkDirectory.uri.resolve(
          Platform.isWindows ? 'flutter.bat' : 'flutter',
        ),
      );
      if (candidate.existsSync()) {
        flutter = candidate;
        break;
      }
      sdkDirectory = sdkDirectory.parent;
    }
    if (flutter == null) {
      throw const FormatException(
        'No se encuentra Flutter junto al SDK Dart actual.',
      );
    }
    final process = await Process.start(
      flutter.path,
      args,
      workingDirectory: root.path,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on FileSystemException {
    stderr.writeln('No se pudo leer la configuración local de compilación.');
    exitCode = 64;
  } on ProcessException {
    stderr.writeln('No se pudo iniciar Git o Flutter desde este SDK.');
    exitCode = 64;
  }
}
