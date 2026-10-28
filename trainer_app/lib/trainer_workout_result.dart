export 'package:workout_editor_ui/professional_workout_result.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_workout_repository.dart';
import 'trainer_operations_repository.dart';
import 'trainer_operations_pages.dart';

/// Consulta sin controles de corrección: los resultados pertenecen al alumno.
class TrainerWorkoutResultPage extends StatefulWidget {
  const TrainerWorkoutResultPage({
    super.key,
    required this.repository,
    required this.assignmentId,
    this.operations,
  });
  final TrainerWorkoutRepository repository;
  final String assignmentId;
  final TrainerOperationsRepository? operations;
  @override
  State<TrainerWorkoutResultPage> createState() =>
      _TrainerWorkoutResultPageState();
}

class _TrainerWorkoutResultPageState extends State<TrainerWorkoutResultPage> {
  late Future<WorkoutJson?> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.result(widget.assignmentId);
  }

  void _refresh() {
    setState(() {
      _future = widget.repository.result(widget.assignmentId);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Resultado del alumno'),
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: FutureBuilder<WorkoutJson?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trainerError(snapshot.error!)),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final row = snapshot.data;
        if (row == null) {
          return const Center(
            child: Text('Todavía no hay una ejecución de esta pauta.'),
          );
        }
        final review = row['review'] as Map?;
        final revision = (row['result_revision'] as num?)?.toInt() ?? 0;
        final reviewed = review?['result_revision'] == revision;
        return LayoutBuilder(
          builder: (context, constraints) {
            final controls = <Widget>[
              if (widget.operations != null &&
                  ['completed', 'abandoned'].contains(row['status']))
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        reviewed
                            ? 'Resultado revisado'
                            : 'Pendiente de revisión',
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await showTrainerReviewDialog(
                            context,
                            widget.operations!,
                            widget.assignmentId,
                            revision,
                            review?['private_note'] as String?,
                          );
                          if (mounted) {
                            _refresh();
                          }
                        },
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(
                          reviewed
                              ? 'Actualizar nota interna'
                              : 'Marcar revisado',
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.operations != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.video_camera_front_outlined),
                        label: const Text('Vídeos de técnica'),
                        onPressed: () => context.push(
                          '/assignments/${widget.assignmentId}/technique',
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Comentar con el alumno'),
                        onPressed: () async {
                          try {
                            final detail = await widget.operations!.assignment(
                              widget.assignmentId,
                            );
                            if (context.mounted) {
                              await context.push(
                                '/conversations/${detail.relationId}?assignment=${widget.assignmentId}',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(trainerError(e))),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ];
            final content = TrainerWorkoutResultContent(
              key: ValueKey(row['id']),
              result: row,
              loadHistory: (cursor) =>
                  loadTrainerComparisonPage(widget.repository, row, cursor),
            );
            if (ProfessionalWorkspaceScope.isDesktop(context) &&
                constraints.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: content),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 310,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Revisión del resultado',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        ...controls,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                ...controls,
                Expanded(child: content),
              ],
            );
          },
        );
      },
    ),
  );
}
