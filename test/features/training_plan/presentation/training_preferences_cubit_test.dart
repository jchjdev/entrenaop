import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_cubit.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const preferences = TrainingPreferences(
    availableDaysPerWeek: 3,
    sessionDurationMinutes: 60,
    experience: TrainingExperience.occasional,
    equipment: {TrainingEquipment.none},
    requiresProfessionalReview: false,
  );

  test('carga una valoración ya guardada', () async {
    final repository = _TrainingPreferencesRepository(stored: preferences);
    final cubit = TrainingPreferencesCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, TrainingPreferencesStatus.ready);
    expect(cubit.state.preferences, preferences);
  });

  test('guarda la valoración y conserva el resultado confirmado', () async {
    final repository = _TrainingPreferencesRepository();
    final cubit = TrainingPreferencesCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.save(preferences);

    expect(repository.stored, preferences);
    expect(cubit.state.status, TrainingPreferencesStatus.saved);
    expect(cubit.state.preferences, preferences);
  });

  test('expone un fallo recuperable cuando no puede guardar', () async {
    final repository = _TrainingPreferencesRepository(shouldFail: true);
    final cubit = TrainingPreferencesCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.save(preferences);

    expect(cubit.state.status, TrainingPreferencesStatus.failure);
    expect(cubit.state.errorMessage, isNotEmpty);
  });
}

class _TrainingPreferencesRepository implements TrainingPreferencesRepository {
  _TrainingPreferencesRepository({this.stored, this.shouldFail = false});

  TrainingPreferences? stored;
  final bool shouldFail;

  @override
  Future<TrainingPreferences?> get() async {
    if (shouldFail) throw Exception('fallo simulado');
    return stored;
  }

  @override
  Future<void> save(TrainingPreferences preferences) async {
    if (shouldFail) throw Exception('fallo simulado');
    stored = preferences;
  }
}
