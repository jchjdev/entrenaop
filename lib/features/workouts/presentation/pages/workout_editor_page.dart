import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WorkoutEditorPage extends StatefulWidget {
  const WorkoutEditorPage({super.key});

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final List<_ExerciseRowData> _rows = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutEditorCubit, WorkoutEditorState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.status == WorkoutEditorStatus.saved) {
          context.pop(state.createdTemplateId);
        } else if (state.errorMessage case final message?) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final saving = state.status == WorkoutEditorStatus.saving;
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Volver',
              onPressed: saving ? null : context.pop,
              icon: const Icon(Icons.close_rounded),
            ),
            title: const Text('Nueva sesión'),
            actions: [
              TextButton(
                onPressed: saving ? null : () => _save(context),
                child: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: switch (state.status) {
            WorkoutEditorStatus.initial || WorkoutEditorStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            WorkoutEditorStatus.failure when state.exercises.isEmpty =>
              _LoadFailure(onRetry: context.read<WorkoutEditorCubit>().load),
            _ => _buildForm(context, state.exercises, saving),
          },
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<ExerciseEntity> catalog,
    bool saving,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Diseña tu entrenamiento',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Crea una sesión privada. Después podrás abrirla y entrenarla con el mismo motor guiado.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la sesión',
                      hintText: 'Ej. Tirón y dominadas',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      return length < 3 || length > 80
                          ? 'Escribe un nombre de 3 a 80 caracteres.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Objetivo o indicaciones generales',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      controller: _durationController,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duración estimada',
                        suffixText: 'min',
                        prefixIcon: Icon(Icons.schedule_rounded),
                      ),
                      validator: (value) => _integerValidator(
                        value,
                        min: 1,
                        max: 600,
                        label: 'duración',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ejercicios',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text('${_rows.length}/20'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_rows.isEmpty)
                    _EmptyExercises(
                      onAdd: catalog.isEmpty || saving
                          ? null
                          : () => _chooseExercise(context, catalog),
                    )
                  else
                    ...List.generate(
                      _rows.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExerciseEditorCard(
                          key: ValueKey(_rows[index].exercise.id),
                          index: index,
                          data: _rows[index],
                          enabled: !saving,
                          onRemove: () => setState(() => _rows.removeAt(index)),
                          onMoveUp: index == 0
                              ? null
                              : () => _move(index, index - 1),
                          onMoveDown: index == _rows.length - 1
                              ? null
                              : () => _move(index, index + 1),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: catalog.isEmpty || saving || _rows.length >= 20
                        ? null
                        : () => _chooseExercise(context, catalog),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Añadir ejercicio'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: saving ? null : () => _save(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Text('Guardar sesión'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _move(int from, int to) {
    setState(() {
      final row = _rows.removeAt(from);
      _rows.insert(to, row);
    });
  }

  Future<void> _chooseExercise(
    BuildContext context,
    List<ExerciseEntity> catalog,
  ) async {
    final selectedIds = _rows.map((row) => row.exercise.id).toSet();
    final available = catalog
        .where((exercise) => !selectedIds.contains(exercise.id))
        .toList();
    final selected = await showModalBottomSheet<ExerciseEntity>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ExercisePicker(exercises: available),
    );
    if (selected != null && mounted) {
      setState(() => _rows.add(_ExerciseRowData.fromExercise(selected)));
    }
  }

  void _save(BuildContext context) {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un ejercicio.')),
      );
      return;
    }
    final input = CreatePersonalWorkoutInput(
      name: _nameController.text,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text,
      estimatedDurationMinutes: int.tryParse(_durationController.text),
      exercises: _rows.map((row) => row.toDraft()).toList(),
    );
    context.read<WorkoutEditorCubit>().save(input);
  }
}

class _ExerciseRowData {
  _ExerciseRowData({
    required this.exercise,
    required this.targetType,
    required this.targetValue,
  });

  factory _ExerciseRowData.fromExercise(ExerciseEntity exercise) {
    final type = exercise.exerciseType.toLowerCase().contains('dur')
        ? WorkoutTargetType.duration
        : WorkoutTargetType.repetitions;
    return _ExerciseRowData(
      exercise: exercise,
      targetType: type,
      targetValue: type == WorkoutTargetType.duration ? 30 : 10,
    );
  }

  final ExerciseEntity exercise;
  WorkoutTargetType targetType;
  int setCount = 3;
  double targetValue;
  int restSeconds = 60;
  double? loadKg;
  double? rir = 2;

  WorkoutExerciseDraft toDraft() => WorkoutExerciseDraft(
    exerciseId: exercise.id,
    sets: List.generate(
      setCount,
      (_) => WorkoutSetDraft(
        targetType: targetType,
        targetValue: targetValue,
        restAfterSeconds: restSeconds,
        targetLoadKg: loadKg,
        targetRir: rir,
      ),
    ),
  );
}

class _ExerciseEditorCard extends StatefulWidget {
  const _ExerciseEditorCard({
    super.key,
    required this.index,
    required this.data,
    required this.enabled,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final _ExerciseRowData data;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<_ExerciseEditorCard> createState() => _ExerciseEditorCardState();
}

class _ExerciseEditorCardState extends State<_ExerciseEditorCard> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0x33FF8A50),
                  foregroundColor: const Color(0xFFFF8A50),
                  child: Text('${widget.index + 1}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Subir',
                  onPressed: widget.enabled ? widget.onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'Bajar',
                  onPressed: widget.enabled ? widget.onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: widget.enabled ? widget.onRemove : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkoutTargetType>(
              initialValue: data.targetType,
              decoration: const InputDecoration(
                labelText: 'Objetivo principal',
              ),
              items: const [
                DropdownMenuItem(
                  value: WorkoutTargetType.repetitions,
                  child: Text('Repeticiones'),
                ),
                DropdownMenuItem(
                  value: WorkoutTargetType.duration,
                  child: Text('Tiempo'),
                ),
                DropdownMenuItem(
                  value: WorkoutTargetType.distance,
                  child: Text('Distancia'),
                ),
              ],
              onChanged: widget.enabled
                  ? (value) => setState(() {
                      if (value == null) return;
                      data.targetType = value;
                      data.targetValue = switch (value) {
                        WorkoutTargetType.repetitions => 10,
                        WorkoutTargetType.duration => 30,
                        WorkoutTargetType.distance => 1000,
                      };
                    })
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _NumberField(
                  label: 'Series',
                  initialValue: data.setCount.toString(),
                  suffix: null,
                  enabled: widget.enabled,
                  integer: true,
                  min: 1,
                  max: 20,
                  onChanged: (value) => data.setCount = value.round(),
                ),
                _NumberField(
                  key: ValueKey(data.targetType),
                  label: switch (data.targetType) {
                    WorkoutTargetType.repetitions => 'Repeticiones',
                    WorkoutTargetType.duration => 'Tiempo',
                    WorkoutTargetType.distance => 'Distancia',
                  },
                  initialValue: _numberText(data.targetValue),
                  suffix: switch (data.targetType) {
                    WorkoutTargetType.repetitions => 'reps',
                    WorkoutTargetType.duration => 's',
                    WorkoutTargetType.distance => 'm',
                  },
                  enabled: widget.enabled,
                  integer: data.targetType != WorkoutTargetType.distance,
                  min: 0.01,
                  max: 100000,
                  onChanged: (value) => data.targetValue = value,
                ),
                _NumberField(
                  label: 'Descanso',
                  initialValue: data.restSeconds.toString(),
                  suffix: 's',
                  enabled: widget.enabled,
                  integer: true,
                  min: 0,
                  max: 3600,
                  onChanged: (value) => data.restSeconds = value.round(),
                ),
                _NumberField(
                  label: 'Carga',
                  initialValue: data.loadKg == null
                      ? ''
                      : _numberText(data.loadKg!),
                  suffix: 'kg',
                  enabled: widget.enabled,
                  optional: true,
                  min: 0,
                  max: 1000,
                  onChanged: (value) => data.loadKg = value,
                  onCleared: () => data.loadKg = null,
                ),
                _NumberField(
                  label: 'RIR',
                  initialValue: data.rir == null ? '' : _numberText(data.rir!),
                  suffix: null,
                  enabled: widget.enabled,
                  optional: true,
                  min: 0,
                  max: 10,
                  onChanged: (value) => data.rir = value,
                  onCleared: () => data.rir = null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Por ahora todas las series de este ejercicio comparten objetivo. La edición serie a serie llegará en el siguiente nivel del creador.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.suffix,
    required this.enabled,
    required this.min,
    required this.max,
    required this.onChanged,
    this.integer = false,
    this.optional = false,
    this.onCleared,
  });

  final String label;
  final String initialValue;
  final String? suffix;
  final bool enabled;
  final bool integer;
  final bool optional;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: TextFormField(
        initialValue: initialValue,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        validator: (value) {
          final normalized = value?.trim().replaceAll(',', '.') ?? '';
          if (normalized.isEmpty && optional) return null;
          final number = double.tryParse(normalized);
          if (number == null || number < min || number > max) {
            return 'Entre ${_numberText(min)} y ${_numberText(max)}';
          }
          if (integer && number != number.roundToDouble()) {
            return 'Usa un entero';
          }
          return null;
        },
        onChanged: (value) {
          final normalized = value.trim().replaceAll(',', '.');
          if (normalized.isEmpty) {
            onCleared?.call();
            return;
          }
          final number = double.tryParse(normalized);
          if (number != null) onChanged(number);
        },
      ),
    );
  }
}

class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker({required this.exercises});

  final List<ExerciseEntity> exercises;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Elige un ejercicio',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: exercises.isEmpty
                  ? const Center(
                      child: Text('Ya has añadido todos los ejercicios.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: exercises.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        return ListTile(
                          leading: const Icon(Icons.fitness_center_rounded),
                          title: Text(exercise.name),
                          subtitle: exercise.muscleGroups.isEmpty
                              ? null
                              : Text(exercise.muscleGroups.join(' · ')),
                          trailing: const Icon(
                            Icons.add_circle_outline_rounded,
                          ),
                          onTap: () => context.pop(exercise),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyExercises extends StatelessWidget {
  const _EmptyExercises({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151515),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.playlist_add_rounded, size: 42),
            const SizedBox(height: 10),
            const Text(
              'La sesión todavía está vacía',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Añade ejercicios y define sus series.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Primer ejercicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    );
  }
}

String? _integerValidator(
  String? value, {
  required int min,
  required int max,
  required String label,
}) {
  final number = int.tryParse(value?.trim() ?? '');
  return number == null || number < min || number > max
      ? 'Revisa la $label.'
      : null;
}

String _numberText(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();
