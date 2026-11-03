import 'package:entrenaop/features/preparation_goal/data/repositories/shared_preferences_preparation_setup_progress_store.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_setup_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'retoma por titular y preparación y limpiar una no afecta a las demás',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final a = SharedPreferencesPreparationSetupProgressStore(
        preferences,
        ownerId: 'A',
      );
      final b = SharedPreferencesPreparationSetupProgressStore(
        preferences,
        ownerId: 'B',
      );
      await a.write('one', PreparationSetupStep.movements);
      await a.write('two', PreparationSetupStep.availability);
      expect(await b.read('one'), isNull);
      await b.write('one', PreparationSetupStep.program);
      final reloaded = SharedPreferencesPreparationSetupProgressStore(
        preferences,
        ownerId: 'A',
      );
      expect(await reloaded.read('one'), PreparationSetupStep.movements);
      await reloaded.clear('one');
      expect(await a.read('one'), isNull);
      expect(await a.read('two'), PreparationSetupStep.availability);
      expect(await b.read('one'), PreparationSetupStep.program);
    },
  );

  test('una posición desconocida no impide abrir la preparación', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesPreparationSetupProgressStore(
      preferences,
      ownerId: 'A',
    );
    await store.write('goal', PreparationSetupStep.movements);
    await preferences.setString(preferences.getKeys().single, 'future-step');
    expect(await store.read('goal'), isNull);
  });
}
