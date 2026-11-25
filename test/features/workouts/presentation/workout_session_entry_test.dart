import 'package:entrenaop/features/workouts/presentation/workout_session_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('solo abre un enlace nativo a una ejecución y lo consume una vez', () {
    const id = '11111111-2222-4333-8444-555555555555';
    final entry = WorkoutSessionEntry();
    addTearDown(entry.dispose);
    for (final link in [
      'es.entrenaop://auth-callback/$id',
      'https://workout-session/$id',
      'es.entrenaop://workout-session/invalid',
      'es.entrenaop://workout-session/$id/extra',
      'es.entrenaop://workout-session/$id?account=other',
    ]) {
      entry.receive(Uri.parse(link));
      expect(entry.take(), isNull);
    }
    entry.receive(Uri.parse('es.entrenaop://workout-session/$id'));
    expect(entry.take(), id);
    expect(entry.take(), isNull);
  });
}
