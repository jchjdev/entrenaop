import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';

import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class RunningWeekPreviewSection extends StatefulWidget {
  const RunningWeekPreviewSection({
    required this.goalId,
    required this.programId,
    required this.loadContext,
    required this.loadSelectionState,
    required this.loadScheduledWorkouts,
    required this.now,
    this.calculateWeek,
    this.previewInitialWeek,
    this.previewNextWeek,
    this.publishWeek,
    this.onPublished,
    super.key,
  });

  final String goalId;
  final String programId;
  final Future<RunningInitialContext?> Function({
    required String goalId,
    required String programId,
  })
  loadContext;
  final Future<RunningReferenceSelectionState> Function(String goalId)
  loadSelectionState;
  final Future<List<ScheduledWorkout>> Function(DateTime start, DateTime end)
  loadScheduledWorkouts;
  final DateTime Function() now;
  final Future<Map<String, dynamic>> Function(String goalId, DateTime monday)?
  calculateWeek;
  final Future<Map<String, dynamic>> Function(String goalId, DateTime monday)?
  previewInitialWeek;
  final Future<Map<String, dynamic>> Function(String goalId)? previewNextWeek;
  final Future<Map<String, dynamic>> Function(String goalId, DateTime monday)?
  publishWeek;
  final VoidCallback? onPublished;

  @override
  State<RunningWeekPreviewSection> createState() =>
      _RunningWeekPreviewSectionState();
}

class _RunningWeekPreviewSectionState extends State<RunningWeekPreviewSection> {
  Future<Map<String, dynamic>>? _runningPreview;
  Future<Map<String, dynamic>>? _runningReplayPreview;
  Future<Map<String, dynamic>>? _runningNextPreview;
  bool _publishing = false;
  String? _publishError;

  DateTime get _monday {
    final now = widget.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.add(
      Duration(days: now.weekday == DateTime.monday ? 0 : 8 - now.weekday),
    );
  }

  Future<void> _publish() async {
    if (widget.publishWeek == null) return;
    setState(() {
      _publishing = true;
      _publishError = null;
    });
    try {
      final result = await widget.publishWeek!(widget.goalId, _monday);
      if (mounted) {
        setState(() {
          _runningPreview = Future.value(result);
        });
        widget.onPublished?.call();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _publishError = _runningError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: widget.calculateWeek != null && widget.publishWeek != null
          ? _buildRunningWeek(context)
          : const Text(
              'La planificación automática de carrera aún no está conectada a este programa.',
            ),
    ),
  );
  Widget _buildRunningWeek(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Tu próxima semana', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        'Semana del ${DateFormat('dd/MM').format(_monday)}. Revisa la propuesta y publícala para entrenar y registrar tus resultados en Mi semana.',
      ),
      const SizedBox(height: 12),
      FilledButton.tonal(
        onPressed: () => setState(() {
          _runningPreview = widget.calculateWeek!(widget.goalId, _monday);
          _runningReplayPreview = null;
          _publishError = null;
        }),
        child: const Text('Ver semana propuesta'),
      ),
      if (_runningPreview case final future?) ...[
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(_runningError(snapshot.error!));
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final plan = snapshot.data!;
            final sessions = (plan['sessions'] as List).cast<Map>();
            final published = plan['decision_id'] != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sessions.length} sesiones de carrera · ${sessions.fold<int>(0, (sum, item) => sum + (item['minutes'] as int))} min en total esta semana',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(_runningReason(plan)),
                if ((plan['declared_prior_quality_weeks'] as num?)?.toInt()
                    case final weeks? when weeks > 0)
                  Text(
                    'Has declarado calidad en $weeks de las últimas cuatro semanas. Es contexto previo: la progresión a dos días intensos requiere sesiones completadas en EntrenaOP.',
                  ),
                ..._decisionNotes(plan),
                if (plan['phase'] case final String phase) ...[
                  const SizedBox(height: 6),
                  Text('Etapa: ${_phaseLabel(phase)}'),
                ],
                if (plan['needs_control'] == true)
                  const Text(
                    'Actualiza tu control de 2 km. Mientras tanto, la pauta es fácil y sin ritmos calculados.',
                  ),
                for (final session in sessions)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${const ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'][DateTime.parse(session['date'] as String).weekday - 1]} ${DateFormat('dd/MM').format(DateTime.parse(session['date'] as String))} · ${_runningKind(session)} · ${session['minutes']} min',
                    ),
                  ),
                if (sessions.any((s) => s['segments'] != null))
                  ExpansionTile(
                    title: const Text('Ver tramos y orientación de esfuerzo'),
                    children: [
                      for (final session in sessions)
                        ListTile(
                          title: Text(_runningKind(session)),
                          subtitle: Text(_sessionDetails(session)),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (published)
                  FilledButton.icon(
                    onPressed: () => context.push(
                      '/plan/week?date=${DateFormat('yyyy-MM-dd').format(_monday)}',
                    ),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Ver en Mi semana'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _publishing ? null : _publish,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _publishing
                          ? 'Publicando…'
                          : 'Añadir sesiones a Mi semana',
                    ),
                  ),
                if (published && widget.previewInitialWeek != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _runningReplayPreview = widget.previewInitialWeek!(
                        widget.goalId,
                        _monday,
                      );
                    }),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text(
                      'Simular esta semana con la regla actual',
                    ),
                  ),
                  if (_runningReplayPreview case final replay?) ...[
                    const SizedBox(height: 10),
                    FutureBuilder<Map<String, dynamic>>(
                      future: replay,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(_runningError(snapshot.error!));
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final proposed = (snapshot.data!['sessions'] as List)
                            .cast<Map>();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regla actual · ${proposed.length} sesiones · '
                              '${proposed.fold<int>(0, (sum, item) => sum + (item['minutes'] as int))} min en total esta semana',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Ensayo de una primera semana con tus datos actuales. No modifica la semana publicada ni predice la adaptación posterior a tu sesión registrada.',
                            ),
                            Text(_runningReason(snapshot.data!)),
                            ..._decisionNotes(snapshot.data!),
                            for (final session in proposed)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${const ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'][DateTime.parse(session['date'] as String).weekday - 1]} ${DateFormat('dd/MM').format(DateTime.parse(session['date'] as String))} · ${_runningKind(session)} · ${session['minutes']} min',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
                if (_publishError case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(message),
                  ),
              ],
            );
          },
        ),
      ],
      if (widget.previewNextWeek != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _runningNextPreview = widget.previewNextWeek!(widget.goalId);
          }),
          icon: const Icon(Icons.insights_outlined),
          label: const Text('Simular la siguiente semana con mis resultados'),
        ),
        if (_runningNextPreview case final forecast?) ...[
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: forecast,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(_runningError(snapshot.error!));
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final next = snapshot.data!;
              final sessions = (next['sessions'] as List).cast<Map>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semana del ${DateFormat('dd/MM').format(DateTime.parse(next['week_start'] as String))} · ${sessions.length} sesiones',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(_runningReason(next)),
                  ..._decisionNotes(next),
                  const Text(
                    'Simulación con tus sesiones registradas. No añade ni cambia entrenamientos; la publicación real espera al cierre de la semana.',
                  ),
                  for (final session in sessions)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${const ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'][DateTime.parse(session['date'] as String).weekday - 1]} ${DateFormat('dd/MM').format(DateTime.parse(session['date'] as String))} · ${_runningKind(session)} · ${session['minutes']} min',
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    ],
  );
}

List<Widget> _decisionNotes(Map plan) {
  final goal = plan['goal'] as Map?;
  final seconds = (goal?['seconds'] as num?)?.round();
  String time(int value) =>
      '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
  return [
    for (final recommendation in (plan['recommendations'] as List? ?? const []))
      if (recommendation is Map && recommendation['message'] is String)
        Text(recommendation['message'] as String),
    if (seconds != null)
      Text(
        goal?['mode'] == 'official_margin'
            ? 'Meta: ${time(seconds)} · ${goal!['standard']?['scope'] == 'minimum_20_points_not_global_pass' ? 'umbral de 20 puntos del catálogo' : 'mínimo de esta prueba'} menos ${goal['margin_seconds']} s. Categoría: ${goal['standard']?['category'] == 'men' ? 'hombres' : 'mujeres'}. No acredita aptitud global.'
            : 'Meta elegida: ${time(seconds)} en 2 km.',
      ),
    if (plan['control_due'] == true)
      const Text(
        'Conviene actualizar el control de 2 km en las próximas semanas, en un día recuperado. La marca anterior conserva su fecha y vigencia.',
      ),
    if (plan['data_review_required'] == true)
      const Text(
        'Revisa los registros pendientes o incompletos. No los interpretamos como pérdida de forma ni como ausencia de entrenamiento.',
      ),
    if (plan['rpe_review_required'] == true)
      const Text(
        'Tus rodajes fáciles figuran como muy duros (RPE 8 o más), aunque completaste la dosis. Por ahora mantenemos la carga. En el próximo rodaje, comprueba si puedes conversar y registra el esfuerzo con esa referencia; si realmente te cuesta o hay molestias, actualiza tu estado.',
      ),
  ];
}

String _runningKind(Map session) =>
    session['name'] as String? ??
    switch (session['variant_code']) {
      'controlled_4x2_v1' => 'Calidad controlada · 4 × 2 min',
      'controlled_5x2_v1' => 'Calidad controlada · 5 × 2 min',
      _ => switch (session['kind']) {
        'controlled_quality' => 'Calidad controlada',
        'walk_run' => 'Caminar y trotar',
        _ => 'Carrera fácil',
      },
    };

String _runningReason(Map<String, dynamic> plan) =>
    plan['reason'] as String? ??
    switch (plan['outcome']) {
      'reduce' =>
        'Varias sesiones resultaron difíciles: esta semana baja la carga.',
      'maintain' =>
        'Una sesión difícil o datos pendientes: mantenemos la carga.',
      'progress' =>
        'Semana completada y tolerada: avanzamos solo una variable.',
      _ when plan['basis'] == 'returning' => 'Vuelves tras cuatro semanas sin correr. Empezamos con dos sesiones fáciles y ajustamos con lo que registres.',
      _ when plan['basis'] == 'introductory' =>
        'Inicio gradual con caminar y trotar, según tu capacidad declarada.',
      _ => 'La propuesta toma tu carrera reciente como punto de partida y usa los días y minutos que tienes disponibles. Revisa la dosis antes de publicarla; se ajustará con lo que completes.',
    };

String _runningError(Object error) {
  final message = error.toString();
  if (message.contains('Revisa y publica desde Fuerza y carrera')) {
    return 'Tienes referencias de fuerza. Vuelve a Fuerza y carrera para calcular y guardar la semana completa.';
  }
  if (message.contains('Target date has passed')) {
    return 'La fecha objetivo ya pasó. Actualízala para preparar otra semana.';
  }
  if (message.contains('Confirm uninterrupted')) {
    return 'Confirma tu continuidad y actualiza las cuatro semanas recientes antes de reutilizar esta marca.';
  }
  if (message.contains('Health flag') || message.contains('discomfort')) {
    return 'Has indicado molestias o una limitación. Actualiza tu estado antes de generar otra semana.';
  }
  if (message.contains('current running context')) {
    return 'Actualiza tu contexto de carrera para esta semana.';
  }
  if (message.contains('Repeated high effort')) {
    return 'Tus carreras siguen resultando difíciles con la dosis mínima. Revisa tu capacidad actual, disponibilidad y molestias antes de crear otra semana.';
  }
  if (message.contains('valid FAS 2 km mark') ||
      message.contains('reuse window') ||
      message.contains('compatible 2 km mark')) {
    return 'Elige una marca de 2 km vigente para esta preparación.';
  }
  if (message.contains('Official running standard or margin unavailable')) {
    return 'Esta marca no tiene un mínimo oficial aplicable. Elige una evaluación de este programa con baremo, una meta concreta o mejorar sin cifra.';
  }
  if (message.contains('unambiguous module-linked')) {
    return 'La evaluación debe contener una única marca válida vinculada al módulo de carrera de 2 km.';
  }
  if (message.contains('free day')) {
    return 'No hay un día libre de al menos 30 min para programar carrera.';
  }
  if (message.contains('previous week')) {
    return 'Termina la semana actual antes de calcular la siguiente.';
  }
  if (message.contains('Finish or skip')) {
    return 'Registra o salta todas las sesiones publicadas antes de simular la semana siguiente.';
  }
  if (message.contains('Publish a week')) {
    return 'Publica y registra una semana antes de simular la adaptación.';
  }
  if (message.contains('already published')) {
    return 'La siguiente semana ya está publicada; consúltala en Mi semana.';
  }
  return 'No se pudo calcular la semana. Revisa la marca, la disponibilidad y el contexto.';
}

String _phaseLabel(String phase) => switch (phase) {
  'general' => 'Preparación general',
  'build' => 'Desarrollo',
  'specific' => 'Preparación específica',
  'taper' => 'Puesta a punto',
  'reentry' => 'Entrada gradual',
  _ => phase,
};

String _sessionDetails(Map session) {
  final lines = <String>[];
  for (final segment in (session['segments'] as List? ?? []).cast<Map>()) {
    final role = switch (segment['role']) {
      'warmup' => 'Calentamiento',
      'cooldown' => 'Vuelta a la calma',
      _ => 'Trabajo',
    };
    final dose = segment['meters'] != null
        ? '${segment['meters']} m'
        : _duration((segment['seconds'] as num).toInt());
    final pace = segment['pace_min'] == null
        ? ''
        : ' · ${_clock((segment['pace_min'] as num).toInt())}–${_clock((segment['pace_max'] as num).toInt())}/km orientativo';
    final recovery = segment['recovery_seconds'] == null
        ? ''
        : ' · recuperar ${_duration((segment['recovery_seconds'] as num).toInt())}';
    lines.add('$role: $dose$pace$recovery');
  }
  if (session['description'] case final String description) {
    lines.add(description);
  }
  if (session['rpe_ceiling'] != null) {
    lines.add('Esfuerzo orientativo máximo: ${session['rpe_ceiling']}/10.');
  }
  return lines.join('\n');
}

String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
String _duration(int seconds) =>
    seconds % 60 == 0 ? '${seconds ~/ 60} min' : '${_clock(seconds)} min';
