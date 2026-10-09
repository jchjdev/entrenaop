enum HomeShortcut { personalSessions, personalExercises, availability }

const defaultHomeFavorites = [
  HomeShortcut.personalSessions,
  HomeShortcut.personalExercises,
  HomeShortcut.availability,
];

const maxHomeFavorites = 3;

/// Preferencias de navegación, sin relación con la prescripción deportiva.
abstract interface class HomeFavoritesRepository {
  Future<List<HomeShortcut>> load(String userId);
  Future<void> save(String userId, List<HomeShortcut> favorites);
}
