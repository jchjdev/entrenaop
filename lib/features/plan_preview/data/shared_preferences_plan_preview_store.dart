import 'package:entrenaop/features/plan_preview/domain/plan_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesPlanPreviewStore implements PlanPreviewStore {
  const SharedPreferencesPlanPreviewStore(this.preferences);
  final SharedPreferences preferences;

  String _key(String userId) => 'development.plan_preview.v1.$userId';

  @override
  PlanPreviewTier read(String userId) =>
      preferences.getString(_key(userId)) == 'free'
      ? PlanPreviewTier.free
      : PlanPreviewTier.pro;

  @override
  Future<void> save(String userId, PlanPreviewTier tier) async {
    if (!await preferences.setString(_key(userId), tier.name)) {
      throw StateError('No se pudo guardar la vista de prueba.');
    }
  }
}
