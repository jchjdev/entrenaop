import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_preferences_controller.dart';

class PreferenceSource implements ExerciseCatalogPreferences {
  final entries = <String, ExercisePreferenceEntry>{};
  final favorites = <(String, bool, int, String)>[];
  final selections = <(String, String)>[];
  final receipts = <String, ExercisePreferenceEntry>{};
  int sequence = 0;
  bool loseResponse = false, failRead = false;
  bool accountValid = true;
  Completer<ExercisePreferenceSnapshot>? delayedRead;
  Completer<ExercisePreferenceEntry>? delayedFavorite;
  @override
  String newOperationId() {
    if (!accountValid) throw StateError('account changed');
    return 'operation-${++sequence}';
  }

  @override
  Future<ExercisePreferenceSnapshot> read() async {
    if (delayedRead != null) return delayedRead!.future;
    if (failRead) throw StateError('read failed');
    return ExercisePreferenceSnapshot(entries: entries.values);
  }

  @override
  Future<ExercisePreferenceEntry> setFavorite(
    String id,
    bool favorite, {
    required int expectedRevision,
    required String operationId,
  }) async {
    favorites.add((id, favorite, expectedRevision, operationId));
    if (delayedFavorite != null) return delayedFavorite!.future;
    if (receipts[operationId] case final receipt?) return receipt;
    final current = entries[id];
    if (current != null && current.favoriteRevision != expectedRevision) {
      throw ExercisePreferenceConflict(current);
    }
    final entry = ExercisePreferenceEntry(
      exerciseId: id,
      favorite: favorite,
      favoriteRevision: expectedRevision + 1,
      lastSelectedAt: current?.lastSelectedAt,
    );
    entries[id] = receipts[operationId] = entry;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('response lost after commit');
    }
    return entry;
  }

  @override
  Future<ExercisePreferenceEntry> recordSelection(
    String id, {
    required String operationId,
  }) async {
    selections.add((id, operationId));
    if (receipts[operationId] case final receipt?) return receipt;
    final old = entries[id];
    final entry = ExercisePreferenceEntry(
      exerciseId: id,
      favorite: old?.favorite ?? false,
      favoriteRevision: old?.favoriteRevision ?? 0,
      lastSelectedAt: DateTime.utc(2026, 10, 21, 12, sequence),
    );
    entries[id] = receipts[operationId] = entry;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('response lost after commit');
    }
    return entry;
  }
}

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('snapshot no comparte la lista mutable del consumidor', () {
    final source = <ExercisePreferenceEntry>[];
    final snapshot = ExercisePreferenceSnapshot(entries: source);
    source.add(
      const ExercisePreferenceEntry(
        exerciseId: 'a',
        favorite: true,
        favoriteRevision: 1,
      ),
    );
    expect(snapshot.entries, isEmpty);
    expect(() => snapshot.entries.clear(), throwsUnsupportedError);
  });

  test(
    'respuesta perdida de favorito retiene UUID, payload y revisión',
    () async {
      final source = PreferenceSource();
      final controller = ExercisePreferencesController(source);
      addTearDown(controller.dispose);
      await controller.load();
      source.loseResponse = true;
      controller.toggleFavorite('a');
      await flush();
      expect(controller.favorite('a'), isFalse);
      expect(controller.error, isNotNull);
      controller.toggleFavorite('a');
      expect(source.favorites, hasLength(1));
      controller.retry();
      await flush();
      expect(source.favorites, hasLength(2));
      expect(source.favorites[0], source.favorites[1]);
      expect(controller.favorite('a'), isTrue);
      expect(source.entries['a']!.favoriteRevision, 1);
      expect(controller.error, isNull);
    },
  );

  test('selección incierta reusa UUID y fecha canónica', () async {
    final source = PreferenceSource();
    final controller = ExercisePreferencesController(source);
    addTearDown(controller.dispose);
    await controller.load();
    source.loseResponse = true;
    controller.recordSelection('a');
    await flush();
    final date = source.entries['a']!.lastSelectedAt;
    controller.retry();
    await flush();
    expect(source.selections[0], source.selections[1]);
    expect(controller.selectedAt('a'), date);
    expect(source.sequence, 1);
  });

  test('recibo antiguo no pisa revisión ni fecha posterior ya leída', () async {
    final source = PreferenceSource();
    final controller = ExercisePreferencesController(source);
    addTearDown(controller.dispose);
    await controller.load();
    source.loseResponse = true;
    controller.recordSelection('a');
    await flush();
    final later = DateTime.utc(2026, 10, 22);
    source.entries['a'] = ExercisePreferenceEntry(
      exerciseId: 'a',
      favorite: true,
      favoriteRevision: 9,
      lastSelectedAt: later,
    );
    await controller.load();
    controller.retry();
    await flush();
    expect(controller.favorite('a'), isTrue);
    expect(controller.selectedAt('a'), later);
  });

  test('conflicto recupera revisión incluso si la entrada no estaba en snapshot', () async {
    final source = PreferenceSource();
    final controller = ExercisePreferencesController(source);
    addTearDown(controller.dispose);
    await controller.load();
    source.entries['a'] = const ExercisePreferenceEntry(
      exerciseId: 'a',
      favorite: false,
      favoriteRevision: 7,
    );
    controller.toggleFavorite('a');
    await flush();
    expect(controller.error, contains('otra pestaña'));
    expect(controller.pending('a'), isFalse);
    // La siguiente acción es una decisión nueva tras conocer el estado vigente.
    controller.toggleFavorite('a');
    await flush();
    expect(controller.favorite('a'), isTrue);
    expect(source.favorites.last.$3, 7);
    expect(source.favorites.first.$4, isNot(source.favorites.last.$4));
  });

  test(
    'cierre durante lectura no aplica ni notifica datos de la cuenta anterior',
    () async {
      final source = PreferenceSource()..delayedRead = Completer();
      final controller = ExercisePreferencesController(source);
      var notices = 0;
      controller.addListener(() => notices++);
      final reading = controller.load();
      await flush();
      controller.recordSelection('a');
      controller.dispose();
      final before = notices;
      source.delayedRead!.complete(
        ExercisePreferenceSnapshot(
          entries: [
            const ExercisePreferenceEntry(
              exerciseId: 'private-a',
              favorite: true,
              favoriteRevision: 1,
            ),
          ],
        ),
      );
      await reading;
      await flush();
      expect(notices, before);
      expect(controller.favorite('private-a'), isFalse);
      expect(source.selections, isEmpty);
    },
  );

  test('error de lectura reintenta sin crear operaciones', () async {
    final source = PreferenceSource()..failRead = true;
    final controller = ExercisePreferencesController(source);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.error, isNotNull);
    source.failRead = false;
    controller.retry();
    await flush();
    expect(controller.loaded, isTrue);
    expect(controller.error, isNull);
    expect(source.sequence, 0);
  });

  test(
    'snapshot acotado conserva CAS de desmarcada pero no resucita recientes',
    () async {
      final source = PreferenceSource();
      source.entries['a'] = ExercisePreferenceEntry(
        exerciseId: 'a',
        favorite: false,
        favoriteRevision: 5,
        lastSelectedAt: DateTime.utc(2026, 1, 1),
      );
      final controller = ExercisePreferencesController(source);
      addTearDown(controller.dispose);
      await controller.load();
      source.entries.clear();
      await controller.load();
      expect(controller.selectedAt('a'), isNull);
      controller.toggleFavorite('a');
      await flush();
      expect(source.favorites.single.$3, 5);
    },
  );

  test('salir durante mutación descarta respuesta y no envía las acciones restantes', () async {
    final source = PreferenceSource()..delayedFavorite = Completer();
    final controller = ExercisePreferencesController(source);
    await controller.load();
    controller.toggleFavorite('a');
    await flush();
    controller.recordSelection('b');
    controller.dispose();
    source.delayedFavorite!.complete(
      const ExercisePreferenceEntry(
        exerciseId: 'a',
        favorite: true,
        favoriteRevision: 1,
      ),
    );
    await flush();
    expect(controller.favorite('a'), isFalse);
    expect(source.selections, isEmpty);
  });

  test(
    'cambio de identidad al generar UUID no rompe la selección del ejercicio',
    () async {
      final source = PreferenceSource();
      final controller = ExercisePreferencesController(source);
      addTearDown(controller.dispose);
      await controller.load();
      source.accountValid = false;
      expect(() => controller.recordSelection('a'), returnsNormally);
      expect(controller.error, contains('acceso'));
      expect(() => controller.toggleFavorite('a'), returnsNormally);
      expect(source.selections, isEmpty);
      expect(source.favorites, isEmpty);
    },
  );

  test('un fallo no bloquea cambios en otro ejercicio y conserva el reintento original', () async {
    final source = PreferenceSource();
    source.entries['b'] = const ExercisePreferenceEntry(
      exerciseId: 'b',
      favorite: true,
      favoriteRevision: 3,
    );
    final controller = ExercisePreferencesController(source);
    addTearDown(controller.dispose);
    await controller.load();
    source.loseResponse = true;
    controller.toggleFavorite('a');
    await flush();
    controller.toggleFavorite('b');
    await flush();
    expect(controller.favorite('b'), isFalse);
    expect(controller.error, isNotNull);
    expect(source.favorites, hasLength(2));
    controller.retry();
    await flush();
    expect(source.favorites.first, source.favorites.last);
    expect(controller.favorite('a'), isTrue);
    expect(controller.error, isNull);
  });
}
