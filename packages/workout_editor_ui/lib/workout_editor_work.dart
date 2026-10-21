export 'workout_editor_snapshot.dart';

import 'editor_work_checkpoint.dart';

class WorkoutWorkConflict implements Exception {
  const WorkoutWorkConflict();
}

class WorkoutEditorWork {
  const WorkoutEditorWork({
    required this.id,
    required this.origin,
    this.state = const {},
    this.revision = 0,
    this.resultId,
    this.discarded = false,
    this.updatedAt,
  });
  final String id;
  // Origen inmutable validado por el adaptador y de nuevo por el servidor.
  final Map<String, dynamic> origin;
  final Map<String, dynamic> state;
  final int revision;
  final String? resultId;
  final bool discarded;
  final DateTime? updatedAt;
  String get name =>
      (state['editor']?['nameText'] as String?)?.trim().isNotEmpty == true
      ? state['editor']['nameText'] as String
      : 'Sesión sin nombre';
}

abstract interface class WorkoutEditorWorkRepository {
  Future<List<WorkoutEditorWork>> list();
  Future<WorkoutEditorWork?> load(String id);
  Future<WorkoutEditorWork> save(
    WorkoutEditorWork work,
    Map<String, dynamic> state,
  );
  Future<String> finalize(WorkoutEditorWork work);
  Future<void> discard(WorkoutEditorWork work);
  Future<WorkoutEditorWork> reopen(WorkoutEditorWork work);
}

/// El consumidor codifica su contexto tipado y confirma el destino del recibo.
/// No se guardan catálogo, URLs de medios ni credenciales en el formulario.
abstract class WorkoutEditorWorkBinding {
  WorkoutEditorWork get work;
  WorkoutEditorWorkRepository get repository;
  Map<String, dynamic> captureContext();
  void restoreContext(Map<String, dynamic> context);
  Future<void> acknowledge(String resultId);
  bool definitiveError(Object error) => false;
}

class WorkoutEditorWorkController
    extends EditorWorkCheckpoint<WorkoutEditorWork> {
  WorkoutEditorWorkController(this.binding, Map<String, dynamic> state)
    : super(
        work: binding.work,
        state: state,
        save: binding.repository.save,
        isNew: (work) => work.revision == 0,
        isConflict: (error) => error is WorkoutWorkConflict,
        conflictError: WorkoutWorkConflict.new,
      ) {
    _prepared = state['intent'] != null;
  }
  final WorkoutEditorWorkBinding binding;
  bool _prepared = false;
  bool get finalizing => _prepared || work.resultId != null;
  @override
  void update(Map<String, dynamic> state) {
    _prepared = state['intent'] != null;
    super.update(state);
  }

  String? _confirmedResult;
  Future<String> finish({void Function()? beforeAcknowledge}) async {
    final id = _confirmedResult ??=
        work.resultId ?? await binding.repository.finalize(work);
    beforeAcknowledge?.call();
    await binding.acknowledge(id);
    return id;
  }

  Future<void> reopen() async {
    final confirmed = await binding.repository.reopen(work);
    if (confirmed.resultId != null) throw const WorkoutWorkConflict();
    _prepared = false;
    accept(confirmed, confirmed.state);
  }
}
