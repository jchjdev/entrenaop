import 'package:workout_editor_ui/video_read_button.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_editor_ui/exercise_video_preview.dart';

import 'trainer_media_repository.dart';
import 'trainer_workout_repository.dart' show trainerOperationId;

class TrainerTechniquePage extends StatefulWidget {
  const TrainerTechniquePage({
    super.key,
    required this.repository,
    required this.assignmentId,
    this.onVideoRead,
  });
  final TrainerMediaRepository repository;
  final String assignmentId;
  final Future<void> Function(String)? onVideoRead;
  @override
  State<TrainerTechniquePage> createState() => _TrainerTechniquePageState();
}

class _TrainerTechniquePageState extends State<TrainerTechniquePage> {
  late Future<List<TrainerMediaRow>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.technique(widget.assignmentId);
  }

  void _refresh() => setState(() {
    _future = widget.repository.technique(widget.assignmentId);
  });

  bool _canReply(TrainerMediaRow clip) =>
      clip['can_feedback'] == true &&
      (clip['feedback_count'] as num? ?? 0) <
          (clip['feedback_limit'] as num? ?? 100);
  Future<void> _feedback(TrainerMediaRow clip, [double second = 0]) async {
    if (!_canReply(clip)) return;
    final form = GlobalKey<FormState>();
    final time = TextEditingController(text: second.toStringAsFixed(1));
    final body = TextEditingController();
    final operation = trainerOperationId();
    final duration = (clip['duration_seconds'] as num).toDouble();
    var busy = false, locked = false;
    double? submittedTime;
    String? submittedBody, error;
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              title: const Text('Corrección del vídeo'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'El alumno verá el comentario vinculado a este instante de su vídeo.',
                        ),
                        TextFormField(
                          controller: time,
                          enabled: !locked,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Instante en segundos',
                            helperText: 'De 0 a $duration s',
                          ),
                          validator: (value) {
                            final n = double.tryParse(
                              (value ?? '').replaceAll(',', '.'),
                            );
                            return n == null ||
                                    !n.isFinite ||
                                    n < 0 ||
                                    n > duration
                                ? 'Elige un instante dentro del vídeo.'
                                : null;
                          },
                        ),
                        TextFormField(
                          controller: body,
                          enabled: !locked,
                          maxLength: 2000,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Comentario para el alumno',
                          ),
                          validator: (value) => value?.trim().isNotEmpty == true
                              ? null
                              : 'Escribe la corrección.',
                        ),
                        if (error != null) Text(error!),
                        if (busy) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          submittedTime ??= double.parse(
                            time.text.replaceAll(',', '.'),
                          );
                          submittedBody ??= body.text.trim();
                          update(() {
                            busy = true;
                            locked = true;
                            error = null;
                          });
                          try {
                            await widget.repository.feedback(
                              operation,
                              clip['id'] as String,
                              submittedTime!,
                              submittedBody!,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              update(() {
                                busy = false;
                                error = 'No se pudo confirmar. Reintenta con el mismo contenido.';
                              });
                            }
                          }
                        },
                  child: const Text('Enviar corrección'),
                ),
              ],
            ),
          ),
        ),
      );
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      time.dispose();
      body.dispose();
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Técnica del alumno'),
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: FutureBuilder<List<TrainerMediaRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text('No se pudieron cargar los vídeos. Reintentar'),
            ),
          );
        }
        final clips = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Solo aparecen los vídeos compartidos de esta sesión. Retirar la compartición corta el acceso del preparador, conservando el historial del alumno.',
            ),
            if (clips.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay vídeos compartidos de esta sesión.',
                ),
              ),
            for (final clip in clips)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ProfessionalDetailColumns(
                    primary: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Vídeo del ${(clip['created_at'] as String).split('T').first}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (clip['execution_set_id'] != null)
                          const Text(
                            'Vinculado a una serie concreta de esta ejecución.',
                          ),
                        const SizedBox(height: 12),
                        if (clip['status'] == 'ready')
                          ExerciseVideoPreview(
                            key: ValueKey('technique-player-${clip['id']}'),
                            url: clip['playback_url'] as String,
                            source: widget.repository.source(),
                            onPositionSelected: _canReply(clip)
                                ? (second) => _feedback(clip, second)
                                : null,
                          )
                        else
                          Text(
                            'El vídeo está ${clip['status']}. El alumno puede comprobar su preparación.',
                          ),
                      ],
                    ),
                    secondary: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Correcciones de técnica',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (clip['status'] == 'ready') ...[
                          if (_canReply(clip))
                            TextButton.icon(
                              onPressed: () => _feedback(clip),
                              icon: const Icon(Icons.add_comment_outlined),
                              label: const Text(
                                'Añadir corrección en un instante',
                              ),
                            ),
                          if (clip['can_feedback'] != true)
                            const Text(
                              'Solo consulta: el acceso profesional o esta etapa del servicio ya no permiten nuevas respuestas.',
                            ),
                          if (clip['can_feedback'] == true && !_canReply(clip))
                            const Text(
                              'Este vídeo ha alcanzado el límite técnico de comentarios. Conservas las respuestas anteriores.',
                            ),
                        ],
                        if (clip['can_feedback'] == true &&
                            widget.onVideoRead != null)
                          VideoReadButton(
                            key: ValueKey('read-${clip['id']}'),
                            markRead: () =>
                                widget.onVideoRead!(clip['id'] as String),
                          ),
                        if ((clip['feedback'] as List? ?? const []).isEmpty)
                          const Text(
                            'Todavía no hay correcciones compartidas.',
                          ),
                        for (final feedback
                            in (clip['feedback'] as List? ?? const []))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.comment_outlined),
                            title: Text(
                              '${feedback['second']} s · ${feedback['body']}',
                            ),
                            subtitle: const Text(
                              'Comentario compartido con el alumno',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
