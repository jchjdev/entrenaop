import 'package:equatable/equatable.dart';

enum WorkoutCue {
  preparationTick,
  workStarted,
  halfway,
  tenSecondsRemaining,
  workEndingTick,
  workFinished,
  restFinished,
}

class WorkoutCuePreferences extends Equatable {
  const WorkoutCuePreferences({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;

  @override
  List<Object?> get props => [soundEnabled, hapticsEnabled];
}

abstract class WorkoutCueService {
  WorkoutCuePreferences get preferences;

  Future<void> savePreferences(WorkoutCuePreferences preferences);

  Future<void> prepare();

  /// Primera oferta de permiso, según plataforma y preferencias locales.
  Future<bool> shouldOfferHapticsPermission();

  Future<void> markHapticsPermissionOffered();

  /// Acción explícita del usuario; no reproduce avisos ni guarda preferencias.
  Future<bool> requestHapticsPermission();

  /// Prueba explícita del sonido, sin guardar ni modificar preferencias.
  Future<bool> previewSound();

  /// Prueba explícita de vibración, sin sonido ni cambios de preferencias.
  Future<bool> previewHaptics();

  Future<void> signal(WorkoutCue cue);
}
