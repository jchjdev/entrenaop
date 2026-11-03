import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';

class PreparationGoalCubit extends Cubit<PreparationGoalState> {
  PreparationGoalCubit({required PreparationGoalRepository repository})
    : _repository = repository,
      super(const PreparationGoalState());

  final PreparationGoalRepository _repository;
  int _loadVersion = 0;
  bool _mutationBusy = false;

  Future<void> load() async {
    if (isClosed || _mutationBusy) return;
    final version = ++_loadVersion;
    final previous = state;
    emit(
      PreparationGoalState(
        status: PreparationGoalStatus.loading,
        goals: previous.goals,
        programs: previous.programs,
      ),
    );
    try {
      // Ambas respuestas se observan también si una falla. No debe quedar
      // un error asíncrono sin recoger al cerrar o recargar el catálogo.
      final result = await Future.wait<Object>([
        _repository.getActiveGoals(),
        _repository.getAvailablePrograms(),
      ], eagerError: true);
      if (isClosed || version != _loadVersion) return;
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.ready,
          goals: result[0] as List<PreparationGoal>,
          programs: result[1] as List<PreparationProgram>,
        ),
      );
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.failure,
          goals: previous.goals,
          programs: previous.programs,
          errorMessage: 'No hemos podido cargar tu objetivo.',
        ),
      );
    }
  }

  Future<void> add(PreparationProgram program) async {
    if (isClosed || _mutationBusy) return;
    if (state.goals.any((goal) => goal.programId == program.id)) return;
    await _save(PreparationGoal(program: program));
  }

  Future<void> updateTargetDate(PreparationGoal goal, DateTime? targetDate) =>
      _save(
        PreparationGoal(
          id: goal.id,
          program: goal.program,
          targetDate: targetDate,
        ),
      );

  Future<void> archive(PreparationGoal goal) async {
    final goalId = goal.id;
    if (goalId == null || isClosed || _mutationBusy) return;
    _mutationBusy = true;
    final version = ++_loadVersion;
    final previous = state;
    emit(
      PreparationGoalState(
        status: PreparationGoalStatus.saving,
        goals: previous.goals,
        programs: previous.programs,
      ),
    );
    try {
      await _repository.archive(goalId);
      if (isClosed || version != _loadVersion) return;
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.saved,
          goals: previous.goals.where((item) => item.id != goalId).toList(),
          programs: previous.programs,
        ),
      );
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.failure,
          goals: previous.goals,
          programs: previous.programs,
          errorMessage: 'No hemos podido guardar tu objetivo.',
        ),
      );
    } finally {
      _mutationBusy = false;
    }
  }

  Future<void> _save(PreparationGoal goal) async {
    if (isClosed || _mutationBusy) return;
    _mutationBusy = true;
    final version = ++_loadVersion;
    final previous = state;
    emit(
      PreparationGoalState(
        status: PreparationGoalStatus.saving,
        goals: previous.goals,
        programs: previous.programs,
      ),
    );
    try {
      final savedGoal = await _repository.save(goal);
      if (isClosed || version != _loadVersion) return;
      // Editar fecha no cambia el orden de las preparaciones guardadas. La
      // portada no debe saltar a otra al recibir el resultado de esta edición.
      final updated = [
        for (final current in previous.goals)
          current.programId == savedGoal.programId ? savedGoal : current,
        if (!previous.goals.any(
          (current) => current.programId == savedGoal.programId,
        ))
          savedGoal,
      ];
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.saved,
          goals: updated,
          programs: previous.programs,
        ),
      );
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.failure,
          goals: previous.goals,
          programs: previous.programs,
          errorMessage: 'No hemos podido guardar tu preparación.',
        ),
      );
    } finally {
      _mutationBusy = false;
    }
  }
}
