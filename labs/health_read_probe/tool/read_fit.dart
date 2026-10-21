import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_activity_core/device_activity_core.dart';
import 'package:health_read_probe/data/fit_running_activity_reader.dart';

Future<void> main(List<String> arguments) async {
  const providers = {
    'garmin': ActivityChannel.garmin,
    'coros': ActivityChannel.coros,
    'suunto': ActivityChannel.suunto,
  };
  if (arguments.length == 1 && arguments.first == '--help') {
    stdout.writeln(
      'dart run tool/read_fit.dart garmin|coros|suunto archivo.fit [--show-metrics]',
    );
    return;
  }
  if ((arguments.length != 2 && arguments.length != 3) ||
      !providers.containsKey(arguments.first) ||
      (arguments.length == 3 && arguments[2] != '--show-metrics')) {
    stderr.writeln(
      'Uso: dart run tool/read_fit.dart garmin|coros|suunto archivo.fit [--show-metrics]',
    );
    exitCode = 64;
    return;
  }
  try {
    final file = File(arguments[1]);
    if (await file.length() > FitRunningActivityReader.maxBytes) {
      throw const FitReadException(FitReadProblem.tooLarge);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > FitRunningActivityReader.maxBytes) {
        throw const FitReadException(FitReadProblem.tooLarge);
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    final activity = FitRunningActivityReader().read(
      bytes,
      // Identidad solo de laboratorio, sin cuenta autenticada ni persistencia.
      identity: ActivityIdentity(
        ownerId: 'offline-probe',
        channel: providers[arguments.first]!,
        accountScope: 'unverified-local-file',
        externalId: sha256.convert(bytes).toString(),
      ),
      receivedAtUtc: DateTime.now().toUtc(),
    );
    final showMetrics = arguments.length == 3;
    stderr.writeln(
      'Ensayo local: proveedor declarado, sin conexión ni autenticación. No se guarda ni confirma ningún resultado.',
    );
    stdout.writeln(
      jsonEncode({
        'mode': 'offline-fit-probe',
        'providerVerified': false,
        'runningActivities': 1,
        'laps': activity.segments.length,
        if (showMetrics)
          'metrics': {
            'startedAtUtc': activity.startedAtUtc!.toIso8601String(),
            'endedAtUtc': activity.endedAtUtc!.toIso8601String(),
            'elapsedMicroseconds': activity.metrics.elapsed?.inMicroseconds,
            'timerMicroseconds': activity.metrics.timer?.inMicroseconds,
            'distanceMeters': activity.metrics.distanceMeters,
            'averageHeartRateBpm': activity.metrics.averageHeartRateBpm,
            'maxHeartRateBpm': activity.metrics.maxHeartRateBpm,
          },
      }),
    );
  } on FitReadException catch (error) {
    stderr.writeln('FIT rechazado: ${error.problem.name}');
    exitCode = 65;
  } on FileSystemException {
    stderr.writeln('No se pudo leer el archivo local indicado.');
    exitCode = 66;
  }
}
