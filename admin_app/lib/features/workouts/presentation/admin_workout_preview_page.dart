import 'package:entrena_ui/entrena_ui.dart'
    show
        EntrenaDialog,
        EntrenaDialogActions,
        EntrenaButtonStyles,
        WorkflowDraftGuard;
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

import 'admin_workout_content.dart';
import '../../publication/presentation/publication_review_panel.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminWorkoutPreviewPage extends StatefulWidget {
  const AdminWorkoutPreviewPage({
    super.key,
    required this.workout,
    required this.repository,
    required this.program,
    this.returnSavedId = false,
  });

  final AdminWorkoutSummary workout;
  final AdminWorkoutRepository repository;
  final AdminProgram? program;
  final bool returnSavedId;

  @override
  State<AdminWorkoutPreviewPage> createState() =>
      _AdminWorkoutPreviewPageState();
}

class _AdminWorkoutPreviewPageState extends State<AdminWorkoutPreviewPage> {
  late Future<WorkoutTemplate?> _template;
  bool _publishing = false;
  bool _confirming = false;
  bool _removing = false;
  bool _savingVisibility = false;
  late bool _showInLibrary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _showInLibrary = widget.workout.showInLibrary;
    _template = widget.repository.getTemplateById(widget.workout.id);
  }

  Future<void> _setVisibility(bool value) async {
    if (_savingVisibility || _publishing || _removing || _confirming) return;
    setState(() {
      _savingVisibility = true;
      _error = null;
    });
    try {
      await widget.repository.setLibraryVisibility(
        widget.workout.id,
        value,
        expected: _showInLibrary,
      );
      if (mounted) setState(() => _showInLibrary = value);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cambiar la visibilidad. Reintenta; la sesión y sus programas se conservan.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingVisibility = false);
    }
  }

  Future<void> _publish(WorkoutTemplate reviewed) async {
    if (_savingVisibility ||
        _publishing ||
        _confirming ||
        _removing ||
        _blockingIssues(reviewed).isNotEmpty) {
      return;
    }
    _confirming = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Publicar sesión'),
          content: Text(
            widget.workout.catalogScope == 'general'
                ? _showInLibrary
                      ? '«${widget.workout.name}» se podrá usar en programas y será visible como sesión suelta. No se asignará a ningún plan ni agenda.'
                      : '«${widget.workout.name}» se podrá usar en programas y quedará fuera del listado de sesiones sueltas. No se asignará a ningún plan ni agenda.'
                : '«${widget.workout.name}» quedará disponible como plantilla de este programa. No aparecerá en la biblioteca general ni se asignará a alumnos hasta definir las reglas del plan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                widget.workout.catalogScope == 'general'
                    ? _showInLibrary
                          ? 'Publicar en biblioteca general'
                          : 'Publicar sesión'
                    : 'Publicar para el programa',
              ),
            ),
          ],
        ),
      );
    } finally {
      _confirming = false;
    }
    if (confirmed != true || !mounted || _publishing || _removing) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final latest = await widget.repository.getTemplateById(widget.workout.id);
      if (!mounted) return;
      if (latest == null || latest != reviewed) {
        setState(() {
          _template = Future.value(latest);
          _error = 'La sesión ha cambiado desde la revisión. Comprueba el contenido actualizado antes de publicar.';
        });
        return;
      }
      await widget.repository.publishDraft(widget.workout.id);
      if (mounted) {
        setState(() => _publishing = false);
        context.pop<Object>(widget.returnSavedId ? widget.workout.id : true);
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo publicar la sesión. Tu borrador sigue guardado; puedes reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _remove() async {
    if (_savingVisibility || _publishing || _removing) return;
    final draft = widget.workout.status == 'draft';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => EntrenaDialog(
        title: Text(draft ? 'Borrar borrador' : 'Retirar sesión'),
        content: Text(
          draft
              ? 'Se borrará «${widget.workout.name}». Esta acción no se puede deshacer.'
              : '«${widget.workout.name}» dejará de estar disponible para nuevas asignaciones. Si hay entrenamientos pendientes o en curso, tendrás que reprogramarlos antes. El historial se conservará.',
        ),
        actions: [
          EntrenaDialogActions(
            primaryLabel: 'Cancelar',
            onPrimary: () => Navigator.of(dialogContext).pop(false),
            secondary: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: EntrenaButtonStyles.destructive(dialogContext),
                child: Text(
                  draft ? 'Borrar borrador' : 'Retirar sesión',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _publishing || _removing) return;
    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      await widget.repository.remove(widget.workout.id);
      if (mounted) context.pop<Object?>(widget.returnSavedId ? null : true);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo retirar la sesión. Puedes reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _revise(WorkoutTemplate template) async {
    if (_savingVisibility) return;
    final base = widget.program == null
        ? '/sessions'
        : '/programs/${Uri.encodeComponent(widget.program!.id)}/sessions';
    final saved = await context.push<Object>(
      '$base/${Uri.encodeComponent(widget.workout.id)}/edit${widget.returnSavedId ? '?returnId=true' : ''}',
    );
    // Con onExit asíncrono, el resultado llega antes de retirar la página hija.
    // Esperar su frame evita intentar cerrar dos veces el mismo editor.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && (saved == true || saved is String)) context.pop(saved);
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => false,
    isBusy: () => _publishing || _removing || _confirming || _savingVisibility,
    child: Scaffold(
      appBar: AppBar(title: const Text('Revisar sesión')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FutureBuilder<WorkoutTemplate?>(
            future: _template,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudo cargar la sesión. No la publiques todavía.',
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _template = widget.repository.getTemplateById(
                            widget.workout.id,
                          );
                        }),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              return AbsorbPointer(
                absorbing: _savingVisibility,
                child: _content(snapshot.data!),
              );
            },
          ),
        ),
      ),
    ),
  );

  List<String> _blockingIssues(WorkoutTemplate template) => [
    if (template.blocks.isEmpty) 'La sesión no contiene bloques.',
    if (template.blocks.any(
      (b) => b.items.isEmpty || b.items.any((i) => i.sets.isEmpty),
    ))
      'Hay bloques o ejercicios sin series ni tramos. Completa el borrador antes de publicar.',
  ];

  Widget _content(WorkoutTemplate template) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(template.name, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(
        'Versión ${template.version} · ${widget.workout.status == 'draft'
            ? 'Borrador privado'
            : widget.workout.status == 'archived'
            ? 'Retirada'
            : widget.workout.catalogScope == 'general'
            ? _showInLibrary
                  ? 'Publicado en biblioteca general'
                  : 'Publicada · fuera del listado de sesiones sueltas'
            : 'Publicado para el programa'}',
      ),
      const SizedBox(height: 16),
      if (widget.workout.catalogScope == 'general' &&
          widget.workout.status != 'archived')
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar en Sesiones de EntrenaOP'),
          subtitle: Text(
            _savingVisibility ? 'Guardando…' : 'Se guarda sin crear otra versión. Los programas que la utilizan y sus registros se conservan.',
          ),
          value: _showInLibrary,
          onChanged:
              _publishing || _removing || _confirming || _savingVisibility
              ? null
              : _setVisibility,
        ),
      AdminWorkoutContent(template: template, showTitle: false),
      const SizedBox(height: 16),
      PublicationReviewPanel(
        errors: _blockingIssues(template),
        suggestions: [
          if (template.description?.trim().isNotEmpty != true) 'Puedes añadir una descripción para explicar el objetivo de la sesión.',
          if (template.estimatedDurationMinutes == null)
            'La duración estimada no está indicada.',
        ],
      ),
      const SizedBox(height: 16),
      if (widget.workout.status != 'archived') ...[
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _publishing || _removing
                ? null
                : () => _revise(template),
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              widget.workout.status == 'draft'
                  ? 'Editar borrador'
                  : 'Crear nueva versión en borrador',
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (widget.workout.status == 'draft') ...[
        Text(
          widget.workout.catalogScope == 'general'
              ? _showInLibrary
                    ? 'Publicar la mostrará como sesión suelta y permitirá usarla en programas. No modifica planes ni agendas.'
                    : 'Publicar permitirá usarla en programas. No aparecerá en el listado de sesiones sueltas.'
              : 'Publicar la deja disponible para las futuras reglas de este programa. No la asigna todavía a ningún alumno.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed:
                _publishing || _removing || _blockingIssues(template).isNotEmpty
                ? null
                : () => _publish(template),
            icon: const Icon(Icons.public),
            label: Text(
              _publishing
                  ? 'Publicando…'
                  : widget.workout.catalogScope == 'general'
                  ? _showInLibrary
                        ? 'Publicar en biblioteca general'
                        : 'Publicar sesión'
                  : 'Publicar para el programa',
            ),
          ),
        ),
      ],
      if (widget.workout.status != 'archived') ...[
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _publishing || _removing ? null : _remove,
            icon: const Icon(Icons.delete_outline),
            label: Text(
              _removing
                  ? 'Retirando…'
                  : widget.workout.status == 'draft'
                  ? 'Borrar borrador'
                  : 'Retirar sesión',
            ),
          ),
        ),
      ],
    ],
  );
}
