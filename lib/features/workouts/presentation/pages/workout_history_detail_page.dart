import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/services/running_execution_assessment.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:intl/intl.dart';

class WorkoutHistoryDetailPage extends StatelessWidget {
  const WorkoutHistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Detalle de la sesión'),
      ),
      body: BlocConsumer<WorkoutHistoryDetailCubit, WorkoutHistoryDetailState>(
        listener: (context, state) {
          final message = state.correctionMessage;
          if (message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
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

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.execution, required this.isCorrecting});

  final WorkoutExecution execution;
  final bool isCorrecting;

  @override
  Widget build(BuildContext context) {
    final amrapBlocks = _groupAmrapBlocks(execution.sets);
    final groups = _groupSets(
      execution.sets
          .where((set) => set.blockFormat != WorkoutBlockFormat.amrap)
          .toList(growable: false),
    );
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
                if (execution.notes case final notes?) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF171717),
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
                const Text(
                  'Objetivo y resultado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...amrapBlocks.map(
                  (block) => _AmrapResultCard(
                    block: block,
                    result: execution.amrapResultFor(block.blockOrder),
                  ),
                ),
                ...groups.map(
                  (group) =>
                      _ExerciseResultCard(group, isCorrecting: isCorrecting),
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
      color: const Color(0xFF171717),
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
              if (partialExercise != null && result!.partialReps > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Parcial · ${partialExercise.exerciseName}: '
                  '${result!.partialReps} rep',
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
    final duration = completedAt?.difference(execution.startedAt);
    return Card(
      color: const Color(0xFF171717),
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
                label: 'Duración',
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
                label: 'Cumplimiento',
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 105,
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
  const _ExerciseResultCard(this.group, {required this.isCorrecting});

  final _ExerciseGroup group;
  final bool isCorrecting;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              group.blockName.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFF8A50),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              group.exerciseName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...group.sets.map(
              (set) => _SetResultRow(set, isCorrecting: isCorrecting),
            ),
          ],
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
      builder: (_) => _CorrectionDialog(set: set),
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
  late double _rpe;
  late double _rir;

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
    _rpe = (set.actualRpe ?? set.targetRpe ?? 7).clamp(1, 10).toDouble();
    _rir = (set.actualRir ?? set.targetRir ?? 2).clamp(0, 10).toDouble();
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
        actualRir: set.targetRir == null && set.actualRir == null ? null : _rir,
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
                  Text('RPE real · ${_number(_rpe)}'),
                  Slider(
                    value: _rpe,
                    min: 1,
                    max: 10,
                    divisions: 18,
                    onChanged: (value) => setState(() => _rpe = value),
                  ),
                ],
                if (set.targetRir != null || set.actualRir != null) ...[
                  Text('RIR real · ${_number(_rir)}'),
                  Slider(
                    value: _rir,
                    min: 0,
                    max: 10,
                    divisions: 20,
                    onChanged: (value) => setState(() => _rir = value),
                  ),
                ],
                TextFormField(
                  controller: _reason,
                  maxLength: 300,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la corrección',
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
          labelText: '$label (min:seg)',
          helperText: 'Escribe 128 para registrar 1:28.',
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
  });

  final String blockName;
  final String exerciseName;
  final List<WorkoutExecutionSet> sets;
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
        last.sets.first.blockOrder == set.blockOrder) {
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

String _target(WorkoutExecutionSet set) {
  final parts = <String>[];
  if (set.targetReps != null) parts.add('${set.targetReps} rep');
  if (set.targetDurationSeconds != null) {
    parts.add('${set.targetDurationSeconds} s');
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
  if (set.status == WorkoutSetStatus.skipped) {
    return set.blockFormat == WorkoutBlockFormat.running
        ? 'Tramo omitido'
        : 'Serie omitida';
  }
  if (set.status == WorkoutSetStatus.pending) return 'No realizada';
  final parts = <String>[];
  if (set.actualReps != null) parts.add('${set.actualReps} rep');
  if (set.actualDurationSeconds != null) {
    parts.add('${set.actualDurationSeconds} s');
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
    final pace = (set.actualDurationSeconds! * 1000 / set.actualDistanceMeters!)
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
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String _shortDuration(int seconds) => seconds < 60
    ? '$seconds s'
    : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min';

String _reasonLabel(WorkoutAbandonmentReason reason) => switch (reason) {
  WorkoutAbandonmentReason.lackOfTime => 'Falta de tiempo',
  WorkoutAbandonmentReason.tooDifficult => 'Demasiada dificultad',
  WorkoutAbandonmentReason.discomfort => 'Molestias',
  WorkoutAbandonmentReason.other => 'Otro motivo',
};

String _compactDuration(Duration duration) {
  if (duration.inMinutes < 1) return '<1 min';
  if (duration.inHours < 1) return '${duration.inMinutes} min';
  final minutes = duration.inMinutes.remainder(60);
  return minutes == 0
      ? '${duration.inHours} h'
      : '${duration.inHours} h $minutes min';
}

String _number(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

String _integer(int? value) => value?.toString() ?? '';

String _nullableNumber(double? value) => value == null ? '' : _number(value);

double? _parseDecimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

final _dateFormat = DateFormat('dd/MM/yyyy · HH:mm');
