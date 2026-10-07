import 'package:equatable/equatable.dart';

enum PlanPreviewTier { free, pro }

/// Simulación de desarrollo; nunca representa derechos comerciales reales.
class PlanPreviewState extends Equatable {
  const PlanPreviewState({
    required this.enabled,
    this.userId,
    this.tier = PlanPreviewTier.pro,
    this.saving = false,
    this.error,
  });

  final bool enabled;
  final String? userId;
  final PlanPreviewTier tier;
  final bool saving;
  final String? error;
  bool get available => enabled && userId != null;
  bool get isFree => available && tier == PlanPreviewTier.free;

  @override
  List<Object?> get props => [enabled, userId, tier, saving, error];
}

abstract interface class PlanPreviewStore {
  PlanPreviewTier read(String userId);
  Future<void> save(String userId, PlanPreviewTier tier);
}
