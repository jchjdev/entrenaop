import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/preparation_setup_progress_store.dart';

class SharedPreferencesPreparationSetupProgressStore
    implements PreparationSetupProgressStore {
  const SharedPreferencesPreparationSetupProgressStore(
    this._preferences, {
    required this.ownerId,
  });

  final SharedPreferences _preferences;
  final String ownerId;
  String _key(String goalId) => 'preparation.setup_step.v1.$ownerId.$goalId';

  @override
  Future<PreparationSetupStep?> read(String goalId) async {
    final value = _preferences.getString(_key(goalId));
    return PreparationSetupStep.values
        .where((step) => step.name == value)
        .firstOrNull;
  }

  @override
  Future<void> write(String goalId, PreparationSetupStep step) async {
    await _preferences.setString(_key(goalId), step.name);
  }

  @override
  Future<void> clear(String goalId) async {
    await _preferences.remove(_key(goalId));
  }
}
