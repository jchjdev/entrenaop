export 'package:workout_editor_ui/professional_workout_result.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_workout_repository.dart';
import 'trainer_operations_repository.dart';
import 'trainer_operations_pages.dart';
import 'trainer_review_navigation.dart';
import 'trainer_calendar_date.dart';

/// Consulta sin controles de corrección: los resultados pertenecen al alumno.
class TrainerWorkoutResultPage extends StatefulWidget {
  const TrainerWorkoutResultPage({
    super.key,
    required this.repository,
    required this.assignmentId,
    this.operations,
    this.clientId,
    this.reviewAllClients = false,
  });
  final TrainerWorkoutRepository repository;
  final String assignmentId;
  final TrainerOperationsRepository? operations;
  final String? clientId;
  final bool reviewAllClients;
  @override
  State<TrainerWorkoutResultPage> createState() =>
      _TrainerWorkoutResultPageState();
}

class _TrainerWorkoutResultPageState extends State<TrainerWorkoutResultPage> {
  late Future<WorkoutJson?> _future;
  TrainerAssignmentContext? _detail;
  bool _acting = false, _moreReviews = false;
  String? _notice;
  TrainerReviewItem? _reviewCursor;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<WorkoutJson?> _load() async {
    final generation = ++_generation;
    final id = widget.assignmentId, clientId = widget.clientId;
    final operations = widget.operations;
    final row = await widget.repository.result(id);
    final detail = operations == null ? null : await operations.assignment(id);
    if (clientId != null && detail != null && detail.clientId != clientId ||
        clientId != null &&
            row?['user_id'] != null &&
            row!['user_id'] != clientId) {
      throw StateError('La pauta no corresponde a este alumno.');
    }
    if (mounted && generation == _generation) _detail = detail;
    return row;
  }

  @override
  void didUpdateWidget(covariant TrainerWorkoutResultPage old) {
    super.didUpdateWidget(old);
    if (old.assignmentId != widget.assignmentId ||
        old.clientId != widget.clientId) {
      _detail = null;
      _notice = null;
      _reviewCursor = null;
      _moreReviews = false;
      _future = _load();
    }
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _review(WorkoutJson row, {required bool advance}) async {
    if (_acting || widget.operations == null) return;
    final id = widget.assignmentId;
    setState(() {
      _acting = true;
      _notice = null;
    });
    try {
      final revision = (row['result_revision'] as num?)?.toInt() ?? 0;
      final saved = await showTrainerReviewDialog(
        context,
        widget.operations!,
        widget.assignmentId,
        revision,
        (row['review'] as Map?)?['private_note'] as String?,
        confirmLabel: advance
            ? 'Guardar revisión y continuar'
            : 'Marcar revisado',
      );
      if (!saved || !mounted || widget.assignmentId != id) return;
      final refreshed = _load();
      setState(() {
        _future = refreshed;
      });
      final current = await refreshed;
      if (!mounted || current == null || widget.assignmentId != id) return;
      final currentRevision =
          (current['result_revision'] as num?)?.toInt() ?? 0;
      // Una corrección después del guardado exige revisar la versión nueva.
      if ((current['review'] as Map?)?['result_revision'] != currentRevision) {
        setState(
          () => _notice = 'El alumno ha actualizado los resultados. Revisa los cambios antes de continuar.',
        );
        return;
      }
      if (advance) await _next(reset: true);
    } catch (error) {
      if (mounted) setState(() => _notice = trainerError(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _next({bool reset = false}) async {
    final id = widget.assignmentId;
    final clientId = _detail?.clientId ?? widget.clientId;
    if (!widget.reviewAllClients && clientId == null) {
      setState(
        () => _notice =
            'No se pudo comprobar el alumno. Actualiza antes de continuar.',
      );
      return;
    }
    if (reset) {
      _reviewCursor = null;
      _moreReviews = false;
    }
    final page = await loadTrainerNextReviewPage(
      widget.operations!,
      currentAssignmentId: widget.assignmentId,
      clientId: widget.reviewAllClients ? null : clientId,
      after: _reviewCursor,
    );
    if (!mounted || widget.assignmentId != id) return;
    final next = page.next;
    if (next != null) {
      // Sustituye solo este detalle: volver devuelve a la ficha/agenda/bandeja.
      context.pushReplacement(
        '/clients/${Uri.encodeComponent(next.clientId)}/workouts/${Uri.encodeComponent(next.assignment.id)}/result${widget.reviewAllClients ? '?review=all' : ''}',
      );
    } else {
      setState(() {
        _reviewCursor = page.cursor;
        _moreReviews = page.hasMore;
        _notice = page.hasMore
            ? 'Hay más resultados por consultar. Carga la siguiente página para continuar.'
            : widget.reviewAllClients
            ? 'No quedan resultados pendientes de revisión.'
            : 'No quedan resultados pendientes de revisión de este alumno.';
      });
    }
  }

  Future<void> _continue() async {
    if (_acting) return;
    setState(() {
      _acting = true;
      _notice = null;
    });
    try {
      await _next();
    } catch (error) {
      if (mounted) setState(() => _notice = trainerError(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Resultado del alumno'),
      actions: [
        IconButton(
          onPressed: _acting ? null : _refresh,
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
            final desktop =
                ProfessionalWorkspaceScope.isDesktop(context) &&
                constraints.maxWidth >= 1000;
            final controls = <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_detail != null)
                      Text(
                        _detail!.clientName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    Text(row['template_name'] as String? ?? 'Sesión'),
                    if (_detail != null)
                      Text(
                        'Pauta del ${trainerCalendarDate(_detail!.assignment.date)}',
                      ),
                    if (widget.operations != null)
                      Text(
                        widget.reviewAllClients
                            ? 'Revisión de todos los alumnos'
                            : 'Revisión de este alumno',
                      ),
                    if (_notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_notice!),
                      ),
                  ],
                ),
              ),
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
                        onPressed: _acting
                            ? null
                            : () => _review(row, advance: false),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(
                          reviewed
                              ? 'Actualizar nota interna'
                              : 'Marcar revisado',
                        ),
                      ),
                      if (!reviewed)
                        FilledButton.icon(
                          onPressed: _acting
                              ? null
                              : () => _review(row, advance: true),
                          icon: const Icon(Icons.playlist_add_check),
                          label: const Text('Revisar y siguiente'),
                        ),
                      if (reviewed || _moreReviews)
                        OutlinedButton.icon(
                          onPressed: _acting ? null : _continue,
                          icon: const Icon(Icons.skip_next_outlined),
                          label: Text(
                            _moreReviews
                                ? 'Cargar más pendientes'
                                : 'Siguiente pendiente',
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
                        onPressed: _acting
                            ? null
                            : () => context.push(
                                '/assignments/${widget.assignmentId}/technique',
                              ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Comentar con el alumno'),
                        onPressed: _acting
                            ? null
                            : () async {
                                try {
                                  final detail = await widget.operations!
                                      .assignment(widget.assignmentId);
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
              header: desktop
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: controls,
                    ),
            );
            if (desktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: content),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 310,
                    child: ListView(
                      key: const ValueKey('result-review-actions'),
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
            return content;
          },
        );
      },
    ),
  );
}
