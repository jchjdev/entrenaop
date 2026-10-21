import 'dart:math';

import 'editor_work_checkpoint.dart';

import 'package:workout_core/guided_program.dart';

String newGuidedWorkId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class GuidedWork {
  const GuidedWork({
    required this.id,
    required this.state,
    this.revision = 0,
    this.baseProgramId,
    this.finalizedProgramId,
    this.updatedAt,
    this.discarded = false,
    this.permanentlyDeleted = false,
  });
  final String id;
  final Map<String, dynamic> state;
  final int revision;
  final String? baseProgramId, finalizedProgramId;
  final DateTime? updatedAt;
  final bool discarded, permanentlyDeleted;
  String get name => (state['name'] as String?)?.trim().isNotEmpty == true
      ? state['name'] as String
      : 'Programa sin nombre';
}

class GuidedWorkConflict implements Exception {
  const GuidedWorkConflict();
}

abstract interface class GuidedWorkRepository {
  Future<List<GuidedWork>> list();
  Future<GuidedWork?> load(String id);
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state);
  Future<String> finalize(GuidedWork work, GuidedProgram program);
  Future<void> discard(GuidedWork work);
}

/// Conserva el contrato de programas sobre el checkpoint canónico compartido.
class GuidedWorkController extends EditorWorkCheckpoint<GuidedWork> {
  GuidedWorkController(
    this.repository,
    GuidedWork work,
    Map<String, dynamic> state,
  ) : super(
        work: work,
        state: state,
        save: repository.save,
        isNew: (work) => work.revision == 0,
        isConflict: (error) => error is GuidedWorkConflict,
        conflictError: GuidedWorkConflict.new,
      );
  final GuidedWorkRepository repository;
}
