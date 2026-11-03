import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sync_apple_training.dart';

/// Solo una preferencia por cuenta e instalación; no concede permisos ni Pro.
class LocalAppleTrainingSyncPreference implements AppleTrainingSyncPreference {
  String _key(String owner) => 'apple.training.auto.$owner';
  @override
  Future<bool> enabled(String owner) async =>
      (await SharedPreferences.getInstance()).getBool(_key(owner)) ?? false;
  @override
  Future<void> setEnabled(String owner, bool value) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _key(owner),
      value,
    );
    if (!saved) throw StateError('No se pudo guardar la preferencia Apple');
  }
}
