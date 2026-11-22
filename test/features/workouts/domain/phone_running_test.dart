import 'package:entrenaop/features/workouts/domain/services/phone_running.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 22, 9);

  PhoneRunFix fix(int seconds, double longitude, {double accuracy = 5}) =>
      PhoneRunFix(
        latitude: 0,
        longitude: longitude,
        accuracyMeters: accuracy,
        at: start.add(Duration(seconds: seconds)),
      );

  void add(PhoneRunTrack track, PhoneRunFix fix) => track.add(fix, fix.at);

  test('la oscilación con el móvil quieto no suma metros', () {
    final track = PhoneRunTrack();
    add(track, fix(0, 0));
    add(track, fix(1, .000010));
    add(track, fix(2, -.000009));
    add(track, fix(3, .000007));
    add(track, fix(4, .000015));
    final totals = track.pause(fix(4, 0).at);
    expect(totals.seconds, 4);
    expect(totals.distanceMeters, 0);
    expect(totals.paceSecondsPerKm, isNull);
  });

  test('pausar excluye el tiempo y el desplazamiento entre tramos', () {
    final track = PhoneRunTrack();
    add(track, fix(0, 0));
    for (var second = 1; second <= 7; second++) {
      add(track, fix(second, second * .00004));
    }
    final first = track.pause(fix(7, 0).at);
    add(track, fix(90, .001));
    for (var second = 1; second <= 7; second++) {
      add(track, fix(90 + second, .001 + second * .00004));
    }
    final totals = track.pause(fix(97, 0).at);
    expect(first.distanceMeters, closeTo(31, 1));
    expect(totals.distanceMeters, closeTo(62, 1));
    expect(totals.seconds, 14);
    expect(totals.paceSecondsPerKm, closeTo(225, 2));
  });

  test(
    'una pérdida de GPS mantiene tiempo y deja la distancia como parcial',
    () {
      final track = PhoneRunTrack();
      add(track, fix(0, 0));
      add(track, fix(1, .00004));
      add(track, fix(2, .003)); // salto incompatible con ir a pie
      add(track, fix(10, .0004, accuracy: 60));
      add(track, fix(25, .001));
      add(track, fix(26, .00104));
      final totals = track.pause(fix(26, 0).at);
      expect(totals.seconds, 26);
      expect(totals.distanceMeters, closeTo(9, 1));
      expect(totals.distanceReliable, isFalse);
      expect(totals.paceSecondsPerKm, isNull);
    },
  );
}
