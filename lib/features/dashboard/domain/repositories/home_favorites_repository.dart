enum HomeShortcut {
  week,
  personalSessions,
  marks,
  availability,
  runningPace,
  fasCalculator,
  library,
  createExercise,
}

const defaultHomeFavorites = [
  HomeShortcut.week,
  HomeShortcut.personalSessions,
  HomeShortcut.marks,
  HomeShortcut.availability,
];

const maxHomeFavorites = 4;

/// Preferencias de navegación, sin relación con la prescripción deportiva.
abstract interface class HomeFavoritesRepository {
  Future<List<HomeShortcut>> load(String userId);
  Future<void> save(String userId, List<HomeShortcut> favorites);
}
