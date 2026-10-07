import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/plan_preview/domain/plan_preview.dart';

class PlanPreviewCubit extends Cubit<PlanPreviewState> {
  PlanPreviewCubit({required bool enabled, required PlanPreviewStore store})
    : _store = store,
      super(PlanPreviewState(enabled: enabled));

  final PlanPreviewStore _store;
  int _accountRevision = 0;

  void bindAccount(String? userId) {
    if (state.userId == userId) return;
    _accountRevision++;
    var tier = PlanPreviewTier.pro;
    if (state.enabled && userId != null) {
      try {
        tier = _store.read(userId);
      } catch (_) {
        // Una preferencia local dañada no altera la cuenta ni sus datos.
      }
    }
    emit(PlanPreviewState(enabled: state.enabled, userId: userId, tier: tier));
  }

  Future<void> select(PlanPreviewTier tier) async {
    final userId = state.userId;
    if (!state.available || state.saving || state.tier == tier) return;
    final revision = _accountRevision;
    final previous = state.tier;
    emit(
      PlanPreviewState(
        enabled: state.enabled,
        userId: userId,
        tier: previous,
        saving: true,
      ),
    );
    try {
      await _store.save(userId!, tier);
      if (isClosed || revision != _accountRevision) return;
      emit(
        PlanPreviewState(enabled: state.enabled, userId: userId, tier: tier),
      );
    } catch (_) {
      if (isClosed || revision != _accountRevision) return;
      emit(
        PlanPreviewState(
          enabled: state.enabled,
          userId: userId,
          tier: previous,
          error: 'No se pudo guardar la vista de prueba. Inténtalo otra vez.',
        ),
      );
    }
  }
}
