import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/performance_set.dart' show supportsRirForTask;

import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../../pro/presentation/widgets/pro_access_widgets.dart';
import '../../../workout_schedule/domain/entities/scheduled_workout.dart';
import '../bloc/adaptive_plan_cubit.dart';
import '../widgets/program_phase_section.dart';

class AdaptivePlanPage extends StatelessWidget {
  const AdaptivePlanPage({this.loadProAccess, super.key});
  final LoadProAccess? loadProAccess;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi plan adaptativo')),
    body: BlocBuilder<AdaptivePlanCubit, AdaptivePlanState>(
      builder: (context, state) {
        final cubit = context.read<AdaptivePlanCubit>();
        final detail = state.detail;
        final publishedSessions = _publishedSessions(state);
        final proRequired = state.setup?.proRequired == true;
        final visibleWorkouts = state.paused && !proRequired
            ? state.workouts.where(
                (item) => item.status != ScheduledWorkoutStatus.planned,
              )
            : state.workouts;
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.status == AdaptivePlanStatus.loading)
                        const LinearProgressIndicator(),
                      if (state.error != null) ...[
                        EntrenaCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(state.error!),
                              OutlinedButton.icon(
                                onPressed: cubit.load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text(
                                  'Reintentar consultar el plan',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (state.setup case final setup?) ...[
                        EntrenaCard(
                          tone: EntrenaCardTone.accent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                setup.proRequired
                                    ? 'Tu plan guardado'
                                    : state.paused
                                    ? 'PLAN ADAPTATIVO · PAUSADO'
                                    : state.needsReview
                                    ? 'PLAN ADAPTATIVO · PENDIENTE DE REVISIÓN'
                                    : state.complete
                                    ? 'PLAN ADAPTATIVO · FINALIZADO'
                                    : 'TU PLAN ADAPTATIVO',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                detail?.goal.program.name ??
                                    setup.programName ??
                                    'Tu preparación',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              if (setup.targetDate case final date?) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Objetivo · ${DateFormat('dd/MM/yyyy').format(date)}',
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                setup.proRequired
                                    ? 'Puedes consultar tus entrenamientos y resultados. Activa Pro para empezar nuevas sesiones del plan.'
                                    : state.paused
                                    ? 'Conservamos tu preparación y tus resultados. Puedes consultar lo pautado; retomarlo requiere revisar la propuesta.'
                                    : setup.programState['message']
                                              as String? ??
                                          'Consulta tu entrenamiento y el recorrido de tu preparación.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<DateTime>(
                          key: ValueKey('plan-week-${state.week}'),
                          initialValue: state.week,
                          isExpanded: true,
                          itemHeight:
                              (MediaQuery.textScalerOf(context).scale(18) + 24)
                                  .clamp(48, 160)
                                  .toDouble(),
                          decoration: InputDecoration(
                            labelText: setup.proRequired
                                ? 'Semanas del plan'
                                : state.paused
                                ? 'Pauta anterior'
                                : 'Semana del plan',
                          ),
                          items: [
                            for (final week in state.weeks)
                              DropdownMenuItem(
                                value: week,
                                child: Text(
                                  'Semana del ${DateFormat('dd/MM/yyyy').format(week)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: state.status == AdaptivePlanStatus.loading
                              ? null
                              : (week) {
                                  if (week != null) cubit.load(week: week);
                                },
                        ),
                        const SizedBox(height: 16),
                        if (state.paused || visibleWorkouts.isEmpty)
                          for (final session in publishedSessions) ...[
                            _PublishedSessionCard(
                              session: session,
                              paused: state.paused,
                              proRequired: setup.proRequired,
                            ),
                            const SizedBox(height: 12),
                          ],
                        if (detail != null &&
                            visibleWorkouts.isEmpty &&
                            publishedSessions.isEmpty)
                          const EntrenaCard(
                            child: Text(
                              'No hay entrenamientos adaptativos conservados en esta semana.',
                            ),
                          ),
                        if (state.paused && visibleWorkouts.isNotEmpty) ...[
                          Text(
                            'Resultados conservados',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (final workout in visibleWorkouts) ...[
                          _SessionCard(
                            workout: workout,
                            paused: state.paused,
                            proRequired: setup.proRequired,
                            onReturn: cubit.load,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!setup.programPath.isEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Estado actual de tu preparación',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          ProgramPhaseSection(path: setup.programPath),
                        ],
                        const SizedBox(height: 20),
                        _PlanAction(state: state, loadProAccess: loadProAccess),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/plan/goal/${Uri.encodeComponent(cubit.goalId)}',
                          ),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Ver preparación y marcas'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _PlanAction extends StatelessWidget {
  const _PlanAction({required this.state, required this.loadProAccess});
  final AdaptivePlanState state;
  final LoadProAccess? loadProAccess;

  @override
  Widget build(BuildContext context) {
    final needsSetup =
        state.setup?.proRequired == true &&
        (state.setup?.programState['status'] == null ||
            state.setup?.programState['status'] == 'draft');
    Widget action(bool? isPro) => FilledButton.icon(
      onPressed: () async {
        final cubit = context.read<AdaptivePlanCubit>();
        await context.push(
          '/plan/goal/${Uri.encodeComponent(cubit.goalId)}/training',
        );
        if (context.mounted) cubit.load();
      },
      icon: Icon(state.paused ? Icons.play_arrow_rounded : Icons.tune_rounded),
      label: Text(
        '${needsSetup
            ? 'Configurar mi plan'
            : state.paused || state.setup?.proRequired == true
            ? 'Retomar mi plan'
            : state.needsReview
            ? 'Revisar mi plan'
            : 'Gestionar mi plan'}${isPro == false || state.setup?.proRequired == true ? ' · Pro' : ''}',
      ),
    );
    // Un fallo al comprobar derechos sólo afecta a la acción comercial: la
    // consulta del plan y sus resultados permanece accesible.
    return loadProAccess == null
        ? action(null)
        : ProAccessBuilder(
            load: loadProAccess!,
            builder: (_, access) => action(access.isPro),
          );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.workout,
    required this.paused,
    required this.proRequired,
    required this.onReturn,
  });
  final ScheduledWorkout workout;
  final bool paused;
  final bool proRequired;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final done =
        workout.status == ScheduledWorkoutStatus.completed ||
        workout.status == ScheduledWorkoutStatus.abandoned;
    final status = switch (workout.status) {
      ScheduledWorkoutStatus.completed => 'Completado',
      ScheduledWorkoutStatus.abandoned => 'Abandonado',
      ScheduledWorkoutStatus.skipped => 'Omitido',
      ScheduledWorkoutStatus.inProgress => 'En curso',
      ScheduledWorkoutStatus.planned =>
        proRequired
            ? 'Entrenamiento del plan'
            : paused
            ? 'Pauta anterior'
            : 'Pautado',
    };
    return EntrenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${DateFormat('dd/MM/yyyy').format(workout.scheduledDate)} · $status',
          ),
          const SizedBox(height: 8),
          Text(
            workout.templateName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (workout.estimatedDurationMinutes case final minutes?) ...[
            const SizedBox(height: 6),
            Text('$minutes min'),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final execution = workout.executionId;
              await context.push(
                done && execution != null
                    ? '/assessment/history/workouts/${Uri.encodeComponent(execution)}'
                    : '/plan/week/session/${Uri.encodeComponent(workout.id)}?date=${DateFormat('yyyy-MM-dd').format(workout.scheduledDate)}',
              );
              if (context.mounted) onReturn();
            },
            child: Text(
              done && workout.executionId != null
                  ? 'Ver resultado'
                  : 'Ver entrenamiento',
            ),
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : const [];

List<Map<String, dynamic>> _publishedSessions(AdaptivePlanState state) {
  final published = state.published;
  final preparation = published?.preparationDecision;
  final running = preparation?['running'] is Map
      ? Map<String, dynamic>.from(preparation!['running'] as Map)
      // Un null explícito conserva el alcance publicado. Sólo las semanas
      // antiguas sin composición propia consultan el documento de carrera.
      : preparation?.containsKey('running') == true ||
            preparation?['training_scope'] == 'performance'
      ? null
      : published?.runningDecision;
  final seenRunning = <String>{};
  return [
      ..._rows(preparation?['sessions']),
      ..._rows(running?['sessions']).map(
        (session) => {
          ...session,
          'running_kind': session['kind'],
          'kind': 'running',
        },
      ),
    ].where((session) {
      if (session['kind'] != 'running') return true;
      final content = Map<String, dynamic>.from(session)
        ..remove('kind')
        ..remove('running_kind');
      // El tipo de carrera también forma parte de la pauta: dos trabajos
      // distintos no se fusionan sólo por coincidir en fecha y duración.
      if (session['running_kind'] != null) {
        content['running_kind'] = session['running_kind'];
      }
      return seenRunning.add(jsonEncode(_canonical(content)));
    }).toList()
    ..sort(
      (a, b) =>
          (a['date'] as String? ?? '').compareTo(b['date'] as String? ?? ''),
    );
}

Object? _canonical(Object? value) => switch (value) {
  Map map => {
    for (final key in (map.keys.cast<String>().toList()..sort()))
      key: _canonical(map[key]),
  },
  List list => list.map(_canonical).toList(),
  _ => value,
};

/// La pauta retirada se lee de su decisión publicada, sin reconstruirla con
/// el algoritmo actual ni intentar comenzar sus sesiones canceladas.
class _PublishedSessionCard extends StatelessWidget {
  const _PublishedSessionCard({
    required this.session,
    required this.paused,
    required this.proRequired,
  });
  final Map<String, dynamic> session;
  final bool paused;
  final bool proRequired;

  @override
  Widget build(BuildContext context) {
    final running = session['kind'] == 'running';
    final date = DateTime.tryParse(session['date'] as String? ?? '');
    final name =
        session['name'] as String? ??
        (running ? 'Carrera' : 'Fuerza y rendimiento');
    return EntrenaCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(name, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text(
          [
            if (date != null) DateFormat('dd/MM/yyyy').format(date),
            if (session['minutes'] != null) '${session['minutes']} min',
            proRequired
                ? 'Entrenamiento del plan'
                : paused
                ? 'Pauta anterior'
                : 'Pauta publicada',
          ].join(' · '),
        ),
        children: [
          if (session['description'] case final String text) Text(text),
          if (session['warm_up_instructions'] case final String text) ...[
            const SizedBox(height: 8),
            Text(
              'Preparación${session['warm_up_seconds'] is num ? ' · ${formatPerformanceTime(session['warm_up_seconds'] as num)} min' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(text),
          ],
          for (final work in _rows(session['work'])) ...[
            const Divider(),
            Text(
              work['name'] as String? ?? 'Trabajo pautado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (work['stimulus'] is Map &&
                (work['stimulus'] as Map)['name'] is String)
              Text((work['stimulus'] as Map)['name'] as String),
            if (work['reason'] case final String reason) Text(reason),
            if (work['role'] == 'regression' || work['role'] == 'support')
              const Text(
                'Trabajo de apoyo: no acredita una marca ni sustituye la práctica de la prueba completa.',
              ),
            if (work['dose'] is Map)
              ..._dose(context, Map<String, dynamic>.from(work['dose'] as Map)),
            if (work['review_due'] == true)
              Text(
                work['review_reason'] as String? ?? 'Este trabajo requiere revisar tu respuesta al entrenamiento.',
              ),
          ],
          if (session['cool_down_instructions'] case final String text) ...[
            const SizedBox(height: 8),
            Text(
              'Vuelta a la calma',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(text),
          ],
        ],
      ),
    );
  }

  List<Widget> _dose(BuildContext context, Map<String, dynamic> dose) {
    final task = dose['task'] is Map
        ? Map<String, dynamic>.from(dose['task'] as Map)
        : const <String, dynamic>{};
    final targets = dose['targets'] is List
        ? (dose['targets'] as List).whereType<num>().toList()
        : const <num>[];
    return [
      const SizedBox(height: 8),
      for (final (index, target) in targets.indexed)
        Text(
          'Serie ${index + 1}: ${_targetLabel(target, task['measurement'] as String? ?? '')}',
        ),
      if (task['fixed_duration_seconds'] case final num duration)
        Text('Duración fijada: ${formatPerformanceTime(duration)} min'),
      if (task['fixed_distance_meters'] case final num distance)
        Text('Distancia fijada: ${_number(distance)} m'),
      if (task['instructions'] case final String instructions)
        if (instructions.isNotEmpty) Text(instructions),
      if (dose['rest_seconds'] case final num rest)
        Text('Descanso entre series: ${formatPerformanceTime(rest)} min'),
      if (supportsRirForTask(
        measurement: task['measurement'] as String? ?? '',
        intent: task['intent'] as String? ?? 'work',
        effortMode: task['effort_mode'] as String?,
      ))
        if (task['target_rir'] case final num rir)
          Text('Conserva al menos ${rir.toInt()} repeticiones de margen.'),
      if (task['target_rpe'] case final num rpe)
        Text(
          'Esfuerzo hasta ${rpe.toInt()}/10; detente si pierdes la postura.',
        ),
      if (task['external_load_kg'] case final num load)
        Text(
          '${task['load_mode'] == 'assisted' ? 'Asistencia' : 'Carga externa'}: ${_number(load)} kg',
        ),
    ];
  }
}

String _targetLabel(num value, String mode) => switch (mode) {
  'DURATION' ||
  'TIME_FOR_DISTANCE' ||
  'TIME_FOR_COURSE' => '${formatPerformanceTime(value)} min',
  'PASS_FAIL' => 'un intento técnico',
  'REPS' || 'LOAD_REPS' || 'REPS_IN_TIME' => '${_number(value)} repeticiones',
  'DISTANCE' || 'HEIGHT' => '${_number(value)} m',
  'MAX_LOAD' => '${_number(value)} kg',
  'REACTIVE_METRICS' => '${_number(value)} s de contacto medido',
  _ => '${_number(value)} · unidad no disponible',
};

String _number(num value) =>
    value == value.truncate() ? '${value.toInt()}' : '$value';
