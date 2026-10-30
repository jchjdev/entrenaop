import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/workout_result_review.dart';
import 'package:workout_core/running_step_codec.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/running_step.dart';

import 'workout_result_review_panel.dart';

String _resultDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class TrainerWorkoutResultContent extends StatefulWidget {
  const TrainerWorkoutResultContent({
    super.key,
    required this.result,
    this.loadHistory,
    this.header,
  });
  final Map<String, dynamic> result;
  final ReviewHistoryLoader? loadHistory;

  /// Cabecera integrada en el mismo desplazamiento, útil en consulta móvil.
  final Widget? header;
  @override
  State<TrainerWorkoutResultContent> createState() =>
      _TrainerWorkoutResultContentState();
}

class _TrainerWorkoutResultContentState
    extends State<TrainerWorkoutResultContent> {
  bool _onlyDifferences = false;
  Map<String, dynamic> get result => widget.result;
  @override
  Widget build(BuildContext context) {
    final sets = (result['workout_execution_sets'] as List? ?? []).cast<Map>();
    final amrap = (result['workout_amrap_results'] as List? ?? []).cast<Map>();
    final review = reviewSessionFromJson(result);
    final visible = sets
        .where(
          (s) =>
              !_onlyDifferences ||
              reviewSetFromJson(Map<String, dynamic>.from(s)).needsReview,
        )
        .toList();
    final blocks = _resultBlocks(visible);
    final hasSeries = sets.any((set) => set['block_format'] != 'amrap');
    final status = switch (result['status']) {
      'completed' => 'Completada',
      'abandoned' => 'Abandonada',
      _ => 'En curso',
    };
    final completed = sets.where((s) => s['status'] == 'completed').length;
    final skipped = sets.where((s) => s['status'] == 'skipped').length;
    final started = DateTime.tryParse(result['started_at'] as String? ?? '');
    final abandonment = switch (result['abandonment_reason']) {
      'lack_of_time' => 'Falta de tiempo',
      'too_difficult' => 'Demasiado difícil',
      'discomfort' => 'Molestias',
      'other' => 'Otro motivo',
      _ => null,
    };
    return Center(
      child: ConstrainedBox(
        constraints: ProfessionalWorkspaceScope.pageConstraints(
          context,
          maxWidth: 1000,
        ),
        child: ListView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
          ),
          children: [
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: 16),
            ],
            Text(
              result['template_name'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('$status · Versión ${result['template_version']}'),
            if (started != null)
              Text('Inicio: ${_resultDate(started.toLocal())}'),
            const SizedBox(height: 16),
            if (hasSeries)
              Text(
                '$completed ${completed == 1 ? 'serie completada' : 'series completadas'} · $skipped omitidas',
              ),
            const SizedBox(height: 8),
            _ResultOverview(
              result: result,
              running: sets.any((set) => set['block_format'] == 'running'),
            ),
            if (abandonment != null) Text('Motivo: $abandonment'),
            if ((result['notes'] as String?)?.isNotEmpty == true)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensaciones del alumno',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(result['notes'] as String),
                    ],
                  ),
                ),
              ),
            WorkoutResultReviewControls(
              session: review,
              onlyDifferences: _onlyDifferences,
              onFilterChanged: (value) =>
                  setState(() => _onlyDifferences = value),
              loadHistory: widget.loadHistory,
            ),
            if (_onlyDifferences && visible.isEmpty && amrap.isEmpty)
              const Text('No hay diferencias ni datos pendientes de revisar.'),
            for (final block in amrap)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'AMRAP · Bloque ${(block['block_order'] as int) + 1}: ${block['completed_rounds']} rondas completas'
                    '${block['partial_item_order'] == null ? '' : ' · ejercicio ${(block['partial_item_order'] as int) + 1}: ${block['partial_reps']} rep adicionales'}',
                  ),
                ),
              ),
            for (final block in blocks) ...[
              _ResultBlockHeading(block: block),
              for (final exercise in block.exercises)
                if (block.format == 'running')
                  _RunningResultCard(set: exercise.sets.single)
                else
                  _ExerciseResultCard(
                    key: ValueKey(exercise.key),
                    exercise: exercise,
                    format: block.format,
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultExercise {
  _ResultExercise(this.key, Map first) : sets = [first];
  final String key;
  final List<Map> sets;
  Map get first => sets.first;
}

class _ResultBlock {
  _ResultBlock(this.first);
  final Map first;
  final List<_ResultExercise> exercises = [];
  String get format => first['block_format'] as String? ?? 'straight_sets';
}

List<_ResultBlock> _resultBlocks(List<Map> sets) {
  final blocks = <_ResultBlock>[];
  for (final (index, set) in sets.indexed) {
    // Los nombres se repiten. Solo agrupamos posiciones consecutivas de la
    // misma receta; una identidad incompleta conserva su tarjeta individual.
    final previousBlock = blocks.lastOrNull;
    final sameBlock =
        set['block_order'] != null &&
        previousBlock?.first['block_order'] == set['block_order'] &&
        previousBlock?.first['block_format'] == set['block_format'];
    final block = sameBlock ? previousBlock! : _ResultBlock(set);
    if (!sameBlock) blocks.add(block);
    final previous = block.exercises.lastOrNull;
    final sameExercise =
        block.format != 'running' &&
        set['item_order'] != null &&
        set['exercise_id'] != null &&
        previous?.first['item_order'] == set['item_order'] &&
        previous?.first['exercise_id'] == set['exercise_id'];
    if (sameExercise) {
      previous!.sets.add(set);
    } else {
      block.exercises.add(
        _ResultExercise(
          '${set['block_order']}:${set['item_order']}:$index',
          set,
        ),
      );
    }
  }
  return blocks;
}

(String, Color) _blockStyle(String format) => switch (format) {
  'superset' => ('Superserie', const Color(0xffce93d8)),
  'circuit' => ('Circuito', const Color(0xff80cbc4)),
  'intervals' => ('Intervalos', const Color(0xffffb74d)),
  'emom' => ('EMOM', const Color(0xff81d4fa)),
  'amrap' => ('AMRAP', const Color(0xffffd54f)),
  'tabata' => ('Tabata', const Color(0xffef9a9a)),
  'warm_up' => ('Calentamiento', const Color(0xffffb74d)),
  'cool_down' => ('Enfriamiento', const Color(0xff80cbc4)),
  'running' => ('Carrera', const Color(0xffff9c68)),
  _ => ('Por series', const Color(0xff82b1ff)),
};

/// El resumen usa registros de la ejecución; nunca rellena ausentes con la pauta.
class _ResultOverview extends StatelessWidget {
  const _ResultOverview({required this.result, required this.running});
  final Map<String, dynamic> result;
  final bool running;

  num? _positive(String key) {
    final value = result[key];
    return value is num && value.isFinite && value > 0 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final timer = _positive('observed_timer_seconds');
    final elapsed = _positive('observed_elapsed_seconds');
    final distance = _positive('observed_distance_meters');
    final averageHeartRate = _positive('average_heart_rate_bpm');
    final maxHeartRate = _positive('max_heart_rate_bpm');
    final metrics =
        <({String title, String value, String source, IconData icon})>[
          if (timer != null)
            (
              title: 'Tiempo del reloj',
              value: formatPerformanceTime(timer),
              source: 'Temporizador registrado',
              icon: Icons.timer_outlined,
            ),
          if (elapsed != null)
            (
              title: 'Tiempo transcurrido',
              value: formatPerformanceTime(elapsed),
              source: 'Incluye las pausas del reloj',
              icon: Icons.schedule,
            ),
          if (distance != null)
            (
              title: 'Distancia del reloj',
              value: '${(distance / 1000).toStringAsFixed(2)} km',
              source: 'Total registrado en la actividad',
              icon: Icons.route_outlined,
            ),
          if (running && timer != null && distance != null)
            (
              title: 'Ritmo global calculado',
              value: '${formatPerformanceTime(timer * 1000 / distance)} min/km',
              source: 'Temporizador / distancia total',
              icon: Icons.speed,
            ),
          if (averageHeartRate != null)
            (
              title: 'Pulso medio',
              value: '$averageHeartRate lpm',
              source: 'Registrado en esta sesión',
              icon: Icons.favorite_border,
            ),
          if (maxHeartRate != null)
            (
              title: 'Pulso máximo',
              value: '$maxHeartRate lpm',
              source: 'Registrado en esta sesión',
              icon: Icons.monitor_heart_outlined,
            ),
          if (result['final_rpe'] case final num rpe)
            (
              title: 'Esfuerzo final',
              value: '$rpe/10',
              source: 'Declarado por el alumno',
              icon: Icons.bolt_outlined,
            ),
        ];
    if (metrics.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14)
              .clamp(1.0, 2.0);
          final columns = (constraints.maxWidth / (160 * textScale))
              .floor()
              .clamp(1, 4);
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final metric in metrics)
                SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            metric.icon,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            metric.title,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.value,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.source,
                            style: Theme.of(context).textTheme.bodySmall,
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
}

class _ResultBlockHeading extends StatelessWidget {
  const _ResultBlockHeading({required this.block});
  final _ResultBlock block;
  @override
  Widget build(BuildContext context) {
    final (label, rawColor) = _blockStyle(block.format);
    final color = context.readableAccent(rawColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            block.first['block_name'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(label, style: TextStyle(color: color)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  const _ExerciseResultCard({
    super.key,
    required this.exercise,
    required this.format,
  });
  final _ResultExercise exercise;
  final String format;
  @override
  Widget build(BuildContext context) {
    final sets = exercise.sets;
    final completed = sets.where((s) => s['status'] == 'completed').toList();
    final skipped = sets.where((s) => s['status'] == 'skipped').length;
    final pending = sets.length - completed.length - skipped;
    final recipe = format == 'amrap';
    final color = _blockStyle(format).$2;
    final doses = completed.map(_resultDose).toSet();
    final summary = recipe
        ? 'Receta AMRAP · ${sets.length} ${sets.length == 1 ? 'posición' : 'posiciones'}'
        : [
            '${completed.length}/${sets.length} completadas',
            if (skipped > 0)
              '$skipped ${skipped == 1 ? 'omitida' : 'omitidas'}',
            if (pending > 0)
              '$pending ${pending == 1 ? 'pendiente' : 'pendientes'}',
          ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: ExpansionTile(
          key: PageStorageKey(exercise.key),
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            exercise.first['exercise_name'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary),
                if (!recipe && completed.isNotEmpty)
                  Text(
                    doses.length == 1
                        ? 'Realizado: ${completed.length > 1 ? '${completed.length} × ' : ''}${doses.single}'
                        : 'Resultados variables · ver series',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          children: [
            for (final set in sets) _ResultSeriesRow(set: set, recipe: recipe),
          ],
        ),
      ),
    );
  }
}

String _resultDose(Map set) {
  // El resumen no confunde pautado con realizado ni promedia excepciones.
  // Si hay repeticiones, el tiempo medido queda en el detalle de la serie.
  if (set['actual_reps'] != null) {
    return '${set['actual_reps']} rep${set['actual_load_kg'] == null ? '' : ' · ${set['actual_load_kg']} kg'}';
  }
  return _measures(set, 'actual_');
}

class _ResultSeriesRow extends StatelessWidget {
  const _ResultSeriesRow({required this.set, required this.recipe});
  final Map set;
  final bool recipe;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, rawColor) = switch (set['status']) {
      'completed' => (Icons.check_circle_outline, const Color(0xff80cbc4)),
      'skipped' => (Icons.remove_circle_outline, const Color(0xffffb74d)),
      _ => (Icons.schedule, scheme.onSurfaceVariant),
    };
    final color = context.readableAccent(rawColor);
    final target = Text(
      'Pautado: ${_measures(set, 'target_')}',
      style: TextStyle(color: scheme.onSurfaceVariant),
    );
    final actual = Text(
      'Realizado: ${set['status'] == 'completed' ? _measures(set, 'actual_') : 'Sin registro de resultado'}',
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(recipe ? Icons.repeat : icon, color: color, size: 18),
                Text(
                  'Serie ${(set['set_order'] as int) + 1} · ${recipe ? 'Receta AMRAP' : _setStatus(set['status'])}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 660 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21;
                if (recipe) return target;
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [target, const SizedBox(height: 4), actual],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: target),
                          const SizedBox(width: 20),
                          Expanded(child: actual),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningResultCard extends StatelessWidget {
  const _RunningResultCard({required this.set});
  final Map set;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            set['exercise_name'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Tramo ${(set['set_order'] as int) + 1} · ${_setStatus(set['status'])}',
          ),
          const SizedBox(height: 8),
          Text('Pautado: ${_measures(set, 'target_')}'),
          Text(
            'Realizado: ${set['status'] == 'completed' ? _measures(set, 'actual_') : 'Sin registro de resultado'}',
          ),
        ],
      ),
    ),
  );
}

String _setStatus(dynamic status) => switch (status) {
  'completed' => 'Completada',
  'skipped' => 'Omitida',
  _ => 'Pendiente',
};
String _measures(Map row, String prefix) {
  final values = <String>[];
  if (prefix == 'target_') {
    final step = RunningStepCodec.decode(row['running_step']);
    if (step != null) {
      values.add(step.kind.label);
      if (step.completion == RunningStepCompletion.manual) {
        values.add('Hasta avance manual');
      }
    }
  }
  for (final field in const [
    ('reps', 'rep'),
    ('distance_meters', 'm'),
    ('load_kg', 'kg'),
    ('rpe', 'RPE'),
    ('rir', 'RIR'),
  ]) {
    final value = row['$prefix${field.$1}'];
    if (value != null) values.add('$value ${field.$2}');
  }
  final native = prefix == 'actual_' && row['result_source'] == 'device'
      ? row['observed_duration_seconds'] as num?
      : null;
  final duration = native ?? row['${prefix}duration_seconds'] as num?;
  if (duration != null) values.add(formatPerformanceTime(duration));
  if (prefix == 'actual_' && row['block_format'] == 'running') {
    // La revisión ya elige el tiempo medido y usa la distancia real del tramo,
    // sin sumar recuperaciones ni sustituirla por la distancia pautada.
    final pace = reviewSetFromJson(Map<String, dynamic>.from(row))
        .actual['pace'];
    if (pace != null && pace.isFinite && pace > 0) {
      values.add('ritmo medio ${_time(pace.round())}/km');
    }
  }
  final recovery =
      row['${prefix == 'target_' ? '' : prefix}recovery_duration_seconds']
          as num?;
  final recoveryDistance =
      row['${prefix == 'target_' ? '' : prefix}recovery_distance_meters'];
  if (recovery != null) values.add('recuperación ${_time(recovery.toInt())}');
  if (recoveryDistance != null) values.add('recuperación $recoveryDistance m');
  if (prefix == 'target_') {
    final pace = row['target_pace_min_seconds_per_km'] as num?;
    final max = row['target_pace_max_seconds_per_km'] as num?;
    if (pace != null) {
      values.add(
        '${_time(pace.toInt())}${max == null || max == pace ? '' : '–${_time(max.toInt())}'}/km',
      );
    }
    final rest = row['rest_after_seconds'] as num?;
    if (rest != null && rest > 0) values.add('descanso ${_time(rest.toInt())}');
  }
  return values.isEmpty ? 'Sin valores registrados' : values.join(' · ');
}

String _time(int value) =>
    '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
