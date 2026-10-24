import 'package:workout_editor_ui/workout_result_review_panel.dart';

import '../../domain/services/workout_result_review.dart';

import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';

import '../widgets/workout_execution_labels.dart';
import '../widgets/workout_effort_field.dart';
import '../widgets/workout_technique_section.dart';

import 'package:entrenaop/features/workouts/domain/services/running_execution_assessment.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/performance_result_form.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:intl/intl.dart';
import 'package:workout_core/performance_time.dart';

class WorkoutHistoryDetailPage extends StatelessWidget {
  const WorkoutHistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Detalle de la sesión'),
      ),
      body: BlocConsumer<WorkoutHistoryDetailCubit, WorkoutHistoryDetailState>(
        listener: (context, state) {
          final message = state.correctionMessage;
          if (message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) => switch (state.status) {
          WorkoutHistoryDetailStatus.initial ||
          WorkoutHistoryDetailStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          WorkoutHistoryDetailStatus.failure => _DetailError(
            message: state.errorMessage!,
            onRetry: context.read<WorkoutHistoryDetailCubit>().load,
          ),
          WorkoutHistoryDetailStatus.loaded => _DetailContent(
            execution: state.execution!,
            isCorrecting: state.isCorrecting,
          ),
        },
      ),
    );
  }
}

class _DetailContent extends StatefulWidget {
  const _DetailContent({required this.execution, required this.isCorrecting});

  final WorkoutExecution execution;
  final bool isCorrecting;

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  final Set<String> _expanded = {};
  bool _onlyDifferences = false;
  WorkoutExecution get execution => widget.execution;

  @override
  void didUpdateWidget(covariant _DetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.execution.id != execution.id) {
      _expanded.clear();
      _onlyDifferences = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = reviewExecution(execution);
    final visibleIds = review.sets
        .where((s) => !_onlyDifferences || s.needsReview)
        .map((s) => s.id)
        .toSet();
    final amrapBlocks = _groupAmrapBlocks(execution.sets);
    final groups =
        _groupSets(
              execution.sets
                  .where((set) => set.blockFormat != WorkoutBlockFormat.amrap)
                  .toList(),
            )
            .map(
              (group) => _ExerciseGroup(
                blockName: group.blockName,
                exerciseName: group.exerciseName,
                sets: group.sets
                    .where((s) => visibleIds.contains(s.id))
                    .toList(),
                originalKey: group.key,
              ),
            )
            .where((group) => group.sets.isNotEmpty)
            .toList();
    final abandoned = execution.status == WorkoutExecutionStatus.abandoned;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  execution.templateName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _dateFormat.format(execution.startedAt.toLocal()),
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 18),
                _SummaryCard(execution: execution),
                WorkoutTechniqueSection(execution: execution),
                if (execution.notes case final notes?
                    when notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.notes_rounded,
                        color: Color(0xFFFFA06F),
                      ),
                      title: const Text('Sensaciones de la sesión'),
                      subtitle: Text(notes),
                    ),
                  ),
                ],
                if (abandoned && execution.abandonmentReason != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF21130E),
                    child: ListTile(
                      leading: const Icon(
                        Icons.flag_outlined,
                        color: Color(0xFFFFA06F),
                      ),
                      title: const Text('Sesión cerrada antes de terminar'),
                      subtitle: Text(
                        _reasonLabel(execution.abandonmentReason!),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                WorkoutResultReviewControls(
                  session: review,
                  onlyDifferences: _onlyDifferences,
                  onFilterChanged: (value) =>
                      setState(() => _onlyDifferences = value),
                  loadHistory: context
                      .read<WorkoutHistoryDetailCubit>()
                      .comparisonLoader,
                ),
                if (_onlyDifferences && groups.isEmpty && amrapBlocks.isEmpty)
                  const Text(
                    'No hay diferencias ni datos pendientes de revisar.',
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Objetivo y resultado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (groups.any((group) => group.isFoldable))
                      TextButton.icon(
                        onPressed: () => setState(() {
                          if (_expanded.isNotEmpty) {
                            _expanded.clear();
                          } else {
                            _expanded.addAll(
                              groups
                                  .where((g) => g.isFoldable)
                                  .map((g) => g.key),
                            );
                          }
                        }),
                        icon: Icon(
                          _expanded.isEmpty
                              ? Icons.unfold_more
                              : Icons.unfold_less,
                        ),
                        label: Text(
                          _expanded.isEmpty ? 'Desplegar todo' : 'Plegar todo',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...amrapBlocks.map(
                  (block) => _AmrapResultCard(
                    block: block,
                    result: execution.amrapResultFor(block.blockOrder),
                  ),
                ),
                ...groups.map(
                  (group) => _ExerciseResultCard(
                    group,
                    key: ValueKey(group.key),
                    isCorrecting: widget.isCorrecting,
                    expanded: _expanded.contains(group.key),
                    onToggle: () => setState(() {
                      if (!_expanded.add(group.key)) {
                        _expanded.remove(group.key);
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AmrapResultCard extends StatelessWidget {
  const _AmrapResultCard({required this.block, required this.result});

  final _AmrapBlock block;
  final WorkoutAmrapResult? result;

  @override
  Widget build(BuildContext context) {
    final partialExercise = _findExercise(
      block.exercises,
      result?.partialItemOrder,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AMRAP',
              style: TextStyle(
                color: Color(0xFFFF8A50),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              block.blockName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              block.exercises
                  .map((set) => '${set.exerciseName} · ${set.targetReps} rep')
                  .join('\n'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 14),
            if (result == null)
              const Text(
                'Sin resultado guardado',
                style: TextStyle(color: Colors.white54),
              )
            else ...[
              Text(
                '${result!.completedRounds} vueltas completas',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (partialExercise != null) ...[
                const SizedBox(height: 4),
                Text(
                  workoutAmrapResultLabel(
                    result!,
                    block.exercises,
                    includeRounds: false,
                  ),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

WorkoutExecutionSet? _findExercise(
  List<WorkoutExecutionSet> exercises,
  int? itemOrder,
) {
  if (itemOrder == null) return null;
  for (final exercise in exercises) {
    if (exercise.itemOrder == itemOrder) return exercise;
  }
  return null;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.execution});

  final WorkoutExecution execution;

  @override
  Widget build(BuildContext context) {
    final completedAt = execution.completedAt;
    final duration =
        execution.measuredDuration ??
        (execution.resultSource == WorkoutResultSource.device
            ? null
            : completedAt?.difference(execution.startedAt));
    final reportedRunningSeconds = execution.sets
        .where(
          (set) =>
              set.blockFormat == WorkoutBlockFormat.running &&
              set.status == WorkoutSetStatus.completed,
        )
        .fold<double>(
          0,
          (total, set) =>
              total +
              (set.measuredDurationSeconds ?? 0) +
              (set.measuredRecoverySeconds ?? 0),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 22,
          runSpacing: 14,
          children: [
            _SummaryMetric(
              value: '${execution.completedSetCount}',
              label: 'Completadas',
            ),
            _SummaryMetric(
              value: '${execution.skippedSetCount}',
              label: 'Omitidas',
            ),
            _SummaryMetric(
              value: '${execution.sets.length - execution.resolvedSetCount}',
              label: 'Pendientes',
            ),
            if (duration != null)
              _SummaryMetric(
                value: _compactDuration(duration),
                label: execution.measuredDuration == null
                    ? 'Tiempo en la app'
                    : 'Tiempo del reloj',
              ),
            if (execution.observedDistanceMeters != null)
              _SummaryMetric(
                value:
                    '${(execution.observedDistanceMeters! / 1000).toStringAsFixed(2)} km',
                label: 'Distancia del reloj',
              ),
            if (reportedRunningSeconds > 0)
              _SummaryMetric(
                value: _compactDuration(
                  Duration(
                    milliseconds: (reportedRunningSeconds * 1000).round(),
                  ),
                ),
                label: 'Tiempo de carrera registrado',
                width: 155,
              ),
            if (execution.finalRpe case final rpe?)
              _SummaryMetric(value: '$rpe/10', label: 'RPE final'),
            if (execution.averageHeartRateBpm case final heartRate?)
              _SummaryMetric(value: '$heartRate', label: 'FC media'),
            if (execution.maxHeartRateBpm case final heartRate?)
              _SummaryMetric(value: '$heartRate', label: 'FC máxima'),
            if (execution.sets.any(
              (set) => set.blockFormat == WorkoutBlockFormat.running,
            ))
              _SummaryMetric(
                value: runningAssessmentLabel(
                  assessRunningExecution(execution.sets),
                ),
                label: 'Comparación con la pauta',
                width: 230,
              ),
            if (execution.sets.any(
              (s) => s.blockFormat == WorkoutBlockFormat.running,
            ))
              SizedBox(
                width: double.infinity,
                child: Text(
                  [
                    ...runningAssessmentDifferences(execution.sets),
                    'Comparamos los datos registrados con la pauta. No es una nota de calidad ni la puntuación de Garmin. Para calcular el ritmo usamos el tiempo original del reloj cuando está disponible.',
                  ].join('\n'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    this.width = 105,
  });

  final String value;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFA06F),
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  const _ExerciseResultCard(
    this.group, {
    super.key,
    required this.isCorrecting,
    required this.expanded,
    required this.onToggle,
  });

  final _ExerciseGroup group;
  final bool isCorrecting;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final format = group.sets.first.blockFormat;
    final (formatName, color) = _resultFormatStyle(format);
    final completed = group.sets
        .where((set) => set.status == WorkoutSetStatus.completed)
        .toList();
    final skipped = group.sets
        .where((set) => set.status == WorkoutSetStatus.skipped)
        .length;
    final pending = group.sets.length - completed.length - skipped;
    final doses = completed.map(_resultDose).toSet();
    final detailsVisible = !group.isFoldable || expanded;
    final heading = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      group.blockName,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          formatName,
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  group.exerciseName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (group.isFoldable) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      '${completed.length}/${group.sets.length} completadas',
                      if (skipped > 0)
                        '$skipped ${skipped == 1 ? 'omitida' : 'omitidas'}',
                      if (pending > 0)
                        '$pending ${pending == 1 ? 'pendiente' : 'pendientes'}',
                    ].join(' · '),
                  ),
                  if (completed.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      doses.length == 1
                          ? 'Realizado · ${completed.length > 1 ? '${completed.length} × ' : ''}${doses.single}'
                          : 'Resultados variables · ver series',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (group.isFoldable) ...[
            const SizedBox(width: 12),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: color,
            ),
          ],
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (group.isFoldable)
                Semantics(
                  button: true,
                  expanded: expanded,
                  child: InkWell(onTap: onToggle, child: heading),
                )
              else
                heading,
              if (detailsVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      for (final set in group.sets) ...[
                        const Divider(height: 1),
                        _SetResultRow(set, isCorrecting: isCorrecting),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetResultRow extends StatelessWidget {
  const _SetResultRow(this.set, {required this.isCorrecting});

  final WorkoutExecutionSet set;
  final bool isCorrecting;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (set.status) {
      WorkoutSetStatus.completed => Colors.greenAccent,
      WorkoutSetStatus.skipped => Colors.orangeAccent,
      WorkoutSetStatus.pending => Colors.white38,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.15),
            ),
            child: Text('${set.setOrder + 1}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Objetivo · ${_target(set)}'),
                const SizedBox(height: 3),
                Text(_result(set), style: TextStyle(color: statusColor)),
              ],
            ),
          ),
          if (set.canBeCorrectedAt(DateTime.now()))
            IconButton(
              tooltip: 'Corregir resultado',
              onPressed: isCorrecting
                  ? null
                  : () => _requestCorrection(context),
              icon: isCorrecting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined),
            ),
        ],
      ),
    );
  }

  Future<void> _requestCorrection(BuildContext context) async {
    final correction = await showDialog<WorkoutSetCorrectionInput>(
      context: context,
      builder: (dialogContext) => set.performancePrescription == null
          ? _CorrectionDialog(set: set)
          : AlertDialog(
              title: Text('Corregir ${set.exerciseName}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: PerformanceResultForm(
                    prescription: set.performancePrescription!,
                    initialResult: set.performanceResult,
                    correction: true,
                    onSave: (result, reason) => Navigator.of(dialogContext).pop(
                      WorkoutSetCorrectionInput(
                        resultId: set.id,
                        reason: reason,
                        performanceResult: result,
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
    );
    if (correction != null && context.mounted) {
      await context.read<WorkoutHistoryDetailCubit>().correct(correction);
    }
  }
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.set});

  final WorkoutExecutionSet set;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reps;
  late final TextEditingController _duration;
  late final TextEditingController _distance;
  late final TextEditingController _load;
  late final TextEditingController _recoveryDuration;
  late final TextEditingController _recoveryDistance;
  late final TextEditingController _reason;
  double? _rpe;
  double? _rir;

  WorkoutExecutionSet get set => widget.set;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: _integer(set.actualReps));
    _duration = TextEditingController(
      text:
          set.blockFormat == WorkoutBlockFormat.running &&
              set.actualDurationSeconds != null
          ? _pace(set.actualDurationSeconds!)
          : _integer(set.actualDurationSeconds),
    );
    _distance = TextEditingController(
      text: _nullableNumber(set.actualDistanceMeters),
    );
    _load = TextEditingController(text: _nullableNumber(set.actualLoadKg));
    _recoveryDuration = TextEditingController(
      text: set.actualRecoveryDurationSeconds == null
          ? ''
          : _pace(set.actualRecoveryDurationSeconds!),
    );
    _recoveryDistance = TextEditingController(
      text: _nullableNumber(set.actualRecoveryDistanceMeters),
    );
    _reason = TextEditingController();
    _rpe = set.actualRpe;
    _rir = set.actualRir;
  }

  @override
  void dispose() {
    _reps.dispose();
    _duration.dispose();
    _distance.dispose();
    _load.dispose();
    _recoveryDuration.dispose();
    _recoveryDistance.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      WorkoutSetCorrectionInput(
        resultId: set.id,
        reason: _reason.text.trim(),
        actualReps: set.targetReps == null
            ? null
            : _parseDecimal(_reps.text)!.toInt(),
        actualDurationSeconds:
            set.targetDurationSeconds == null &&
                set.blockFormat != WorkoutBlockFormat.running
            ? null
            : set.blockFormat == WorkoutBlockFormat.running
            ? parseDurationInput(_duration.text)
            : _parseDecimal(_duration.text)!.toInt(),
        actualDistanceMeters:
            set.targetDistanceMeters == null &&
                set.blockFormat != WorkoutBlockFormat.running
            ? null
            : _parseDecimal(_distance.text),
        actualLoadKg: set.targetLoadKg == null
            ? null
            : _parseDecimal(_load.text),
        actualRpe: set.targetRpe == null && set.actualRpe == null ? null : _rpe,
        // Corregir otro dato no elimina ni redondea un esfuerzo antiguo.
        actualRir: set.usesRir ? _rir : set.actualRir,
        actualRecoveryDurationSeconds: set.recoveryDurationSeconds == null
            ? null
            : parseDurationInput(_recoveryDuration.text),
        actualRecoveryDistanceMeters: set.recoveryDistanceMeters == null
            ? null
            : _parseDecimal(_recoveryDistance.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Corregir · ${set.exerciseName}'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Disponible durante 24 horas y con un máximo de tres cambios por serie.',
                ),
                const SizedBox(height: 16),
                if (set.targetReps != null)
                  _CorrectionField(
                    controller: _reps,
                    label: 'Repeticiones realizadas',
                    decimal: false,
                  ),
                if (set.targetDurationSeconds != null ||
                    set.blockFormat == WorkoutBlockFormat.running)
                  set.blockFormat == WorkoutBlockFormat.running
                      ? _DurationCorrectionField(
                          controller: _duration,
                          label: 'Tiempo real',
                        )
                      : _CorrectionField(
                          controller: _duration,
                          label: 'Segundos realizados',
                          decimal: false,
                        ),
                if (set.targetDistanceMeters != null ||
                    set.blockFormat == WorkoutBlockFormat.running)
                  _CorrectionField(
                    controller: _distance,
                    label: 'Metros realizados',
                  ),
                if (set.targetLoadKg != null)
                  _CorrectionField(
                    controller: _load,
                    label: 'Carga utilizada (kg)',
                  ),
                if (set.recoveryDurationSeconds != null)
                  _DurationCorrectionField(
                    controller: _recoveryDuration,
                    label: 'Recuperación real',
                  ),
                if (set.recoveryDistanceMeters != null)
                  _CorrectionField(
                    controller: _recoveryDistance,
                    label: 'Metros reales de recuperación',
                  ),
                if (set.targetRpe != null || set.actualRpe != null) ...[
                  WorkoutEffortField(
                    label: 'RPE real',
                    minimum: 1,
                    wholeNumbersOnly: true,
                    value: _rpe,
                    enabled: true,
                    onChanged: (value) => setState(() => _rpe = value),
                  ),
                ],
                if (set.usesRir &&
                    (set.targetRir != null || set.actualRir != null))
                  WorkoutEffortField(
                    label: 'RIR real',
                    minimum: 0,
                    value: _rir,
                    enabled: true,
                    onChanged: (value) => setState(() => _rir = value),
                  ),
                TextFormField(
                  controller: _reason,
                  maxLength: 300,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    hintText: 'Por ejemplo: anoté 8, pero fueron 10.',
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    return length < 3 ? 'Explica brevemente el cambio' : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar corrección')),
      ],
    );
  }
}

class _CorrectionField extends StatelessWidget {
  const _CorrectionField({
    required this.controller,
    required this.label,
    this.decimal = true,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final parsed = _parseDecimal(value ?? '');
          if (parsed == null) return 'Introduce un número válido';
          if (parsed < 0) return 'El valor no puede ser negativo';
          if (!decimal && parsed != parsed.roundToDouble()) {
            return 'Introduce un número entero';
          }
          return null;
        },
      ),
    );
  }
}

class _DurationCorrectionField extends StatelessWidget {
  const _DurationCorrectionField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: const [DurationInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          helperText: 'Min:seg. Escribe 128 para registrar 1:28.',
        ),
        validator: (value) {
          final seconds = parseDurationInput(value ?? '');
          return seconds == null || seconds <= 0
              ? 'Introduce un tiempo válido'
              : null;
        },
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _ExerciseGroup {
  const _ExerciseGroup({
    required this.blockName,
    required this.exerciseName,
    required this.sets,
    this.originalKey,
  });

  final String? originalKey;
  final String blockName;
  final String exerciseName;
  final List<WorkoutExecutionSet> sets;
  String get key =>
      originalKey ??
      '${sets.first.blockOrder}:${sets.first.itemOrder}:${sets.first.exerciseId}:${sets.first.id}';
  bool get isFoldable => sets.first.blockFormat != WorkoutBlockFormat.running;
}

class _AmrapBlock {
  const _AmrapBlock({
    required this.blockOrder,
    required this.blockName,
    required this.exercises,
  });

  final int blockOrder;
  final String blockName;
  final List<WorkoutExecutionSet> exercises;
}

List<_AmrapBlock> _groupAmrapBlocks(List<WorkoutExecutionSet> sets) {
  final blocks = <int, _AmrapBlock>{};
  for (final set in sets.where(
    (item) => item.blockFormat == WorkoutBlockFormat.amrap,
  )) {
    final block = blocks.putIfAbsent(
      set.blockOrder,
      () => _AmrapBlock(
        blockOrder: set.blockOrder,
        blockName: set.blockName,
        exercises: [],
      ),
    );
    if (!block.exercises.any((item) => item.itemOrder == set.itemOrder)) {
      block.exercises.add(set);
    }
  }
  return blocks.values.toList(growable: false);
}

List<_ExerciseGroup> _groupSets(List<WorkoutExecutionSet> sets) {
  final groups = <_ExerciseGroup>[];
  for (final set in sets) {
    final last = groups.isEmpty ? null : groups.last;
    if (last != null &&
        last.sets.first.exerciseId == set.exerciseId &&
        last.sets.first.itemOrder == set.itemOrder &&
        last.sets.first.blockOrder == set.blockOrder &&
        last.sets.first.blockFormat == set.blockFormat) {
      last.sets.add(set);
    } else {
      groups.add(
        _ExerciseGroup(
          blockName: set.blockName,
          exerciseName: set.exerciseName,
          sets: [set],
        ),
      );
    }
  }
  return groups;
}

(String, Color) _resultFormatStyle(WorkoutBlockFormat format) =>
    switch (format) {
      WorkoutBlockFormat.straightSets => (
        'Por series',
        const Color(0xff82b1ff),
      ),
      WorkoutBlockFormat.superset => ('Superserie', const Color(0xffce93d8)),
      WorkoutBlockFormat.circuit => ('Circuito', const Color(0xff80cbc4)),
      WorkoutBlockFormat.intervals => ('Intervalos', const Color(0xffffb74d)),
      WorkoutBlockFormat.emom => ('EMOM', const Color(0xff81d4fa)),
      WorkoutBlockFormat.amrap => ('AMRAP', const Color(0xffffd54f)),
      WorkoutBlockFormat.tabata => ('Tabata', const Color(0xffef9a9a)),
      WorkoutBlockFormat.warmUp => ('Calentamiento', const Color(0xffffb74d)),
      WorkoutBlockFormat.coolDown => ('Enfriamiento', const Color(0xff80cbc4)),
      WorkoutBlockFormat.running => ('Carrera', const Color(0xffff9c68)),
    };

String _resultDose(WorkoutExecutionSet set) {
  // Resumimos solo mediciones uniformes; las excepciones quedan en cada serie.
  if (set.performancePrescription == null && set.actualReps != null) {
    return '${set.actualReps} rep${set.actualLoadKg == null ? '' : ' · ${_number(set.actualLoadKg!)} kg'}';
  }
  final result = _result(set);
  final dose = result.startsWith('Realizado · ')
      ? result.substring('Realizado · '.length)
      : result;
  return dose.isEmpty ? 'Sin valores registrados' : dose;
}

String _target(WorkoutExecutionSet set) {
  if (set.performancePrescription case final p?) {
    if (p.intent == 'control') {
      return p.measurement == 'DURATION'
          ? 'Control con techo de ${_number(p.targetValue)} ${p.unit}'
          : 'Control del protocolo, sin marca obligatoria';
    }
    return '${_number(p.targetValue)} ${p.unit}';
  }
  final parts = <String>[];
  if (set.runningStep != null) {
    parts.add(set.runningStep!.kind.label);
    if (set.runningStep!.completion == RunningStepCompletion.manual) {
      parts.add('Hasta avance manual');
    }
  }
  if (set.targetReps != null) parts.add('${set.targetReps} rep');
  if (set.targetDurationSeconds != null) {
    parts.add(workoutClock(set.targetDurationSeconds!));
  }
  if (set.targetDistanceMeters != null) {
    parts.add('${_number(set.targetDistanceMeters!)} m');
  }
  if (set.targetLoadKg != null) parts.add('${_number(set.targetLoadKg!)} kg');
  if (set.targetRir != null) parts.add('RIR ${_number(set.targetRir!)}');
  if (set.targetPaceMinSecondsPerKm != null) {
    final fastest = set.targetPaceMinSecondsPerKm!;
    final slowest = set.targetPaceMaxSecondsPerKm!;
    parts.add(
      fastest == slowest
          ? '${_pace(fastest)}/km'
          : '${_pace(fastest)}–${_pace(slowest)}/km',
    );
  }
  if (set.recoveryType != null) {
    final mode = switch (set.recoveryType!) {
      RunningRecoveryType.passive => 'pasiva',
      RunningRecoveryType.walking => 'andando',
      RunningRecoveryType.jogging => 'trotando',
    };
    final measure = set.recoveryDurationSeconds != null
        ? _shortDuration(set.recoveryDurationSeconds!)
        : '${_number(set.recoveryDistanceMeters!)} m';
    parts.add('rec. $mode $measure');
  }
  return parts.join(' · ');
}

String _result(WorkoutExecutionSet set) {
  if (set.performancePrescription case final p?) {
    if (set.status == WorkoutSetStatus.skipped) return 'Omitida';
    final r = set.performanceResult;
    if (r == null) return 'Sin resultado';
    return '${r.succeeded != null
            ? (r.succeeded! ? 'Intento conseguido' : 'Intento no conseguido')
            : r.value == null
            ? 'Medición no declarada'
            : '${_number(r.value!)} ${p.unit}'}'
        ' · ${r.techniqueValid == null
            ? 'Validez sin confirmar'
            : r.techniqueValid!
            ? 'Técnica válida'
            : 'Intento no válido'}'
        '${r.rir == null ? '' : ' · RIR ${_number(r.rir!)}'}';
  }
  if (set.status == WorkoutSetStatus.skipped) {
    return set.blockFormat == WorkoutBlockFormat.running
        ? 'Tramo omitido'
        : 'Serie omitida';
  }
  if (set.status == WorkoutSetStatus.pending) return 'No realizada';
  final parts = <String>[];
  if (set.actualReps != null) parts.add('${set.actualReps} rep');
  if (set.actualDurationSeconds != null) {
    parts.add(
      set.resultSource == WorkoutResultSource.device &&
              set.observedDurationSeconds != null
          ? formatPerformanceTime(set.observedDurationSeconds!)
          : workoutClock(set.actualDurationSeconds!),
    );
  }
  if (set.actualDistanceMeters != null) {
    parts.add('${_number(set.actualDistanceMeters!)} m');
  }
  if (set.actualLoadKg != null) parts.add('${_number(set.actualLoadKg!)} kg');
  if (set.actualRir != null) parts.add('RIR ${_number(set.actualRir!)}');
  if (set.blockFormat == WorkoutBlockFormat.running &&
      set.actualDurationSeconds != null &&
      set.actualDistanceMeters != null &&
      set.actualDistanceMeters! > 0) {
    final pace =
        (set.measuredDurationSeconds! * 1000 / set.actualDistanceMeters!)
            .round();
    parts.add('${_pace(pace)}/km');
  }
  if (set.actualRecoveryDurationSeconds != null) {
    parts.add('rec. ${_shortDuration(set.actualRecoveryDurationSeconds!)}');
  }
  if (set.actualRecoveryDistanceMeters != null) {
    parts.add('rec. ${_number(set.actualRecoveryDistanceMeters!)} m');
  }
  return 'Realizado · ${parts.join(' · ')}';
}

String _pace(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

String _shortDuration(int seconds) => workoutClock(seconds);

String _reasonLabel(WorkoutAbandonmentReason reason) => switch (reason) {
  WorkoutAbandonmentReason.lackOfTime => 'Falta de tiempo',
  WorkoutAbandonmentReason.tooDifficult => 'Demasiada dificultad',
  WorkoutAbandonmentReason.discomfort => 'Molestias',
  WorkoutAbandonmentReason.other => 'Otro motivo',
};

String _compactDuration(Duration duration) {
  return workoutClock(duration.inSeconds);
}

String _number(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

String _integer(int? value) => value?.toString() ?? '';

String _nullableNumber(double? value) => value == null ? '' : _number(value);

double? _parseDecimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

final _dateFormat = DateFormat('dd/MM/yyyy · HH:mm');
