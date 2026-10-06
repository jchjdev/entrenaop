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
      HomeShortcut.library,
      HomeShortcut.runningPace,
    ]);
    expect(await repository.load('user-a'), [
      HomeShortcut.library,
      HomeShortcut.runningPace,
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
        'home_favorites.v1.user-a': ['future', 'library', 'library', 'week'],
      });
      repository = SharedPreferencesHomeFavoritesRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await repository.load('user-a'), [
        HomeShortcut.library,
        HomeShortcut.week,
      ]);
    },
  );
  test('rechaza más de cuatro favoritos y no pisa lo guardado', () async {
    await repository.save('user-a', [HomeShortcut.week]);
    await expectLater(
      repository.save('user-a', HomeShortcut.values.take(5).toList()),
      throwsArgumentError,
    );
    expect(await repository.load('user-a'), [HomeShortcut.week]);
  });
  test('no guarda preferencias sin una cuenta', () async {
    await expectLater(repository.save('', []), throwsArgumentError);
  });
}
