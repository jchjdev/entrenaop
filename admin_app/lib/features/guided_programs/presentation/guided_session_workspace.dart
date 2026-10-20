import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

import '../../workouts/data/admin_workout_repository.dart';
import '../../workouts/presentation/admin_workout_editor_page.dart';

/// Mantiene el programa montado y abre directamente el creador compartido.
/// El guard local protege el panel sin reemplazar el guard de la página padre.
class GuidedSessionWorkspace extends StatefulWidget {
  const GuidedSessionWorkspace({
    super.key,
    required this.workouts,
    required this.programName,
    required this.onSaved,
    this.sessionId,
    this.duplicate = false,
  });
  final AdminWorkoutRepository workouts;
  final String programName;
  final String? sessionId;
  final bool duplicate;
  final Future<void> Function(String) onSaved;

  @override
  State<GuidedSessionWorkspace> createState() => _GuidedSessionWorkspaceState();
}

class _GuidedSessionWorkspaceState extends State<GuidedSessionWorkspace> {
  final _exit = WorkflowExitController();
  late Future<(AdminWorkoutSummary, WorkoutTemplate)?> _initial = _load();
  bool _registering = false, _canPop = false, _closing = false;
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
      setState(() => _canPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(_savedId);
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

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1020),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sesiones · ${widget.programName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Volver al programa',
                    onPressed: _registering ? null : () => _close(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: _registering
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => _saved(_savedId!),
                                child: const Text('Reintentar enlace'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : FutureBuilder<(AdminWorkoutSummary, WorkoutTemplate)?>(
                        future: _initial,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _initial = _load()),
                                child: const Text(
                                  'No se pudo cargar la sesión. Reintentar',
                                ),
                              ),
                            );
                          }
                          final original = snapshot.data;
                          return WorkflowExitScope(
                            controller: _exit,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!widget.duplicate &&
                                    original?.$1.status == 'published')
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Al guardar se creará una nueva versión en borrador para este programa. La versión publicada se conserva.',
                                    ),
                                  ),
                                AdminWorkoutEditorPage(
                                  program: null,
                                  repository: widget.workouts,
                                  originalTemplate: original == null
                                      ? null
                                      : widget.duplicate
                                      ? WorkoutTemplate(
                                          id: original.$2.id,
                                          name:
                                              '${original.$2.name.characters.take(112)} · copia',
                                          description: original.$2.description,
                                          estimatedDurationMinutes: original
                                              .$2
                                              .estimatedDurationMinutes,
                                          version: 1,
                                          blocks: original.$2.blocks,
                                        )
                                      : original.$2,
                                  revisionId: widget.duplicate
                                      ? null
                                      : original?.$1.id,
                                  initialShowInLibrary: false,
                                  embedded: true,
                                  programName: widget.programName,
                                  onSaved: _saved,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
