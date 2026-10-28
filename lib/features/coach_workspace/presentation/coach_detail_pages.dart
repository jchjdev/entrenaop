import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrena_ui/conversation_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';
import 'package:workout_editor_ui/exercise_video_preview.dart';

import 'coach_workspace_scope.dart';
import 'coach_pages.dart';

class CoachAssignmentPage extends StatelessWidget {
  const CoachAssignmentPage({super.key, required this.assignmentId});
  final String assignmentId;
  @override
  Widget build(BuildContext context) {
    final scope = CoachWorkspaceScope.of(context);
    final repo = scope.controller.repository;
    return Scaffold(
      appBar: AppBar(title: const Text('Sesión del alumno')),
      body: CoachLoad(
        load: () async => (
          await repo.assignment(assignmentId),
          await repo.result(assignmentId),
        ),
        builder: (context, data, refresh) {
          final assignment = data.$1;
          final result = data.$2;
          final revision = (result?['result_revision'] as num?)?.toInt() ?? 0;
          final review = result?['review'] as Map?;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      assignment.clientName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${assignment.name} · ${coachDate(assignment.date)} · ${assignment.statusLabel}',
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/coach/technique/${Uri.encodeComponent(assignmentId)}',
                          ),
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('Vídeos de técnica'),
                        ),
                        if (assignment.relationId case final relation?)
                          OutlinedButton.icon(
                            onPressed: () => context.push(
                              '/coach/messages/${Uri.encodeComponent(relation)}',
                            ),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Conversación'),
                          ),
                        if (result != null &&
                            [
                              'completed',
                              'abandoned',
                            ].contains(result['status']))
                          FilledButton.icon(
                            onPressed: () async {
                              await coachTextAction(
                                context,
                                title: 'Marcar resultado revisado',
                                label: 'Nota interna opcional',
                                explanation: 'Esta nota es privada. Para dar indicaciones al alumno utiliza la conversación.',
                                initial:
                                    review?['private_note'] as String? ?? '',
                                allowEmpty: true,
                                save: (operation, text, _) => repo.review(
                                  operation,
                                  assignmentId,
                                  revision,
                                  text,
                                ),
                              );
                              if (context.mounted) {
                                refresh();
                                scope.controller.refresh();
                              }
                            },
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              review?['result_revision'] == revision
                                  ? 'Actualizar revisión'
                                  : 'Marcar revisado',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: result == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Todavía no hay resultados de esta sesión. Puedes consultar sus vídeos compartidos.',
                          ),
                        ),
                      )
                    : TrainerWorkoutResultContent(result: result),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reintentos fijados a la misma operación y contenido; nunca duplicar un envío incierto.
Future<void> coachTextAction(
  BuildContext context, {
  required String title,
  required String label,
  required String explanation,
  required Future<void> Function(String operation, String text, double second)
  save,
  String initial = '',
  bool allowEmpty = false,
  double? duration,
  double initialSecond = 0,
}) async {
  final text = TextEditingController(text: initial);
  final second = TextEditingController(text: initialSecond.toStringAsFixed(1));
  final operation = trainerMessageOperationId();
  String? pendingText;
  double? pendingSecond;
  var locked = false;
  String? validation;
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StatefulBuilder(
      builder: (context, update) => RetainedSaveDialog<void>(
        errorMessage:
            'No se pudo confirmar. Conservamos el envío para reintentar.',
        save: (_) async => save(operation, pendingText!, pendingSecond!),
        builder: (context, submit, saving, error, markDirty) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(explanation),
                if (duration != null)
                  TextField(
                    controller: second,
                    enabled: !locked && !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Instante en segundos (0–$duration)',
                    ),
                    onChanged: (_) => markDirty(true),
                  ),
                TextField(
                  controller: text,
                  enabled: !locked && !saving,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: InputDecoration(labelText: label),
                  onChanged: (_) => markDirty(true),
                ),
                if (validation != null) Text(validation!),
                if (error != null) Text(error),
                if (saving) const LinearProgressIndicator(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.maybePop(context),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () {
                      final value = double.tryParse(
                        second.text.replaceAll(',', '.'),
                      );
                      if ((!allowEmpty && text.text.trim().isEmpty) ||
                          value == null ||
                          !value.isFinite ||
                          value < 0 ||
                          duration != null && value > duration) {
                        update(
                          () => validation =
                              'Revisa el comentario y el instante del vídeo.',
                        );
                        return;
                      }
                      pendingText ??= text.text.trim();
                      pendingSecond ??= value;
                      update(() {
                        locked = true;
                        validation = null;
                      });
                      submit(null);
                    },
              child: Text(error == null ? 'Guardar' : 'Reintentar'),
            ),
          ],
        ),
      ),
    ),
  );
  try {
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
  } finally {
    text.dispose();
    second.dispose();
  }
}

class CoachTechniquePage extends StatelessWidget {
  const CoachTechniquePage({super.key, required this.assignmentId});
  final String assignmentId;
  @override
  Widget build(BuildContext context) {
    final scope = CoachWorkspaceScope.of(context);
    final repo = scope.controller.repository;
    // Desmontar el reproductor oculto detiene también su audio nativo.
    final visible = TickerMode.valuesOf(context).enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Técnica del alumno')),
      body: CoachLoad(
        load: () => repo.technique(assignmentId),
        builder: (context, clips, refresh) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Solo aparecen los vídeos que el alumno comparte de esta sesión.',
            ),
            if (clips.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay vídeos compartidos.'),
              ),
            for (final clip in clips)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vídeo · ${(clip['created_at'] as String).split('T').first}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (clip['status'] == 'ready' && visible)
                        ExerciseVideoPreview(
                          key: ValueKey(clip['id']),
                          url: clip['playback_url'] as String,
                          source: scope.video,
                          onPositionSelected:
                              clip['can_feedback'] == true &&
                                  (clip['feedback_count'] as num? ?? 0) <
                                      (clip['feedback_limit'] as num? ?? 100)
                              ? (second) =>
                                    _reply(context, clip, second, refresh)
                              : null,
                        )
                      else
                        Text('Vídeo en preparación: ${clip['status']}'),
                      for (final feedback in clip['feedback'] as List? ?? [])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.comment_outlined),
                          title: Text(
                            '${feedback['second']} s · ${feedback['body']}',
                          ),
                        ),
                      if (clip['status'] == 'ready' &&
                          clip['can_feedback'] == true &&
                          (clip['feedback_count'] as num? ?? 0) <
                              (clip['feedback_limit'] as num? ?? 100))
                        OutlinedButton.icon(
                          onPressed: () => _reply(context, clip, 0, refresh),
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Añadir corrección'),
                        ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar vídeos'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reply(
    BuildContext context,
    Map<String, dynamic> clip,
    double second,
    VoidCallback refresh,
  ) async {
    final repo = CoachWorkspaceScope.of(context).controller.repository;
    await coachTextAction(
      context,
      title: 'Corrección de técnica',
      label: 'Comentario para el alumno',
      explanation: 'El alumno verá tu comentario vinculado a este instante.',
      duration: (clip['duration_seconds'] as num).toDouble(),
      initialSecond: second,
      save: (operation, text, second) =>
          repo.feedback(operation, clip['id'] as String, second, text),
    );
    if (context.mounted) refresh();
  }
}

class CoachConversationPage extends StatefulWidget {
  const CoachConversationPage({super.key, required this.relationId});
  final String relationId;
  @override
  State<CoachConversationPage> createState() => _CoachConversationPageState();
}

class _CoachConversationPageState extends State<CoachConversationPage> {
  final _acknowledged = <String>{};
  @override
  Widget build(BuildContext context) {
    final scope = CoachWorkspaceScope.of(context);
    final messages = scope.messages;
    return ConversationView(
      key: ValueKey(widget.relationId),
      header: () async {
        final header = await messages.context(widget.relationId);
        return ConversationHeader(title: header.name, canSend: header.canSend);
      },
      load: (before) async =>
          (await messages.list(
                widget.relationId,
                beforeAt: before?.createdAt,
                beforeId: before?.id,
              ))
              .map(
                (m) => ConversationEntry(
                  id: m.id,
                  body: m.body,
                  createdAt: m.createdAt,
                  mine: m.mine,
                  contextLabel: m.assignmentId == null
                      ? null
                      : 'Sobre una pauta del servicio',
                ),
              )
              .toList(),
      send: (id, body) => messages.send(
        operationId: id,
        relationId: widget.relationId,
        body: body,
      ),
      newOperationId: trainerMessageOperationId,
      errorLabel: trainerError,
      refreshInterval: const Duration(seconds: 15),
      onDisplayed: (rows) async {
        final ids = rows
            .where((m) => !m.mine && !_acknowledged.contains(m.id))
            .map((m) => m.id)
            .toList();
        if (ids.isEmpty) return;
        await messages.markRead(ids);
        _acknowledged.addAll(ids);
        if (mounted) await scope.controller.refresh();
      },
    );
  }
}
