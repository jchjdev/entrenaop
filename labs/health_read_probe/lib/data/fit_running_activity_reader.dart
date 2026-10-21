import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_activity_core/device_activity_core.dart';
import 'package:fit_tool/fit_tool.dart' as fit;

enum FitReadProblem {
  invalidFile,
  unsupportedEncoding,
  tooLarge,
  tooManyRecords,
  notActivity,
  notRunning,
  multipleSessions,
  incompleteData,
}

final class FitReadException implements Exception {
  const FitReadException(this.problem);
  final FitReadProblem problem;

  @override
  String toString() => 'FitReadException(${problem.name})';
}

/// Adaptador experimental: el archivo no autentica su proveedor ni propietario.
final class FitRunningActivityReader {
  static const maxBytes = 1024 * 1024;
  static const maxRecords = 10000;
  static const maxLaps = 500;

  ExternalActivity read(
    Uint8List bytes, {
    required ActivityIdentity identity,
    required DateTime receivedAtUtc,
  }) {
    if (!receivedAtUtc.isUtc) throw ArgumentError('La recepción debe ser UTC');
    _checkEnvelope(bytes);
    try {
      // El códec puede diagnosticar filas. No salen a consola ni a telemetría.
      return runZoned(
        () => _decode(bytes, identity, receivedAtUtc),
        zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
      );
    } on FitReadException {
      rethrow;
    } catch (_) {
      // No propagamos excepciones del códec con contenido del archivo.
      throw const FitReadException(FitReadProblem.invalidFile);
    }
  }

  ExternalActivity _decode(
    Uint8List bytes,
    ActivityIdentity identity,
    DateTime received,
  ) {
    final file = fit.FitFile.fromBytes(bytes, checkCrc: true);
    final encoded = file.toBytes(checkCrc: true);
    if (encoded.length != bytes.length ||
        Iterable<int>.generate(bytes.length)
            .any((i) => encoded[i] != bytes[i])) {
      throw const FitReadException(FitReadProblem.unsupportedEncoding);
    }
    final messages = file.records
        .where((record) => !record.isDefinition)
        .map((record) => record.message)
        .toList();
    final ids = messages.whereType<fit.FileIdMessage>().toList();
    if (ids.length != 1 || ids.single.type != fit.FileType.activity) {
      throw const FitReadException(FitReadProblem.notActivity);
    }
    final sessions = messages.whereType<fit.SessionMessage>().toList();
    if (sessions.length > 1 ||
        messages.whereType<fit.ActivityMessage>().any(
          (message) => message.numSessions != null && message.numSessions != 1,
        )) {
      throw const FitReadException(FitReadProblem.multipleSessions);
    }
    if (sessions.isEmpty) {
      throw const FitReadException(FitReadProblem.incompleteData);
    }
    final session = sessions.single;
    if (session.sport == null) {
      throw const FitReadException(FitReadProblem.incompleteData);
    }
    if (session.sport != fit.Sport.running) {
      throw const FitReadException(FitReadProblem.notRunning);
    }
    final start = _date(session.startTime);
    final end = _date(session.timestamp);
    final laps = messages.whereType<fit.LapMessage>().toList();
    if (laps.length > maxLaps) {
      throw const FitReadException(FitReadProblem.tooManyRecords);
    }
    final activity = ExternalActivity(
      identity: identity,
      // La huella detecta cambios; la fecha del archivo no ordena revisiones.
      revision: ActivityRevision('fit-probe-v1:${sha256.convert(bytes)}'),
      receivedAtUtc: received,
      sport: ActivitySport.running,
      startedAtUtc: start,
      endedAtUtc: end,
      deviceBrand: _brand(ids.single.manufacturer),
      metrics: ActivityMetrics(
        elapsed: _duration(session.totalElapsedTime),
        timer: _duration(session.totalTimerTime),
        distanceMeters: session.totalDistance,
        averageHeartRateBpm: session.avgHeartRate?.toDouble(),
        maxHeartRateBpm: session.maxHeartRate?.toDouble(),
      ),
      segments: [
        for (var i = 0; i < laps.length; i++)
          ActivitySegment(
            index: i,
            startedAtUtc: _date(laps[i].startTime),
            endedAtUtc: _date(laps[i].timestamp),
            kind: switch (laps[i].lapTrigger) {
              fit.LapTrigger.manual => ActivitySegmentKind.manualLap,
              fit.LapTrigger.time ||
              fit.LapTrigger.distance => ActivitySegmentKind.automaticLap,
              _ => ActivitySegmentKind.unknown,
            },
            metrics: ActivityMetrics(
              elapsed: _duration(laps[i].totalElapsedTime),
              timer: _duration(laps[i].totalTimerTime),
              distanceMeters: laps[i].totalDistance,
            ),
          ),
      ],
    );
    if (activity.issues.isNotEmpty ||
        laps.any(
          (lap) => lap.sport != null && lap.sport != fit.Sport.running,
        )) {
      throw const FitReadException(FitReadProblem.incompleteData);
    }
    return activity;
  }
}

DateTime _date(int? milliseconds) {
  if (milliseconds == null) {
    throw const FitReadException(FitReadProblem.incompleteData);
  }
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

Duration? _duration(double? seconds) {
  if (seconds == null) return null;
  if (!seconds.isFinite || seconds < 0) {
    throw const FitReadException(FitReadProblem.incompleteData);
  }
  return Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
}

String? _brand(int? manufacturer) {
  if (manufacturer == fit.Manufacturer.garmin.value) return 'Garmin';
  if (manufacturer == fit.Manufacturer.coros.value ||
      manufacturer == fit.Manufacturer.corosByte.value) {
    return 'COROS';
  }
  if (manufacturer == fit.Manufacturer.suunto.value) return 'Suunto';
  return null;
}

/// Recorrido estructural acotado antes de que el códec reserve sus mensajes.
void _checkEnvelope(Uint8List bytes) {
  if (bytes.length > FitRunningActivityReader.maxBytes) {
    throw const FitReadException(FitReadProblem.tooLarge);
  }
  if (bytes.length < 14) {
    throw const FitReadException(FitReadProblem.invalidFile);
  }
  final headerSize = bytes[0];
  if ((headerSize != 12 && headerSize != 14) ||
      bytes[8] != 0x2e ||
      bytes[9] != 0x46 ||
      bytes[10] != 0x49 ||
      bytes[11] != 0x54) {
    throw const FitReadException(FitReadProblem.invalidFile);
  }
  if (bytes[1] >> 4 != 1 && bytes[1] >> 4 != 2) {
    throw const FitReadException(FitReadProblem.unsupportedEncoding);
  }
  final data = ByteData.sublistView(bytes);
  final end = headerSize + data.getUint32(4, Endian.little);
  if (end + 2 != bytes.length || end < headerSize) {
    throw const FitReadException(FitReadProblem.invalidFile);
  }
  if (headerSize == 14 &&
      data.getUint16(12, Endian.little) != 0 &&
      fit.crc16(Uint8List.sublistView(bytes, 0, 12)) !=
          data.getUint16(12, Endian.little)) {
    throw const FitReadException(FitReadProblem.invalidFile);
  }
  if (fit.crc16(Uint8List.sublistView(bytes, 0, end)) !=
      data.getUint16(end, Endian.little)) {
    throw const FitReadException(FitReadProblem.invalidFile);
  }
  var position = headerSize;
  var records = 0;
  var laps = 0;
  final sizes = <int, int>{};
  final globals = <int, int>{};
  while (position < end) {
    if (++records > FitRunningActivityReader.maxRecords) {
      throw const FitReadException(FitReadProblem.tooManyRecords);
    }
    final header = bytes[position++];
    if (header & 0x80 != 0 || header & 0x20 != 0) {
      // Este primer ensayo no presume soporte de timestamps comprimidos/campos developer.
      throw const FitReadException(FitReadProblem.unsupportedEncoding);
    }
    if (header & 0x10 != 0) {
      throw const FitReadException(FitReadProblem.invalidFile);
    }
    final localId = header & 0x0f;
    if (header & 0x40 != 0) {
      if (position + 5 > end ||
          bytes[position] != 0 ||
          bytes[position + 1] > 1) {
        throw const FitReadException(FitReadProblem.invalidFile);
      }
      final count = bytes[position + 4];
      if (position + 5 + count * 3 > end) {
        throw const FitReadException(FitReadProblem.invalidFile);
      }
      final fields = <int>{};
      var size = 0;
      for (var i = 0; i < count; i++) {
        final field = position + 5 + i * 3;
        if (!fields.add(bytes[field]) || bytes[field + 1] == 0) {
          throw const FitReadException(FitReadProblem.invalidFile);
        }
        size += bytes[field + 1];
      }
      sizes[localId] = size;
      globals[localId] = data.getUint16(
        position + 2,
        bytes[position + 1] == 0 ? Endian.little : Endian.big,
      );
      position += 5 + count * 3;
    } else {
      final size = sizes[localId];
      if (size == null || position + size > end) {
        throw const FitReadException(FitReadProblem.invalidFile);
      }
      if (globals[localId] == 19 && ++laps > FitRunningActivityReader.maxLaps) {
        throw const FitReadException(FitReadProblem.tooManyRecords);
      }
      position += size;
    }
  }
}
