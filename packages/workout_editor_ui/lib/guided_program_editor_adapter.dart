import 'package:flutter/material.dart';
import 'package:workout_core/guided_program.dart';

import 'program_session_catalog.dart';

abstract interface class GuidedProgramCompositionRepository {
  Future<List<GuidedWarmup>> warmups();
  Future<List<GuidedProgramCategory>> categories();
  Future<String> save(GuidedProgram program, {String? id});
}

/// Las pantallas y permisos del contexto se inyectan; la composición es única.
abstract class GuidedProgramEditorAdapter {
  const GuidedProgramEditorAdapter();
  bool get professional => false;
  bool get recoverableSessions => false;
  Future<void> openSessionWork(
    BuildContext context, {
    required String workId,
    required Map<String, dynamic> origin,
    required String programName,
    required Future<void> Function(String) onSaved,
  }) => throw UnsupportedError('Recuperación de sesiones no configurada');
  Future<void> discardSessionWork(String workId) =>
      throw UnsupportedError('Recuperación de sesiones no configurada');
  Future<void> openSession(
    BuildContext context, {
    required String programName,
    String? sessionId,
    required bool duplicate,
    required Future<void> Function(String) onSaved,
  });
  void finish(BuildContext context, String id, bool review);
  Future<void> openLibrary(BuildContext context);
  void openPrograms(BuildContext context);
  Future<String?> createWarmup(BuildContext context);
  Future<GuidedProgramCategory?> createCategory(BuildContext context);
  Future<void> manageCategories(BuildContext context);
  Widget sessionStatus(ProgramSessionSummary? session);
  bool definitiveError(Object error) => false;
  String? visibilityError(Object error) => null;
}
