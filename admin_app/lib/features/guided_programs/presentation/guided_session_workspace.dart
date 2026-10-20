import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

import '../../workouts/data/admin_workout_repository.dart';
import '../../workouts/presentation/admin_workout_editor_page.dart';
import '../../workouts/presentation/admin_workout_preview_page.dart';

/// Mantiene el programa montado y reutiliza su creador y revisión de sesiones.
/// Comparte el desplazamiento del programa y conserva su guard local de salida.
class GuidedSessionWorkspace extends StatefulWidget {
  const GuidedSessionWorkspace({
    super.key,
    required this.workouts,
    required this.programName,
    required this.onSaved,
    required this.onClosed,
    required this.exitController,
    this.sessionId,
  });
  final AdminWorkoutRepository workouts;
  final String programName;
  final String? sessionId;
  final Future<void> Function(String) onSaved;
  final Future<void> Function() onClosed;
  final WorkflowExitController exitController;

  @override
  State<GuidedSessionWorkspace> createState() => _GuidedSessionWorkspaceState();
}

class _GuidedSessionWorkspaceState extends State<GuidedSessionWorkspace> {
  final _exit = WorkflowExitController();
  late Future<(AdminWorkoutSummary, WorkoutTemplate)?> _initial = _load();
  bool _editing = false, _registering = false, _closing = false;
  String? _savedId, _error;

  Future<(AdminWorkoutSummary, WorkoutTemplate)?> _load() async {
    if (widget.sessionId == null) return null;
    final sessions = await widget.workouts.listGeneral();
    final source = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final template = await widget.workouts.getTemplateById(widget.sessionId!);
    if (source == null ||
        template == null ||
        !['draft', 'published'].contains(source.status)) {
      throw StateError('Sesión no disponible');
    }
    return (source, template);
  }

  Future<void> _close({bool saved = false}) async {
    if (_closing || _registering) return;
    _closing = true;
    try {
      if (!saved && !await (_exit.onExit?.call() ?? Future.value(true))) return;
      if (!mounted) return;
      await widget.onClosed();
    } finally {
      _closing = false;
    }
  }

  Future<void> _saved(String id) async {
    if (_registering) return;
    setState(() {
      _savedId = id;
      _registering = true;
      _error = null;
    });
    try {
      await widget.onSaved(id);
      if (!mounted) return;
      setState(() => _registering = false);
      await _close(saved: true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'La sesión está guardada, pero no se ha confirmado su enlace al programa. Reintenta; no se creará otra sesión.',
        );
      }
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<bool> _requestExit() async {
    if (_registering || _closing) return false;
    // El padre conserva el ID pendiente incluso cuando falla su enlace.
    if (_savedId != null) return true;
    return await (_exit.onExit?.call() ?? Future.value(true));
  }

  @override
  Widget build(BuildContext context) => WorkflowExitScope(
    controller: widget.exitController,
    child: WorkflowDraftGuard(
      hasUnsavedChanges: () => false,
      beforeExit: _requestExit,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    'Sesión del programa',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: _registering ? null : () => _close(),
                    icon: const Icon(Icons.expand_less),
                    label: const Text('Recoger sesión'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_registering)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _saved(_savedId!),
                      child: const Text('Reintentar enlace'),
                    ),
                  ],
                ),
              )
            else
              FutureBuilder<(AdminWorkoutSummary, WorkoutTemplate)?>(
                future: _initial,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return TextButton(
                      onPressed: () => setState(() => _initial = _load()),
                      child: const Text(
                        'No se pudo cargar la sesión. Reintentar',
                      ),
                    );
                  }
                  final original = snapshot.data;
                  return WorkflowExitScope(
                    controller: _exit,
                    child: original == null || _editing
                        ? AdminWorkoutEditorPage(
                            program: null,
                            repository: widget.workouts,
                            originalTemplate: original?.$2,
                            revisionId: original?.$1.id,
                            initialShowInLibrary: false,
                            embedded: true,
                            programName: widget.programName,
                            onSaved: _saved,
                          )
                        : AdminWorkoutPreviewPage(
                            workout: original.$1,
                            repository: widget.workouts,
                            program: null,
                            embedded: true,
                            allowPublication: false,
                            onEdit: (_) => setState(() => _editing = true),
                          ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}
