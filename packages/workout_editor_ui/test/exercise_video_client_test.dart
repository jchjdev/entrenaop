import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/exercise_video_client.dart';

void main() {
  for (final (scope, limitMiB) in [
    ('official', 20),
    ('trainer_exercise', 100),
    ('client_technique', 100),
  ]) {
    test('$scope explica su límite antes de solicitar una reserva', () async {
      var requested = false;
      final client = ExerciseVideoClient(
        call: (_) async {
          requested = true;
          return {};
        },
        checkIdentity: () {},
        operationId: () => 'unused',
        scope: scope,
      );

      await expectLater(
        client.create(limitMiB * 1024 * 1024 + 1),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('$limitMiB MiB'),
          ),
        ),
      );
      expect(requested, isFalse);
    });
  }
}
