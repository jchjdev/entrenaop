import 'package:entrenaop/features/dashboard/data/repositories/shared_preferences_home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferencesHomeFavoritesRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesHomeFavoritesRepository(
      await SharedPreferences.getInstance(),
    );
  });
  test('la primera visita tiene destinos predeterminados', () async {
    expect(await repository.load('user-a'), defaultHomeFavorites);
  });
  test('guarda orden y mantiene separadas las cuentas', () async {
    await repository.save('user-a', [
      HomeShortcut.availability,
      HomeShortcut.personalExercises,
    ]);
    expect(await repository.load('user-a'), [
      HomeShortcut.availability,
      HomeShortcut.personalExercises,
    ]);
    expect(await repository.load('user-b'), defaultHomeFavorites);
  });
  test('una selección vacía se conserva, no restaura los defaults', () async {
    await repository.save('user-a', []);
    expect(await repository.load('user-a'), isEmpty);
  });
  test(
    'tolera destinos desconocidos y duplicados de una versión anterior',
    () async {
      SharedPreferences.setMockInitialValues({
        'home_favorites.v1.user-a': [
          'future',
          'library',
          'week',
          'marks',
          'runningPace',
          'fasCalculator',
          'createExercise',
          'personalExercises',
          'availability',
          'personalSessions',
        ],
      });
      repository = SharedPreferencesHomeFavoritesRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await repository.load('user-a'), [
        HomeShortcut.personalExercises,
        HomeShortcut.availability,
        HomeShortcut.personalSessions,
      ]);
    },
  );
  test('rechaza selecciones inválidas y no pisa lo guardado', () async {
    await repository.save('user-a', [HomeShortcut.personalSessions]);
    await expectLater(
      repository.save('user-a', [
        ...HomeShortcut.values,
        HomeShortcut.personalSessions,
      ]),
      throwsArgumentError,
    );
    expect(await repository.load('user-a'), [HomeShortcut.personalSessions]);
  });
  test(
    'retirar todos los antiguos duplicados no rellena la selección',
    () async {
      SharedPreferences.setMockInitialValues({
        'home_favorites.v1.user-a': ['week', 'marks', 'runningPace', 'library'],
      });
      repository = SharedPreferencesHomeFavoritesRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await repository.load('user-a'), isEmpty);
    },
  );
  test('no guarda preferencias sin una cuenta', () async {
    await expectLater(repository.save('', []), throwsArgumentError);
  });
}
