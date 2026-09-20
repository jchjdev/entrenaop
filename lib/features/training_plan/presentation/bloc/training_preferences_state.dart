import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:equatable/equatable.dart';

enum TrainingPreferencesStatus {
  initial,
  loading,
  ready,
  saving,
  saved,
  failure,
}

class TrainingPreferencesState extends Equatable {
  const TrainingPreferencesState({
    this.status = TrainingPreferencesStatus.initial,
    this.preferences,
    this.errorMessage,
  });

  final TrainingPreferencesStatus status;
  final TrainingPreferences? preferences;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, preferences, errorMessage];
}
