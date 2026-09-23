import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminWorkoutPreviewPage extends StatefulWidget {
  const AdminWorkoutPreviewPage({
    super.key,
    required this.workout,
    required this.repository,
    required this.program,
  });

  final AdminWorkoutSummary workout;
  final AdminWorkoutRepository repository;
  final AdminProgram? program;

  @override
  State<AdminWorkoutPreviewPage> createState() =>
      _AdminWorkoutPreviewPageState();
}

class _AdminWorkoutPreviewPageState extends State<AdminWorkoutPreviewPage> {
  late Future<WorkoutTemplate?> _template;
  bool _publishing = false;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _template = widget.repository.getTemplateById(widget.workout.id);
  }

  Future<void> _publish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publicar sesión'),
        content: Text(
          widget.workout.catalogScope == 'general'
              ? '«${widget.workout.name}» será visible para todos en la biblioteca general. No se asignará a ningún plan ni agenda.'
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
                  ? 'Publicar en biblioteca general'
                  : 'Publicar para el programa',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      await widget.repository.publishDraft(widget.workout.id);
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo publicar la sesión.')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _remove() async {
    final draft = widget.workout.status == 'draft';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(draft ? 'Borrar borrador' : 'Retirar sesión'),
        content: Text(
          draft
              ? 'Se borrará «${widget.workout.name}». Esta acción no se puede deshacer.'
              : '«${widget.workout.name}» dejará de estar disponible para nuevas asignaciones. Si hay entrenamientos pendientes o en curso, tendrás que reprogramarlos antes. El historial se conservará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(draft ? 'Borrar borrador' : 'Retirar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      await widget.repository.remove(widget.workout.id);
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo retirar la sesión.')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _revise(WorkoutTemplate template) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminWorkoutEditorPage(
          program: widget.program,
          repository: widget.repository,
          originalTemplate: template,
          revisionId: widget.workout.id,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la prescripción. No la publiques todavía.',
                ),
              );
            }
            return _content(snapshot.data!);
          },
        ),
      ),
    ),
  );

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
            ? 'Publicado en biblioteca general'
            : 'Publicado para el programa'}',
      ),
      if (template.description?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        Text(template.description!),
      ],
      if (template.estimatedDurationMinutes != null) ...[
        const SizedBox(height: 10),
        Text('Duración estimada: ${template.estimatedDurationMinutes} min'),
      ],
      const SizedBox(height: 24),
      for (var index = 0; index < template.blocks.length; index++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _block(index, template.blocks[index]),
          ),
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
      if (widget.workout.status == 'draft') ...[
        Text(
          widget.workout.catalogScope == 'general'
              ? 'Publicar la mostrará en la biblioteca general. No modifica planes ni agendas.'
              : 'Publicar la deja disponible para las futuras reglas de este programa. No la asigna todavía a ningún alumno.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: const Icon(Icons.public),
            label: Text(
              _publishing
                  ? 'Publicando…'
                  : widget.workout.catalogScope == 'general'
                  ? 'Publicar en biblioteca general'
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

  Widget _block(int index, WorkoutBlock block) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${index + 1}. ${block.name}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        [
          _formatLabel(block.format),
          if (block.rounds > 1) '${block.rounds} rondas',
          if (block.timeCapSeconds != null)
            'límite ${_time(block.timeCapSeconds!)}',
          if (block.restAfterSeconds > 0)
            'descanso de bloque ${_time(block.restAfterSeconds)}',
        ].join(' · '),
      ),
      const SizedBox(height: 14),
      for (var index = 0; index < block.items.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _item(index, block.items[index], block.format),
        ),
    ],
  );

  Widget _item(int index, WorkoutItem item, WorkoutBlockFormat format) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${item.exerciseName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          if (format == WorkoutBlockFormat.running &&
              item.sets.length > 1 &&
              item.sets.every(
                (set) =>
                    _setText(set, format) == _setText(item.sets.first, format),
              ))
            Text('${item.sets.length} × ${_setText(item.sets.first, format)}')
          else
            for (var number = 0; number < item.sets.length; number++)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${number + 1}. ${_setText(item.sets[number], format)}',
                ),
              ),
        ],
      );
}

String _setText(WorkoutSet set, WorkoutBlockFormat format) {
  final target = set.targetReps != null
      ? '${set.targetReps} rep'
      : set.targetDurationSeconds != null
      ? _time(set.targetDurationSeconds!)
      : '${set.targetDistanceMeters?.toStringAsFixed(0)} m';
  final details = <String>[target];
  if (set.targetPaceMinSecondsPerKm case final minPace?) {
    final maxPace = set.targetPaceMaxSecondsPerKm;
    details.add(
      maxPace == null || maxPace == minPace
          ? '${_time(minPace)}/km'
          : '${_time(minPace)}–${_time(maxPace)}/km',
    );
  }
  if (set.targetLoadKg != null) details.add('${set.targetLoadKg} kg');
  if (set.targetRir != null) details.add('RIR ${set.targetRir}');
  if (set.recoveryType != null) {
    final measure = set.recoveryDurationSeconds != null
        ? _time(set.recoveryDurationSeconds!)
        : '${set.recoveryDistanceMeters?.toStringAsFixed(0)} m';
    details.add('rec. ${_recoveryLabel(set.recoveryType!)} $measure');
  } else if (format != WorkoutBlockFormat.running && set.restAfterSeconds > 0) {
    details.add('descanso ${_time(set.restAfterSeconds)}');
  }
  return details.join(' · ');
}

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _recoveryLabel(RunningRecoveryType type) => switch (type) {
  RunningRecoveryType.passive => 'pasiva',
  RunningRecoveryType.walking => 'andando',
  RunningRecoveryType.jogging => 'trote',
};

String _formatLabel(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.straightSets => 'Series convencionales',
  WorkoutBlockFormat.superset => 'Superserie',
  WorkoutBlockFormat.circuit => 'Circuito',
  WorkoutBlockFormat.intervals => 'Intervalos',
  WorkoutBlockFormat.emom => 'EMOM',
  WorkoutBlockFormat.amrap => 'AMRAP',
  WorkoutBlockFormat.tabata => 'Tabata 20/10',
  WorkoutBlockFormat.running => 'Carrera por tramos',
  WorkoutBlockFormat.warmUp => 'Calentamiento',
  WorkoutBlockFormat.coolDown => 'Vuelta a la calma',
};
