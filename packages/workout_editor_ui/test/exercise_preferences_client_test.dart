import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_preferences_client.dart';

Map<String, dynamic> entry({int revision = 4, bool favorite = false}) => {
  'exercise_id': 'exercise',
  'favorite': favorite,
  'favorite_revision': revision,
  'last_selected_at': null,
};

class Fixture {
  bool currentIdentity = true, loseResponse = true;
  int gets = 0;
  final writes = <Map<String, dynamic>>[];
  Map<String, dynamic> current = entry();
  late final client = ExercisePreferencesClient(
    context: ExercisePreferenceContext.trainerPrivate,
    operationId: () => 'new-operation',
    isConflict: (error) => error == 'conflict',
    checkIdentity: () {
      if (!currentIdentity) throw StateError('Otra cuenta');
    },
    call: (name, params) async {
      expect(params['p_context'], 'trainer_private');
      if (name == 'get_editor_exercise_preference') {
        gets++;
        return current;
      }
      writes.add(Map.of(params));
      if (loseResponse) throw StateError('Respuesta perdida');
      return entry(revision: 5, favorite: true);
    },
  );
}

void main() {
  test('CAS omitido del snapshot conserva revisión y payload tras respuesta perdida', () async {
    final fixture = Fixture();
    await expectLater(
      fixture.client.setFavorite(
        'exercise',
        true,
        expectedRevision: 0,
        operationId: 'same',
      ),
      throwsStateError,
    );
    fixture.current = entry(revision: 5, favorite: true);
    fixture.loseResponse = false;
    final result = await fixture.client.setFavorite(
      'exercise',
      true,
      expectedRevision: 0,
      operationId: 'same',
    );
    expect(result.favoriteRevision, 5);
    expect(fixture.gets, 1);
    expect(fixture.writes[0], fixture.writes[1]);
    expect(fixture.writes.first['p_expected_revision'], 4);
  });

  test(
    'misma operación no acepta otra intención, revisión ni tipo de acción',
    () async {
      final fixture = Fixture()..loseResponse = false;
      await fixture.client.setFavorite(
        'exercise',
        true,
        expectedRevision: 4,
        operationId: 'same',
      );
      await expectLater(
        fixture.client.setFavorite(
          'exercise',
          false,
          expectedRevision: 4,
          operationId: 'same',
        ),
        throwsStateError,
      );
      await expectLater(
        fixture.client.recordSelection('exercise', operationId: 'same'),
        throwsStateError,
      );
      expect(fixture.writes.length, 1);
    },
  );

  test(
    'favorito confirmado en otra pestaña no invierte silenciosamente el click',
    () async {
      final fixture = Fixture()..current = entry(revision: 7, favorite: true);
      await expectLater(
        fixture.client.setFavorite(
          'exercise',
          true,
          expectedRevision: 0,
          operationId: 'same',
        ),
        throwsA(
          isA<ExercisePreferenceConflict>().having(
            (e) => e.current.favoriteRevision,
            'revision',
            7,
          ),
        ),
      );
      expect(fixture.writes, isEmpty);
    },
  );

  test(
    'dos envíos simultáneos de la misma selección comparten petición',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      final client = ExercisePreferencesClient(
        context: ExercisePreferenceContext.adminOfficial,
        operationId: () => 'op',
        checkIdentity: () {},
        isConflict: (_) => false,
        call: (_, parameters) {
          calls++;
          expect(parameters['p_context'], 'admin_official');
          return pending.future;
        },
      );
      final first = client.recordSelection('exercise', operationId: 'op');
      final second = client.recordSelection('exercise', operationId: 'op');
      pending.complete(entry());
      await Future.wait([first, second]);
      expect(calls, 1);
    },
  );

  test(
    'una cuenta sustituida durante await no recibe preferencias de la anterior',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var identity = true;
      final client = ExercisePreferencesClient(
        context: ExercisePreferenceContext.trainerPrivate,
        operationId: () => 'op',
        isConflict: (_) => false,
        checkIdentity: () {
          if (!identity) throw StateError('Cuenta sustituida');
        },
        call: (_, _) => pending.future,
      );
      final request = client.read();
      identity = false;
      pending.complete({
        'entries': [entry()],
        'recent_limit': 20,
        'favorite_limit': 500,
      });
      await expectLater(request, throwsStateError);
    },
  );

  test(
    'conflicto real devuelve entrada canónica para revisión explícita',
    () async {
      final client = ExercisePreferencesClient(
        context: ExercisePreferenceContext.trainerPrivate,
        operationId: () => 'op',
        checkIdentity: () {},
        isConflict: (e) => e == 'conflict',
        call: (name, _) async {
          if (name == 'get_editor_exercise_preference') {
            return entry(revision: 9);
          }
          throw 'conflict';
        },
      );
      await expectLater(
        client.setFavorite(
          'exercise',
          false,
          expectedRevision: 8,
          operationId: 'op',
        ),
        throwsA(
          isA<ExercisePreferenceConflict>().having(
            (e) => e.current.favoriteRevision,
            'revision',
            9,
          ),
        ),
      );
    },
  );
}
