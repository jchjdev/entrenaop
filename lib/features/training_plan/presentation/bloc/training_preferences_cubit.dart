import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_state.dart';

class TrainingPreferencesCubit extends Cubit<TrainingPreferencesState> {
  TrainingPreferencesCubit({required TrainingPreferencesRepository repository})
    : _repository = repository,
      super(const TrainingPreferencesState());

  final TrainingPreferencesRepository _repository;

  Future<void> load() async {
    emit(
      const TrainingPreferencesState(status: TrainingPreferencesStatus.loading),
    );
    try {
      final preferences = await _repository.get();
      emit(
        TrainingPreferencesState(
          status: TrainingPreferencesStatus.ready,
          preferences: preferences,
        ),
      );
    } catch (_) {
      emit(
        const TrainingPreferencesState(
          status: TrainingPreferencesStatus.failure,
          errorMessage: 'No hemos podido cargar tu disponibilidad.',
        ),
      );
    }
  }

  Future<void> save(TrainingPreferences preferences) async {
    emit(
      TrainingPreferencesState(
        status: TrainingPreferencesStatus.saving,
        preferences: state.preferences,
      ),
    );
    try {
      await _repository.save(preferences);
      emit(
        TrainingPreferencesState(
          status: TrainingPreferencesStatus.saved,
          preferences: preferences,
        ),
      );
    } catch (_) {
      emit(
        TrainingPreferencesState(
          status: TrainingPreferencesStatus.failure,
          preferences: state.preferences,
          errorMessage:
              'No hemos podido guardar los datos. Inténtalo de nuevo.',
        ),
      );
    }
  }
}
