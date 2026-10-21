import 'package:device_activity_core/device_activity_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  test('conserva ausencia, ceros válidos y precisión sin redondear', () {
    const metrics = ActivityMetrics(
      timer: Duration(microseconds: 600123456),
      moving: Duration.zero,
      distanceMeters: 2000.25,
    );
    expect(metrics.issues, isEmpty);
    expect(metrics.elapsed, isNull);
    expect(metrics.averageHeartRateBpm, isNull);
    expect(metrics.moving, Duration.zero);
    expect(metrics.timer!.inMicroseconds, 600123456);
    expect(metrics.distanceMeters, 2000.25);
    final pace = metrics.paceUsing(ActivityTimeBasis.timer)!;
    expect(pace.basis, ActivityTimeBasis.timer);
    expect(pace.secondsPerKm, closeTo(600.123456 / 2.00025, 1e-9));
    expect(metrics.paceUsing(ActivityTimeBasis.elapsed), isNull);
  });

  test('distingue tiempo transcurrido, temporizador y movimiento', () {
    const metrics = ActivityMetrics(
      elapsed: Duration(seconds: 900),
      timer: Duration(seconds: 600),
      moving: Duration(seconds: 540),
      distanceMeters: 2000,
    );
    expect(metrics.paceUsing(ActivityTimeBasis.elapsed)!.secondsPerKm, 450);
    expect(metrics.paceUsing(ActivityTimeBasis.timer)!.secondsPerKm, 300);
    expect(metrics.paceUsing(ActivityTimeBasis.moving)!.secondsPerKm, 270);
    expect(
      const ActivityMetrics(
        timer: Duration(seconds: 5),
        distanceMeters: 0,
      ).paceUsing(ActivityTimeBasis.timer),
      isNull,
    );
    expect(
      const ActivityMetrics(
        timer: Duration.zero,
        distanceMeters: 10,
      ).paceUsing(ActivityTimeBasis.timer),
      isNull,
    );
  });

  for (final value in [
    double.nan,
    double.infinity,
    double.negativeInfinity,
    -1.0,
  ]) {
    test('rechaza distancia y pulso no válidos: $value', () {
      expect(
        ActivityMetrics(distanceMeters: value).issues,
        contains(ActivityIssue.invalidDistance),
      );
      expect(
        ActivityMetrics(averageHeartRateBpm: value).issues,
        contains(ActivityIssue.invalidHeartRate),
      );
      expect(
        ActivityMetrics(maxHeartRateBpm: value).issues,
        contains(ActivityIssue.invalidHeartRate),
      );
    });
  }

  test('rechaza duraciones negativas sin inventar límites fisiológicos', () {
    for (final metrics in [
      const ActivityMetrics(elapsed: Duration(microseconds: -1)),
      const ActivityMetrics(timer: Duration(seconds: -1)),
      const ActivityMetrics(moving: Duration(seconds: -1)),
    ]) {
      expect(metrics.issues, contains(ActivityIssue.negativeDuration));
    }
    expect(const ActivityMetrics(distanceMeters: 0).issues, isEmpty);
    expect(const ActivityMetrics(maxHeartRateBpm: 0).issues, isEmpty);
  });

  test('identifica lo incompleto y lo que no es carrera', () {
    expect(running(sport: null).issues, contains(ActivityIssue.missingSport));
    expect(
      running(sport: ActivitySport.other).issues,
      contains(ActivityIssue.notRunning),
    );
    expect(
      running(missingStart: true).issues,
      contains(ActivityIssue.missingStart),
    );
    expect(
      running(missingEnd: true).issues,
      contains(ActivityIssue.missingEnd),
    );
    expect(
      running(end: instant.subtract(const Duration(seconds: 1))).issues,
      contains(ActivityIssue.invertedInterval),
    );
  });

  test('fecha local conserva medianoche y no usa la zona del proceso', () {
    final run = running(
      start: DateTime.utc(2026, 10, 20, 23, 50),
      end: DateTime.utc(2026, 10, 21, 0, 5),
    );
    expect(run.localStartDate, ActivityLocalDate(2026, 10, 21));
    expect(running(startOffset: null).localStartDate, isNull);
    expect(
      running(
        start: DateTime.utc(2026, 10, 21, 0, 15),
        end: DateTime.utc(2026, 10, 21, 1),
        startOffset: const Duration(hours: -3),
      ).localStartDate,
      ActivityLocalDate(2026, 10, 20),
    );
  });

  test('conserva ambos offsets durante el cambio de horario de otoño', () {
    final run = running(
      start: DateTime.utc(2026, 10, 25, 0, 30),
      end: DateTime.utc(2026, 10, 25, 1, 30),
      startOffset: const Duration(hours: 2),
      endOffset: const Duration(hours: 1),
      metrics: const ActivityMetrics(elapsed: Duration(hours: 1)),
    );
    expect(run.localStartDate, ActivityLocalDate(2026, 10, 25));
    expect(
      run.endedAtUtc!.difference(run.startedAtUtc!),
      const Duration(hours: 1),
    );
    expect(run.endUtcOffset, const Duration(hours: 1));
  });

  test('valida calendario, UTC y offset sin normalización silenciosa', () {
    expect(() => ActivityLocalDate(2026, 2, 29), throwsArgumentError);
    expect(() => ActivityLocalDate(2026, 13, 1), throwsArgumentError);
    expect(ActivityLocalDate(2028, 2, 29).day, 29);
    expect(() => running(start: DateTime(2026, 10, 21)), throwsArgumentError);
    expect(
      running(startOffset: const Duration(hours: 24)).issues,
      contains(ActivityIssue.invalidOffset),
    );
    expect(() => ActivityRevision(' '), throwsArgumentError);
  });

  test(
    'mantiene vueltas automáticas sin convertirlas en series prescritas',
    () {
      final segments = [
        ActivitySegment(
          index: 0,
          startedAtUtc: instant,
          endedAtUtc: instant.add(const Duration(minutes: 5)),
          kind: ActivitySegmentKind.automaticLap,
          metrics: const ActivityMetrics(distanceMeters: 1000),
        ),
      ];
      final run = running(segments: segments);
      segments.clear();
      expect(run.issues, isEmpty);
      expect(run.segments.single.kind, ActivitySegmentKind.automaticLap);
      expect(run.metrics.distanceMeters, 2000);
      expect(() => run.segments.clear(), throwsUnsupportedError);
      expect(running().segments, isEmpty);
    },
  );

  test('rechaza segmentos fuera del intervalo o con índices duplicados', () {
    final first = ActivitySegment(
      index: 0,
      startedAtUtc: instant,
      endedAtUtc: instant.add(const Duration(minutes: 1)),
      kind: ActivitySegmentKind.manualLap,
    );
    expect(
      running(segments: [first, first]).issues,
      contains(ActivityIssue.invalidSegment),
    );
    final outside = ActivitySegment(
      index: 1,
      startedAtUtc: instant.subtract(const Duration(seconds: 1)),
      endedAtUtc: instant,
      kind: ActivitySegmentKind.workoutStep,
    );
    expect(
      running(segments: [outside]).issues,
      contains(ActivityIssue.invalidSegment),
    );
  });

  test('la identidad incluye propietario, canal y ámbito externo', () {
    final identities = {
      identity(),
      identity(),
      identity(owner: 'other'),
      identity(channel: ActivityChannel.appleHealth),
      identity(account: 'other-account'),
    };
    expect(identities.length, 4);
    expect(
      () => running(upstream: identity(owner: 'other')),
      throwsA(hasProblem(ActivityProblem.wrongOwner)),
    );
  });
}
