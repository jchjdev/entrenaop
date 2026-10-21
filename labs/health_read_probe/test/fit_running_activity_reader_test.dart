import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_activity_core/device_activity_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_read_probe/data/fit_running_activity_reader.dart';

import 'fixtures/synthetic_running_fit.dart';

void main() {
  final reader = FitRunningActivityReader();
  final identity = ActivityIdentity(
    ownerId: 'fixture-owner',
    channel: ActivityChannel.coros,
    accountScope: 'fixture-account',
    externalId: 'fixture-external',
  );
  final received = DateTime.utc(2026, 10, 21);
  ExternalActivity read(Uint8List bytes) =>
      reader.read(bytes, identity: identity, receivedAtUtc: received);
  Matcher code(FitReadProblem problem) =>
      isA<FitReadException>().having((e) => e.problem, 'problem', problem);

  test('independent CRC uses the published CRC-16/ARC check vector', () {
    expect(syntheticCrc(ascii.encode('123456789')), 0xbb3d);
  });
  for (final endian in [Endian.little, Endian.big]) {
    test(
      'synthetic binary keeps original timing and fractional units: $endian',
      () {
        final activity = read(syntheticRunningFit(endian: endian));
        expect(activity.identity, identity);
        expect(
          activity.startedAtUtc,
          DateTime.utc(1989, 12, 31).add(const Duration(seconds: 1000000000)),
        );
        expect(activity.metrics.elapsed, const Duration(milliseconds: 1800123));
        expect(activity.metrics.timer, const Duration(milliseconds: 1700456));
        expect(activity.metrics.distanceMeters, 5000.12);
        expect(activity.metrics.averageHeartRateBpm, 143);
        expect(activity.metrics.maxHeartRateBpm, 181);
        expect(activity.startUtcOffset, isNull);
        expect(activity.endUtcOffset, isNull);
        expect(activity.writerApplication, isNull);
        expect(activity.revision.modifiedAtUtc, isNull);
        expect(activity.segments.single.kind, ActivitySegmentKind.automaticLap);
        expect(activity.segments.single.metrics.distanceMeters, 1000.01);
      },
    );
  }
  test('file metadata never replaces trusted acquisition identity', () {
    for (final entry in {1: 'Garmin', 23: 'Suunto', 294: 'COROS'}.entries) {
      final activity = read(syntheticRunningFit(manufacturer: entry.key));
      expect(activity.deviceBrand, entry.value);
      expect(activity.identity, identity);
      expect(activity.upstreamIdentity, isNull);
    }
    expect(read(syntheticRunningFit(manufacturer: 65000)).deviceBrand, isNull);
  });
  test('14-byte header with CRC validates', () {
    expect(read(syntheticRunningFit(headerCrc: true)).issues, isEmpty);
  });
  test('missing metrics remain missing and zero remains zero', () {
    final activity = read(syntheticRunningFit(metrics: false, lap: false));
    expect(activity.metrics.distanceMeters, isNull);
    expect(activity.metrics.elapsed, isNull);
    expect(activity.metrics.timer, isNull);
    expect(read(syntheticRunningFit(distanceRaw: 0)).metrics.distanceMeters, 0);
    expect(
      read(syntheticRunningFit(distanceRaw: 0xffffffff)).metrics.distanceMeters,
      isNull,
    );
  });
  test(
    'automatic, manual and unspecified laps are never prescribed workout steps',
    () {
      expect(
        read(syntheticRunningFit(lapTrigger: 0)).segments.single.kind,
        ActivitySegmentKind.manualLap,
      );
      expect(
        read(syntheticRunningFit(lapTrigger: 7)).segments.single.kind,
        ActivitySegmentKind.unknown,
      );
    },
  );
  test('snapshot fingerprint is stable independently of receipt time', () {
    final bytes = syntheticRunningFit();
    final first = read(bytes);
    final next = reader.read(
      bytes,
      identity: identity,
      receivedAtUtc: received.add(const Duration(hours: 1)),
    );
    expect(first.revision, next.revision);
    expect(first.receivedAtUtc, isNot(next.receivedAtUtc));
    expect(
      read(syntheticRunningFit(distanceRaw: 510012)).revision,
      isNot(first.revision),
    );
  });
  test('multiple sessions are not silently reduced to the first run', () {
    expect(
      () => read(syntheticRunningFit(sessions: 2)),
      throwsA(code(FitReadProblem.multipleSessions)),
    );
    expect(
      () => read(syntheticRunningFit(sessions: 0)),
      throwsA(code(FitReadProblem.incompleteData)),
    );
    expect(
      () => read(syntheticRunningFit(sport: 2)),
      throwsA(code(FitReadProblem.notRunning)),
    );
  });
  test('lap outside the session is rejected', () {
    expect(
      () => read(syntheticRunningFit(lapEnd: 1000009999)),
      throwsA(code(FitReadProblem.incompleteData)),
    );
  });
  test(
    'truncation, concatenation, trailing bytes and CRC corruption are rejected',
    () {
      final bytes = syntheticRunningFit();
      final corrupt = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 1;
      for (final input in [
        Uint8List(0),
        Uint8List.sublistView(bytes, 0, bytes.length - 1),
        Uint8List.fromList([...bytes, 0]),
        Uint8List.fromList([...bytes, ...bytes]),
        corrupt,
      ]) {
        expect(() => read(input), throwsA(code(FitReadProblem.invalidFile)));
      }
    },
  );
  test('bad header CRC is rejected even if whole-file CRC is recomputed', () {
    final input = syntheticRunningFit(headerCrc: true)..[12] ^= 1;
    final crc = syntheticCrc(input.sublist(0, input.length - 2));
    input[input.length - 2] = crc & 255;
    input[input.length - 1] = crc >> 8;
    expect(() => read(input), throwsA(code(FitReadProblem.invalidFile)));
  });
  test(
    'byte and record bounds are enforced before allocating decoded messages',
    () {
      expect(
        () => read(Uint8List(FitRunningActivityReader.maxBytes + 1)),
        throwsA(code(FitReadProblem.tooLarge)),
      );
      final many = wrapSyntheticFit([
        0x40,
        0,
        0,
        0,
        0,
        0,
        ...List.filled(FitRunningActivityReader.maxRecords, 0),
      ]);
      expect(() => read(many), throwsA(code(FitReadProblem.tooManyRecords)));
    },
  );
  test('unsupported compressed/developer encodings are explicit', () {
    for (final header in [0x80, 0x60]) {
      expect(
        () => read(wrapSyntheticFit([header])),
        throwsA(code(FitReadProblem.unsupportedEncoding)),
      );
    }
  });

  test('lap limit is enforced by the structural pass', () {
    expect(
      () => read(
        syntheticRunningFit(lapCount: FitRunningActivityReader.maxLaps + 1),
      ),
      throwsA(code(FitReadProblem.tooManyRecords)),
    );
  });
  test('missing definitions, invalid architecture and partial definitions fail closed', () {
    for (final data in [
      [3],
      [0x40],
      [0x40, 0, 2, 0, 0, 0],
      [0x40, 0, 0, 0, 0, 1],
    ]) {
      expect(
        () => read(wrapSyntheticFit(data)),
        throwsA(code(FitReadProblem.invalidFile)),
      );
    }
  });
  test(
    'decoder failures do not escape as console messages or raw payloads',
    () {
      final output = <String>[];
      runZoned(
        () {
          try {
            read(wrapSyntheticFit([0x40, 0, 0, 0, 0, 1, 0, 1, 0xff, 0, 4]));
            fail('Expected a coded failure');
          } on FitReadException catch (error) {
            expect(error.toString(), startsWith('FitReadException('));
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => output.add(line),
        ),
      );
      expect(output, isEmpty);
    },
  );
  test('deterministic malformed inputs always return a coded failure', () {
    final random = Random(71);
    for (var i = 0; i < 200; i++) {
      final data = Uint8List.fromList(
        List.generate(random.nextInt(200), (_) => random.nextInt(256)),
      );
      expect(() => read(data), throwsA(isA<FitReadException>()));
    }
  });
}
