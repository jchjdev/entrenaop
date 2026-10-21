import 'package:device_activity_core/device_activity_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_read_probe/data/native_running_health.dart';
import 'package:health_read_probe/domain/local_running_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final end = DateTime.utc(2026, 10, 21, 12);
  final window = HealthReadWindow(
    startUtc: end.subtract(const Duration(days: 7)),
    endUtc: end,
  );
  final start = end.subtract(const Duration(hours: 2)).microsecondsSinceEpoch;
  Map<String, Object?> row() => {
    'id': 'fixture-run',
    'kind': 'running',
    'startMicros': start,
    'endMicros': start + 1800000123,
    'timerMicros': 1700000123,
    'distanceMeters': 5000.125,
    'writerApplication': 'com.garmin.connect.fixture',
  };
  Object? response;
  Object? failure;
  MethodCall? lastCall;
  DateTime received = end;
  NativeRunningHealth source([
    LocalHealthPlatform platform = LocalHealthPlatform.appleHealth,
  ]) => NativeRunningHealth(
    platform: platform,
    channel: channel,
    nowUtc: () => received,
  );
  Future<LocalHealthRead> read([
    LocalHealthPlatform platform = LocalHealthPlatform.appleHealth,
  ]) =>
      source(platform)
          .read(window: window, localSessionScope: 'ephemeral-fixture');
  Matcher problem(HealthProbeProblem code) =>
      isA<HealthProbeException>().having((e) => e.problem, 'problem', code);

  setUp(() {
    failure = null;
    lastCall = null;
    received = end;
    response = {
      'runs': [row()],
      'truncated': false,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      lastCall = call;
      if (failure != null) throw failure!;
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('unsupported never invokes native health APIs', () async {
    expect(
      await source(LocalHealthPlatform.unsupported).availability(),
      HealthStoreAvailability.unsupported,
    );
    await expectLater(
      read(LocalHealthPlatform.unsupported),
      throwsA(problem(HealthProbeProblem.unavailable)),
    );
    expect(lastCall, isNull);
  });
  test('availability distinguishes install/update from unsupported', () async {
    for (final item in {
      'available': HealthStoreAvailability.available,
      'unavailable': HealthStoreAvailability.unavailable,
      'updateRequired': HealthStoreAvailability.updateRequired,
    }.entries) {
      response = item.key;
      expect(await source().availability(), item.value);
    }
    response = 'unknown';
    await expectLater(
      source().availability(),
      throwsA(problem(HealthProbeProblem.invalidResponse)),
    );
  });
  test(
    'Apple authorization never claims read permission was granted',
    () async {
      response = 'queryAllowedUnknown';
      expect(
        await source().requestReadAccess(),
        HealthReadConsent.queryAllowedUnknown,
      );
      response = 'granted';
      await expectLater(
        source().requestReadAccess(),
        throwsA(problem(HealthProbeProblem.invalidResponse)),
      );
      response = 'denied';
      expect(
        await source(LocalHealthPlatform.healthConnect).requestReadAccess(),
        HealthReadConsent.denied,
      );
    },
  );
  test(
    'Apple preserves fractional distance, microseconds and missing timezone',
    () async {
      final activity = (await read()).activities.single;
      expect(activity.metrics.distanceMeters, 5000.125);
      expect(
        activity.metrics.elapsed,
        const Duration(microseconds: 1800000123),
      );
      expect(activity.metrics.timer, const Duration(microseconds: 1700000123));
      expect(activity.writerApplication, 'com.garmin.connect.fixture');
      expect(activity.identity.channel, ActivityChannel.appleHealth);
      expect(activity.startUtcOffset, isNull);
      expect(activity.timeZoneId, isNull);
      expect(activity.revision.modifiedAtUtc, isNull);
      expect(lastCall!.arguments, {
        'startMicros': window.startUtc.microsecondsSinceEpoch,
        'endMicros': end.microsecondsSinceEpoch,
      });
    },
  );
  test('source offsets can differ across a DST transition', () async {
    response = {
      'runs': [
        {
          ...row(),
          'startOffsetSeconds': 7200,
          'endOffsetSeconds': 3600,
          'timeZoneId': 'Europe/Madrid',
        },
      ],
      'truncated': false,
    };
    final activity = (await read()).activities.single;
    expect(activity.startUtcOffset, const Duration(hours: 2));
    expect(activity.endUtcOffset, const Duration(hours: 1));
  });
  test(
    'revision excludes receipt time but changes with the source snapshot',
    () async {
      final first = (await read()).activities.single;
      received = end.add(const Duration(minutes: 2));
      final second = (await read()).activities.single;
      expect(first.revision.token, second.revision.token);
      expect(first.receivedAtUtc, isNot(second.receivedAtUtc));
      response = {
        'runs': [
          {...row(), 'distanceMeters': 5010.25},
        ],
        'truncated': false,
      };
      expect(
        (await read()).activities.single.revision.token,
        isNot(first.revision.token),
      );
    },
  );
  test(
    'Android omits unrelated totals and preserves source modification',
    () async {
      response = {
        'runs': [
          {...row(), 'modifiedMicros': start + 2000000000},
        ],
        'truncated': false,
      };
      final activity = (await read(LocalHealthPlatform.healthConnect))
          .activities
          .single;
      expect(activity.identity.channel, ActivityChannel.healthConnect);
      expect(activity.metrics.distanceMeters, isNull);
      expect(activity.metrics.timer, isNull);
      expect(
        activity.revision.modifiedAtUtc!.microsecondsSinceEpoch,
        start + 2000000000,
      );
    },
  );
  test('invalid records and repeated identities are excluded', () async {
    final badRows = [
      {...row(), 'id': ''},
      {...row(), 'startMicros': start.toDouble()},
      {...row(), 'endMicros': start - 1},
      {...row(), 'distanceMeters': double.nan},
      {...row(), 'timerMicros': -1},
      {...row(), 'kind': 'cycling'},
      {...row(), 'startOffsetSeconds': 86400},
      {...row(), 'endMicros': end.microsecondsSinceEpoch + 1},
      {...row(), 'startMicros': window.startUtc.microsecondsSinceEpoch - 1},
    ];
    response = {
      'runs': [row(), ...badRows, row(), null],
      'truncated': true,
    };
    final result = await read();
    expect(result.activities, hasLength(1));
    expect(result.rejectedRecords, badRows.length + 2);
    expect(result.truncated, isTrue);
  });
  test('missing metrics stay missing; zero distance stays zero', () async {
    final withoutMetrics = row()
      ..remove('distanceMeters')
      ..remove('timerMicros');
    response = {
      'runs': [withoutMetrics],
      'truncated': false,
    };
    expect((await read()).activities.single.metrics.distanceMeters, isNull);
    response = {
      'runs': [
        {...row(), 'distanceMeters': 0},
      ],
      'truncated': false,
    };
    expect((await read()).activities.single.metrics.distanceMeters, 0);
  });
  test('empty results are distinct from permission failure', () async {
    response = {'runs': [], 'truncated': false};
    expect((await read()).activities, isEmpty);
    failure = PlatformException(
      code: 'permissionRequired',
      message: 'sensitive fixture',
    );
    await expectLater(
      read(),
      throwsA(problem(HealthProbeProblem.permissionRequired)),
    );
  });
  test('malformed or oversized envelopes fail as a whole', () async {
    for (final envelope in [
      null,
      [],
      {'runs': [], 'truncated': 0},
      {'runs': List.filled(201, row()), 'truncated': true},
    ]) {
      response = envelope;
      await expectLater(
        read(),
        throwsA(problem(HealthProbeProblem.invalidResponse)),
      );
    }
  });
  test('native error payloads never escape in the public exception', () async {
    failure = PlatformException(
      code: 'unknown',
      message: 'private data',
      details: row(),
    );
    try {
      await read();
      fail('Expected failure');
    } catch (error) {
      expect(error, problem(HealthProbeProblem.readFailed));
      expect(error.toString(), isNot(contains('private')));
      expect(error.toString(), isNot(contains('fixture-run')));
    }
  });
  test(
    'UTC window rejects local dates, inverted dates and over seven days',
    () {
      for (final startDate in [
        end,
        end.add(const Duration(seconds: 1)),
        end.subtract(const Duration(days: 8)),
        DateTime(2026, 10, 20),
      ]) {
        expect(
          () => HealthReadWindow(startUtc: startDate, endUtc: end),
          throwsArgumentError,
        );
      }
    },
  );
}
