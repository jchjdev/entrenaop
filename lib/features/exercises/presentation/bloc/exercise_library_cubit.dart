import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:equatable/equatable.dart';

enum ExerciseLibraryStatus { initial, loading, ready, failure }

class ExerciseLibraryState extends Equatable {
  const ExerciseLibraryState({
    this.status = ExerciseLibraryStatus.initial,
    this.officialExercises = const [],
    this.personalExercises = const [],
  });

  final ExerciseLibraryStatus status;
  final List<ExerciseEntity> officialExercises;
  final List<ExerciseEntity> personalExercises;
  bool get isEmpty => officialExercises.isEmpty && personalExercises.isEmpty;

  @override
  List<Object?> get props => [status, officialExercises, personalExercises];
}

class ExerciseLibraryCubit extends Cubit<ExerciseLibraryState> {
  ExerciseLibraryCubit({
    required GetExercisesUseCase getExercises,
    required this.userId,
  }) : _getExercises = getExercises,
       super(const ExerciseLibraryState());

  final GetExercisesUseCase _getExercises;
  final String userId;
  int _request = 0;

  Future<void> load() async {
    if (isClosed) return;
    final request = ++_request;
    emit(
      ExerciseLibraryState(
        status: ExerciseLibraryStatus.loading,
        officialExercises: state.officialExercises,
        personalExercises: state.personalExercises,
      ),
    );
    try {
      final exercises = await _getExercises();
      if (isClosed || request != _request) return;
      // Separación de presentación, no autorización: el servidor mantiene RLS.
      // Contenido público de otro autor no se etiqueta como EntrenaOP ni propio.
      final official = exercises
          .where((e) => e.origin == ExerciseOrigin.system && e.isPublic)
          .toList();
      final personal = exercises
          .where(
            (e) => e.origin == ExerciseOrigin.user && e.createdBy == userId,
          )
          .toList();
      int compare(ExerciseEntity a, ExerciseEntity b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase());
      official.sort(compare);
      personal.sort(compare);
      emit(
        ExerciseLibraryState(
          status: ExerciseLibraryStatus.ready,
          officialExercises: List.unmodifiable(official),
          personalExercises: List.unmodifiable(personal),
        ),
      );
    } catch (_) {
      if (isClosed || request != _request) return;
      emit(
        ExerciseLibraryState(
          status: ExerciseLibraryStatus.failure,
          officialExercises: state.officialExercises,
          personalExercises: state.personalExercises,
        ),
      );
    }
  }
}
