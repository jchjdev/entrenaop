import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final chosen = DateTime(2000, 9, 22);

  test(
    'no muestra error si la escritura entró pero falló su respuesta',
    () async {
      DateTime? stored;
      await confirmBirthDateWrite(
        chosen: chosen,
        write: () async {
          stored = chosen;
          throw StateError('Respuesta perdida tras guardar');
        },
        read: () async => stored,
      );
      expect(stored, chosen);
    },
  );

  test('mantiene el error si la fecha realmente no se guardó', () async {
    await expectLater(
      confirmBirthDateWrite(
        chosen: chosen,
        write: () async => throw StateError('Escritura denegada'),
        read: () async => DateTime(1999, 1, 1),
      ),
      throwsStateError,
    );
  });
}
