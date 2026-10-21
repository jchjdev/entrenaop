import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_editor_ui/exercise_video_field.dart';

import '../../../exercises/presentation/widgets/exercise_reference_video.dart';
import '../../data/services/client_technique_repository.dart';
import '../../domain/entities/workout_execution.dart';

/// El historial solo muestra esta sección cuando existe una ejecución pautada
/// por preparador; los usuarios sin ella no reciben un apartado vacío.
class WorkoutTechniqueSection extends StatefulWidget {
  const WorkoutTechniqueSection({
    super.key,
    required this.execution,
    this.repository,
  });
  final WorkoutExecution execution;
  final ClientTechniqueRepository? repository;
  @override
  State<WorkoutTechniqueSection> createState() =>
      _WorkoutTechniqueSectionState();
}

class _WorkoutTechniqueSectionState extends State<WorkoutTechniqueSection> {
  ClientTechniqueRepository? _repository;
  ClientTechniqueContext? _context;
  List<ClientTechniqueClip> _clips = [];
  bool _busy = false;
  String? _error;
  final _shareOperations = <String, String>{};
  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    if (_repository == null && GetIt.instance.isRegistered<SupabaseClient>()) {
      final client = GetIt.instance<SupabaseClient>();
      final owner = client.auth.currentUser?.id;
      if (owner != null) {
        _repository = SupabaseClientTechniqueRepository(client, owner);
      }
    }
    if (_repository != null) _load();
  }

  @override
  void didUpdateWidget(covariant WorkoutTechniqueSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.execution.id != widget.execution.id) {
      _context = null;
      _clips = [];
      _shareOperations.clear();
      _load();
    }
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) return;
    final executionId = widget.execution.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final context = await repository.context(executionId);
      final clips = context == null
          ? <ClientTechniqueClip>[]
          : await repository.clips(context.assignmentId);
      if (mounted && widget.execution.id == executionId) {
        setState(() {
          _context = context;
          _clips = clips;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted && widget.execution.id == executionId) {
        setState(() {
          _busy = false;
          _error = 'No se pudieron actualizar los vídeos.';
        });
      }
    }
  }

  Future<void> _upload([ClientTechniqueClip? resume]) async {
    final data = _context!;
    final controller = TextEditingController();
    String? selectedSet = resume?['execution_set_id'] as String?;
    var source = _repository!.uploader(
      data,
      executionSetId: selectedSet,
      resume: resume,
    );
    var busy = false;
    final selectable = widget.execution.sets
        .where((s) => s.status != WorkoutSetStatus.pending)
        .toList();
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              title: const Text('Enviar técnica al preparador'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'El vídeo se compartirá con el preparador de esta sesión. Después puedes retirar o volver a activar la compartición desde aquí.',
                      ),
                      if (selectable.isNotEmpty)
                        DropdownButtonFormField<String?>(
                          initialValue: selectedSet,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sesión o serie',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('La sesión completa'),
                            ),
                            for (final set in selectable)
                              DropdownMenuItem<String?>(
                                value: set.id,
                                child: Text(
                                  '${set.exerciseName} · serie ${set.setOrder + 1}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged:
                              busy ||
                                  controller.text.isNotEmpty ||
                                  resume != null
                              ? null
                              : (value) => update(() {
                                  selectedSet = value;
                                  source = _repository!.uploader(
                                    data,
                                    executionSetId: value,
                                  );
                                }),
                        ),
                      const SizedBox(height: 12),
                      if (controller.text.isNotEmpty && !busy)
                        const Text(
                          'Vídeo enviado. Al cerrar verás el archivo y podrás retirar su compartición.',
                        )
                      else
                        ExerciseVideoField(
                          key: ValueKey(selectedSet),
                          controller: controller,
                          repository: source,
                          maxVideoBytes:
                              resume?['source_limit'] as int? ??
                              data.sourceLimit,
                          maxVideoDurationSeconds:
                              resume?['duration_limit'] as int? ??
                              data.durationLimit,
                          allowExternalLinks: false,
                          onBusyChanged: (value) => update(() => busy = value),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar y actualizar'),
                ),
              ],
            ),
          ),
        ),
      );
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      controller.dispose();
    }
    if (mounted) await _load();
  }

  Future<void> _toggle(ClientTechniqueClip clip) async {
    final id = clip['id'] as String;
    final operation = _shareOperations.putIfAbsent(id, const Uuid().v4);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository!.setShared(operation, id, !(clip['shared'] as bool));
      _shareOperations.remove(id);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo confirmar la compartición. Reintenta.';
        });
      }
    }
  }

  Future<void> _check(ClientTechniqueClip clip) async {
    setState(() => _busy = true);
    try {
      await _repository!.check(clip['id'] as String);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo comprobar. Puedes reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _context;
    if (data == null || (!data.canUpload && _clips.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Técnica con tu preparador',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar vídeos y respuestas',
                ),
              ],
            ),
            const Text(
              'Estos vídeos y comentarios pertenecen a esta sesión concreta.',
            ),
            if (data.canUpload)
              OutlinedButton.icon(
                onPressed: _busy ? null : _upload,
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Enviar vídeo de técnica'),
              ),
            if (!data.canUpload)
              const Text(
                'El servicio está inactivo. Conservas tus vídeos y respuestas; no puedes enviar vídeos nuevos.',
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              TextButton(onPressed: _load, child: Text(_error!)),
            for (final clip in _clips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vídeo del ${(clip['created_at'] as String).split('T').first} · ${clip['shared'] == true ? 'Compartido' : 'Compartición retirada'}',
                    ),
                    if (clip['status'] == 'ready')
                      ExerciseReferenceVideo(
                        url: clip['playback_url'] as String,
                      )
                    else
                      Text('Estado: ${clip['status']}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _toggle(clip),
                          child: Text(
                            clip['shared'] == true
                                ? 'Retirar compartición'
                                : 'Volver a compartir',
                          ),
                        ),
                        if (clip['status'] == 'uploading' ||
                            clip['status'] == 'processing')
                          TextButton(
                            onPressed: _busy ? null : () => _check(clip),
                            child: const Text('Comprobar vídeo'),
                          ),
                        if (clip['status'] == 'uploading' && data.canUpload)
                          TextButton(
                            onPressed: _busy ? null : () => _upload(clip),
                            child: const Text(
                              'Continuar reserva con el archivo original',
                            ),
                          ),
                      ],
                    ),
                    for (final feedback
                        in (clip['feedback'] as List? ?? const []))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.comment_outlined),
                        title: Text(
                          '${feedback['second']} s · ${feedback['body']}',
                        ),
                        subtitle: const Text('Respuesta de tu preparador'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
