import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';
import 'package:workout_editor_ui/guided_program_editor_adapter.dart';
import 'package:workout_editor_ui/program_session_catalog.dart';
import 'package:workout_core/workout_template.dart';

import 'trainer_workout_repository.dart';

class TrainerProgram {
  TrainerProgram.fromJson(Map<String, dynamic> row)
    : program = guidedProgramFromJson(row),
      createdAt = DateTime.parse(row['created_at'] as String);
  final GuidedProgram program;
  final DateTime createdAt;
}

class TrainerProgramEntry {
  const TrainerProgramEntry(this.phase, this.session, this.date);
  final int phase, session;
  final DateTime date;
  Map<String, dynamic> toJson() => {
    'phase': phase,
    'session': session,
    'date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
  };
}

abstract class TrainerProgramRepository {
  Future<List<TrainerProgram>> programs({TrainerProgram? before});
  Future<GuidedProgram> program(String id);
  Future<String> save(
    String operationId,
    GuidedProgram program, {
    String? previousId,
  });
  Future<void> assign({
    required String id,
    required String relationId,
    required String programId,
    required List<TrainerProgramEntry> entries,
    String? note,
  });
}

class SupabaseTrainerProgramRepository implements TrainerProgramRepository {
  const SupabaseTrainerProgramRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    void identity() {
      if (client.auth.currentUser?.id != userId) {
        throw StateError('La cuenta ha cambiado.');
      }
    }

    identity();
    final result = await client.rpc(name, params: params);
    identity();
    return result;
  }

  @override
  Future<List<TrainerProgram>> programs({TrainerProgram? before}) async =>
      (await _rpc('list_trainer_programs', {
            'p_before_at': before?.createdAt.toUtc().toIso8601String(),
            'p_before_id': before?.program.id,
          }) as List)
          .map(
            (r) => TrainerProgram.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
  @override
  Future<GuidedProgram> program(String id) async => guidedProgramFromJson(
    Map<String, dynamic>.from(
      await _rpc('get_trainer_program', {'p_id': id}) as Map,
    ),
  );
  @override
  Future<String> save(
    String operationId,
    GuidedProgram program, {
    String? previousId,
  }) async {
    validateGuidedProgram(program);
    return await _rpc('save_trainer_program', {
      'p_operation_id': operationId,
      'p_payload': guidedProgramToJson(program),
      'p_previous_id': previousId,
    }) as String;
  }

  @override
  Future<void> assign({
    required String id,
    required String relationId,
    required String programId,
    required List<TrainerProgramEntry> entries,
    String? note,
  }) async {
    await _rpc('assign_trainer_program', {
      'p_id': id,
      'p_relation_id': relationId,
      'p_program_id': programId,
      'p_entries': entries.map((e) => e.toJson()).toList(),
      'p_note': note,
    });
  }
}

/// Adapta únicamente la biblioteca profesional al creador único de programas.
class TrainerProgramComposition
    implements GuidedProgramCompositionRepository, ProgramSessionCatalog {
  TrainerProgramComposition(this.repository, this.workouts, {this.original});
  final TrainerProgramRepository repository;
  final TrainerWorkoutRepository workouts;
  final GuidedProgram? original;
  final operationId = trainerOperationId();
  @override
  Future<List<GuidedProgramCategory>> categories() async => [];
  @override
  Future<List<GuidedWarmup>> warmups() async => [];
  @override
  Future<String> save(GuidedProgram program, {String? id}) =>
      repository.save(operationId, program, previousId: id);
  @override
  Future<WorkoutTemplate?> getTemplateById(String id) => workouts.template(id);
  @override
  Future<void> setLibraryVisibility(
    String id,
    bool value, {
    required bool expected,
  }) async => throw UnsupportedError('La biblioteca profesional es privada.');
  @override
  Future<List<ProgramSessionSummary>> listGeneral() async {
    final rows = <TrainerWorkout>[];
    while (true) {
      final next = await workouts.workouts(
        before: rows.isEmpty ? null : rows.last,
      );
      rows.addAll(next);
      if (next.length < 50) break;
    }
    final result = <String, ProgramSessionSummary>{
      for (final row in rows)
        row.id: ProgramSessionSummary(
          id: row.id,
          name: row.name,
          status: 'published',
          version: row.version,
          isRunning: row.isRunning,
          catalogScope: 'private',
          supportsAdjustableRest: false,
          showInLibrary: false,
        ),
    };
    // Una revisión mantiene las referencias antiguas aunque se haya revisado la
    // sesión suelta. No se cambia de versión por tener el mismo nombre/familia.
    for (final session
        in original?.phases.expand((p) => p.sessions) ?? <GuidedSession>[]) {
      if (result.containsKey(session.templateId)) continue;
      final template = await workouts.template(session.templateId);
      if (template != null) {
        result[template.id] = ProgramSessionSummary(
          id: template.id,
          name: template.name,
          status: 'published',
          version: template.version,
          isRunning: false,
          catalogScope: 'private',
          supportsAdjustableRest: false,
          showInLibrary: false,
        );
      }
    }
    return result.values.toList();
  }
}
