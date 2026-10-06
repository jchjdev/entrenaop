import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHomeFavoritesRepository
    implements HomeFavoritesRepository {
  const SharedPreferencesHomeFavoritesRepository(this._preferences);

  final SharedPreferences _preferences;

  String _key(String userId) {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    // Cada cuenta mantiene sus accesos; no se comparte la selección al salir.
    return 'home_favorites.v1.$userId';
  }

  @override
  Future<List<HomeShortcut>> load(String userId) async {
    final saved = _preferences.getStringList(_key(userId));
    if (saved == null) return List.of(defaultHomeFavorites);
    return saved
        .map(
          (name) => HomeShortcut.values
              .where((item) => item.name == name)
              .firstOrNull,
        )
        .whereType<HomeShortcut>()
        .toSet()
        .take(maxHomeFavorites)
        .toList();
  }

  @override
  Future<void> save(String userId, List<HomeShortcut> favorites) async {
    if (favorites.length > maxHomeFavorites ||
        favorites.toSet().length != favorites.length) {
      throw ArgumentError('Selecciona hasta cuatro destinos distintos.');
    }
    final saved = await _preferences.setStringList(
      _key(userId),
      favorites.map((item) => item.name).toList(),
    );
    if (!saved) throw StateError('No se pudieron guardar los favoritos.');
  }
}
