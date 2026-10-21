import 'package:device_activity_core/device_activity_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

FindActivityDuplicates policy({
  ActivityTimeBasis basis = ActivityTimeBasis.timer,
}) => FindActivityDuplicates(
  policyVersion: 'test-policy-1',
  startTolerance: const Duration(seconds: 10),
  durationTolerance: const Duration(seconds: 5),
  distanceToleranceMeters: 20,
  timeBasis: basis,
);

void main() {
  test('Garmin y su copia de Salud generan candidato, nunca una fusión', () {
    final garmin = running();
    final health = running(
      key: identity(channel: ActivityChannel.appleHealth),
      upstream: garmin.identity,
    );
    final candidate = policy().compare(garmin, health)!;
    expect(candidate.evidence, DuplicateEvidence.sharedOrigin);
    expect(candidate.policyVersion, 'test-policy-1');
    expect(candidate.left, garmin.identity);
    expect(candidate.right, health.identity);
    expect(garmin.identity.channel, ActivityChannel.garmin);
    expect(health.identity.channel, ActivityChannel.appleHealth);
  });

  test('parecidos sin origen común siguen siendo una coincidencia ambigua', () {
    final first = running();
    final second = running(
      key: identity(id: 'another-run'),
      start: instant.add(const Duration(seconds: 5)),
    );
    final match = policy().compare(first, second)!;
    expect(match.evidence, DuplicateEvidence.similarMeasurement);
    expect(first.identity, isNot(second.identity));
  });

  test('no compara cuentas distintas ni confunde identidad con copia', () {
    expect(
      policy().compare(running(), running(key: identity(owner: 'other'))),
      isNull,
    );
    expect(policy().compare(running(), running()), isNull);
    expect(
      policy().compare(
        running(),
        running(missingEnd: true, key: identity(id: 'other')),
      ),
      isNull,
    );
  });

  test('sin datos comparables o fuera de tolerancia no propone duplicados', () {
    final original = running();
    for (final other in [
      running(
        key: identity(id: 'other'),
        metrics: const ActivityMetrics(distanceMeters: 2000),
      ),
      running(
        key: identity(id: 'other'),
        metrics: const ActivityMetrics(timer: Duration(seconds: 600)),
      ),
      running(
        key: identity(id: 'other'),
        metrics: const ActivityMetrics(
          timer: Duration(seconds: 700),
          distanceMeters: 2000,
        ),
      ),
      running(
        key: identity(id: 'other'),
        metrics: const ActivityMetrics(
          timer: Duration(seconds: 600),
          distanceMeters: 2050,
        ),
      ),
      running(
        key: identity(id: 'other'),
        start: instant.subtract(const Duration(minutes: 1)),
      ),
    ]) {
      expect(policy().compare(original, other), isNull);
    }
  });

  test('no sustituye tiempo en movimiento por temporizador al comparar', () {
    final elapsedOnly = running(
      key: identity(id: 'other'),
      metrics: const ActivityMetrics(
        elapsed: Duration(seconds: 600),
        distanceMeters: 2000,
      ),
    );
    expect(policy().compare(running(), elapsedOnly), isNull);
    expect(
      () => FindActivityDuplicates(
        policyVersion: 'test-policy-1',
        startTolerance: Duration.zero,
        durationTolerance: Duration.zero,
        distanceToleranceMeters: double.nan,
        timeBasis: ActivityTimeBasis.elapsed,
      ),
      throwsArgumentError,
    );
  });
}
