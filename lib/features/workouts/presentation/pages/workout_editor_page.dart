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
  final List<_BlockRowData> _blocks = [_BlockRowData(name: 'Principal')];
  bool _didPopulateTemplate = false;

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
        if (state.status == WorkoutEditorStatus.ready &&
            state.originalTemplate != null &&
            !_didPopulateTemplate) {
          _populateTemplate(state.originalTemplate!, state.exercises);
        } else if (state.status == WorkoutEditorStatus.saved) {
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
            title: Text(
              state.originalTemplate == null ? 'Nueva sesión' : 'Editar sesión',
            ),
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
            _ => _buildForm(
              context,
              state.exercises,
              saving,
              state.originalTemplate,
            ),
          },
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<ExerciseEntity> catalog,
    bool saving,
    WorkoutTemplate? originalTemplate,
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
                  Text(
                    originalTemplate == null
                        ? 'Diseña tu entrenamiento'
                        : 'Actualiza tu entrenamiento',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    originalTemplate == null
                        ? 'Crea una sesión privada. Después podrás abrirla y entrenarla con el mismo motor guiado.'
                        : 'Guardaremos una versión nueva. Tus entrenamientos anteriores seguirán vinculados a la versión que realizaste.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  if (originalTemplate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFF8A50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Versión actual ${originalTemplate.version} · se creará la versión ${originalTemplate.version + 1}',
                        style: const TextStyle(
                          color: Color(0xFFFFB08A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
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
                          'Bloques de la sesión',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text('${_blocks.length}/10'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Agrupa el calentamiento, el trabajo principal o los accesorios como prefieras.',
                    style: TextStyle(color: Colors.white54, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    _blocks.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildBlockEditor(context, catalog, index, saving),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    key: const ValueKey('add-workout-block'),
                    onPressed: saving || _blocks.length >= 10
                        ? null
                        : _addBlock,
                    icon: const Icon(Icons.view_agenda_outlined),
                    label: const Text('Añadir bloque'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: saving ? null : () => _save(context),
                    icon: const Icon(Icons.check_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        originalTemplate == null
                            ? 'Guardar sesión'
                            : 'Guardar nueva versión',
                      ),
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

  Widget _buildBlockEditor(
    BuildContext context,
    List<ExerciseEntity> catalog,
    int blockIndex,
    bool saving,
  ) {
    final block = _blocks[blockIndex];
    return Card(
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0x33FF8A50),
                  foregroundColor: const Color(0xFFFF8A50),
                  child: Text('${blockIndex + 1}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: ValueKey(block),
                    initialValue: block.name,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del bloque',
                      isDense: true,
                    ),
                    maxLength: 60,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ponle un nombre al bloque.'
                        : null,
                    onChanged: (value) => block.name = value,
                  ),
                ),
                PopupMenuButton<int>(
                  enabled: !saving,
                  tooltip: 'Organizar bloque',
                  onSelected: (value) {
                    if (value == -1) {
                      _moveBlock(blockIndex, blockIndex - 1);
                    }
                    if (value == -2) {
                      _moveBlock(blockIndex, blockIndex + 1);
                    }
                    if (value == -3) _removeBlock(context, blockIndex);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: -1,
                      enabled: blockIndex > 0,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.arrow_upward_rounded),
                        title: Text('Subir bloque'),
                      ),
                    ),
                    PopupMenuItem(
                      value: -2,
                      enabled: blockIndex < _blocks.length - 1,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.arrow_downward_rounded),
                        title: Text('Bajar bloque'),
                      ),
                    ),
                    PopupMenuItem(
                      value: -3,
                      enabled: _blocks.length > 1,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Eliminar bloque'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<WorkoutBlockFormat>(
              key: ValueKey('format-${block.identity}-${block.format}'),
              isExpanded: true,
              initialValue: block.format,
              decoration: const InputDecoration(
                labelText: 'Formato del bloque',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: WorkoutBlockFormat.straightSets,
                  child: Text('Series convencionales'),
                ),
                const DropdownMenuItem(
                  value: WorkoutBlockFormat.superset,
                  child: Text('Superserie'),
                ),
                const DropdownMenuItem(
                  value: WorkoutBlockFormat.circuit,
                  child: Text('Circuito'),
                ),
                DropdownMenuItem(
                  value: WorkoutBlockFormat.intervals,
                  enabled: block.rows.length <= 1,
                  child: const Text('Intervalos personalizados'),
                ),
                DropdownMenuItem(
                  value: WorkoutBlockFormat.tabata,
                  enabled: block.rows.length <= 1,
                  child: const Text('Tabata · 8 × 20/10'),
                ),
                const DropdownMenuItem(
                  value: WorkoutBlockFormat.emom,
                  child: Text('EMOM · cada minuto'),
                ),
                const DropdownMenuItem(
                  value: WorkoutBlockFormat.amrap,
                  child: Text('AMRAP · máximas vueltas'),
                ),
              ],
              onChanged: saving
                  ? null
                  : (format) {
                      if (format != null) {
                        _changeBlockFormat(context, blockIndex, format);
                      }
                    },
            ),
            if (block.isRoundBased) ...[
              const SizedBox(height: 12),
              if (block.format == WorkoutBlockFormat.tabata)
                const _TabataSummary()
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        key: ValueKey(
                          'rounds-${block.identity}-${block.rounds}',
                        ),
                        initialValue: block.rounds.toString(),
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: switch (block.format) {
                            WorkoutBlockFormat.intervals => 'Intervalos',
                            WorkoutBlockFormat.emom => 'Vueltas',
                            _ => 'Rondas',
                          },
                          prefixIcon: const Icon(Icons.repeat_rounded),
                        ),
                        validator: (value) => _integerValidator(
                          value,
                          min: 1,
                          max: block.maxRounds,
                          label: 'cantidad de rondas',
                        ),
                        onChanged: (value) {
                          final rounds = int.tryParse(value);
                          if (rounds != null &&
                              rounds >= 1 &&
                              rounds <= block.maxRounds) {
                            _changeBlockRounds(blockIndex, rounds);
                          }
                        },
                      ),
                    ),
                    if (block.format != WorkoutBlockFormat.emom)
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          key: ValueKey(
                            'rest-${block.identity}-${block.format}',
                          ),
                          initialValue: block.restAfterSeconds.toString(),
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                block.format == WorkoutBlockFormat.intervals
                                ? 'Recuperación'
                                : 'Descanso entre rondas',
                            suffixText: 's',
                            prefixIcon: const Icon(Icons.timer_outlined),
                          ),
                          validator: (value) => _integerValidator(
                            value,
                            min: 0,
                            max: 3600,
                            label: 'descanso',
                          ),
                          onChanged: (value) {
                            final seconds = int.tryParse(value);
                            if (seconds != null) {
                              block.restAfterSeconds = seconds;
                            }
                          },
                        ),
                      ),
                  ],
                ),
                if (block.format == WorkoutBlockFormat.emom) ...[
                  const SizedBox(height: 10),
                  _EmomSummary(
                    cycles: block.rounds,
                    exerciseCount: block.rows.length,
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Text(switch (block.format) {
                WorkoutBlockFormat.superset =>
                  'Alternaremos exactamente dos ejercicios en cada ronda.',
                WorkoutBlockFormat.circuit =>
                  'Recorreremos todos los ejercicios antes de comenzar la siguiente ronda.',
                WorkoutBlockFormat.intervals =>
                  'Repetiremos un ejercicio con una recuperación común entre intervalos.',
                WorkoutBlockFormat.tabata =>
                  'Formato cerrado: un ejercicio, 8 intervalos de 20 segundos y 10 de recuperación.',
                WorkoutBlockFormat.emom =>
                  'Cada ejercicio ocupa un minuto. Si añades varios, se alternarán y después comenzará una nueva vuelta.',
                _ => '',
              }, style: const TextStyle(color: Colors.white54, height: 1.35)),
            ],
            if (block.format == WorkoutBlockFormat.amrap) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: TextFormField(
                  key: ValueKey(
                    'time-cap-${block.identity}-${block.timeCapSeconds}',
                  ),
                  initialValue: (block.timeCapSeconds ~/ 60).toString(),
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Límite de tiempo',
                    suffixText: 'min',
                    prefixIcon: Icon(Icons.hourglass_bottom_rounded),
                  ),
                  validator: (value) => _integerValidator(
                    value,
                    min: 1,
                    max: 60,
                    label: 'límite de tiempo',
                  ),
                  onChanged: (value) {
                    final minutes = int.tryParse(value);
                    if (minutes != null && minutes >= 1 && minutes <= 60) {
                      block.timeCapSeconds = minutes * 60;
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Repite la secuencia tantas veces como puedas. Guardaremos vueltas completas y el progreso de la última.',
                style: TextStyle(color: Colors.white54, height: 1.35),
              ),
            ],
            if (block.showsSequenceOverview) ...[
              const SizedBox(height: 14),
              _BlockSequenceOverview(block: block),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  catalog.isEmpty ||
                      saving ||
                      block.rows.length >= block.maxExercises ||
                      _exerciseCount >= 40
                  ? null
                  : () => _chooseExercise(context, catalog, blockIndex),
              icon: const Icon(Icons.add_rounded),
              label: Text(block.addExerciseLabel),
            ),
            const SizedBox(height: 12),
            if (block.rows.isEmpty)
              const _EmptyExercises()
            else
              ...List.generate(
                block.rows.length,
                (exerciseIndex) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseEditorCard(
                    key: ValueKey(block.rows[exerciseIndex].identity),
                    index: exerciseIndex,
                    positionLabel: block.positionLabel(exerciseIndex),
                    setSectionLabel: block.setSectionLabel(
                      block.rows[exerciseIndex].sets.length,
                    ),
                    data: block.rows[exerciseIndex],
                    enabled: !saving,
                    fixedSetCount: block.fixedSetCount,
                    fixedTarget: block.format == WorkoutBlockFormat.tabata,
                    moveTargets: [
                      for (final (index, target) in _blocks.indexed)
                        if (index != blockIndex &&
                            target.rows.length < target.maxExercises)
                          (index: index, name: target.name),
                    ],
                    onMoveToBlock: (targetIndex) => _moveExerciseToBlock(
                      blockIndex,
                      exerciseIndex,
                      targetIndex,
                    ),
                    onRemove: () =>
                        setState(() => block.rows.removeAt(exerciseIndex)),
                    onMoveUp: exerciseIndex == 0
                        ? null
                        : () => _moveExercise(
                            blockIndex,
                            exerciseIndex,
                            exerciseIndex - 1,
                          ),
                    onMoveDown: exerciseIndex == block.rows.length - 1
                        ? null
                        : () => _moveExercise(
                            blockIndex,
                            exerciseIndex,
                            exerciseIndex + 1,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _populateTemplate(
    WorkoutTemplate template,
    List<ExerciseEntity> catalog,
  ) {
    final exercisesById = {
      for (final exercise in catalog) exercise.id: exercise,
    };
    final blocks = template.blocks.map((block) {
      final rows = <_ExerciseRowData>[];
      for (final item in block.items) {
        final exercise = exercisesById[item.exerciseId];
        if (exercise == null || item.sets.isEmpty) continue;
        final targetType = _targetTypeOf(item.sets.first);
        if (item.sets.any((set) => _targetTypeOf(set) != targetType)) continue;
        rows.add(
          _ExerciseRowData(
            exercise: exercise,
            targetType: targetType,
            sets: item.sets
                .map(
                  (set) => _SetRowData(
                    targetValue: _targetValueOf(set),
                    restSeconds: set.restAfterSeconds,
                    loadKg: set.targetLoadKg,
                    rir: set.targetRir,
                  ),
                )
                .toList(),
          ),
        );
      }
      return _BlockRowData(
        name: block.name,
        format: block.format,
        rounds: block.rounds,
        timeCapSeconds: block.timeCapSeconds ?? 600,
        restAfterSeconds: block.restAfterSeconds,
        rows: rows,
      );
    }).toList();
    _didPopulateTemplate = true;
    _nameController.text = template.name;
    _descriptionController.text = template.description ?? '';
    _durationController.text =
        template.estimatedDurationMinutes?.toString() ?? '';
    setState(() {
      _blocks
        ..clear()
        ..addAll(blocks);
    });
  }

  int get _exerciseCount =>
      _blocks.fold(0, (count, block) => count + block.rows.length);

  void _addBlock() {
    setState(
      () => _blocks.add(_BlockRowData(name: 'Bloque ${_blocks.length + 1}')),
    );
  }

  void _moveBlock(int from, int to) {
    setState(() {
      final block = _blocks.removeAt(from);
      _blocks.insert(to, block);
    });
  }

  void _changeBlockFormat(
    BuildContext context,
    int index,
    WorkoutBlockFormat format,
  ) {
    final acceptsOneExercise =
        format == WorkoutBlockFormat.intervals ||
        format == WorkoutBlockFormat.tabata;
    if (acceptsOneExercise && _blocks[index].rows.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deja un solo ejercicio en el bloque antes de cambiar a este formato.',
          ),
        ),
      );
      return;
    }
    if (format == WorkoutBlockFormat.superset &&
        _blocks[index].rows.length > 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Una superserie tiene dos posiciones. Quita o mueve los demás ejercicios antes de cambiar el formato.',
          ),
        ),
      );
      return;
    }
    setState(() {
      final block = _blocks[index];
      block.format = format;
      if (format == WorkoutBlockFormat.straightSets) {
        block.rounds = 1;
        block.restAfterSeconds = 0;
      } else if (format == WorkoutBlockFormat.tabata) {
        block.rounds = 8;
        block.restAfterSeconds = 10;
        for (final row in block.rows) {
          row.targetType = WorkoutTargetType.duration;
          for (final set in row.sets) {
            set.targetValue = 20;
            set.restSeconds = 0;
          }
        }
        _syncBlockRounds(block);
      } else if (format == WorkoutBlockFormat.emom) {
        if (block.rows.isEmpty) {
          block.rounds = 5;
        } else {
          final capacity = 60 ~/ block.rows.length;
          block.rounds = block.rows.first.sets.length
              .clamp(1, capacity < 20 ? capacity : 20)
              .toInt();
        }
        block.restAfterSeconds = 60;
        _syncBlockRounds(block);
      } else if (format == WorkoutBlockFormat.amrap) {
        block.rounds = 1;
        block.restAfterSeconds = 0;
        block.timeCapSeconds = 600;
        for (final row in block.rows) {
          row.targetType = WorkoutTargetType.repetitions;
          while (row.sets.length > 1) {
            row.sets.removeLast();
          }
          row.sets.single.restSeconds = 0;
        }
      } else {
        block.rounds = block.rows.isEmpty
            ? (format == WorkoutBlockFormat.intervals ? 6 : 3)
            : block.rows.first.sets.length.clamp(1, 20);
        block.restAfterSeconds = block.restAfterSeconds == 0
            ? (format == WorkoutBlockFormat.intervals ? 60 : 90)
            : block.restAfterSeconds;
        _syncBlockRounds(block);
      }
    });
  }

  void _changeBlockRounds(int index, int rounds) {
    setState(() {
      final block = _blocks[index]..rounds = rounds;
      _syncBlockRounds(block);
    });
  }

  void _syncBlockRounds(_BlockRowData block) {
    for (final row in block.rows) {
      while (row.sets.length > block.rounds) {
        row.sets.removeLast();
      }
      while (row.sets.length < block.rounds) {
        row.sets.add(row.sets.last.copy());
      }
    }
  }

  Future<void> _removeBlock(BuildContext context, int index) async {
    if (_blocks[index].rows.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminar bloque'),
          content: const Text(
            'También se quitarán del borrador los ejercicios de este bloque.',
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => dialogContext.pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _blocks.removeAt(index));
  }

  void _moveExercise(int blockIndex, int from, int to) {
    setState(() {
      final rows = _blocks[blockIndex].rows;
      final row = rows.removeAt(from);
      rows.insert(to, row);
    });
  }

  void _moveExerciseToBlock(int fromBlock, int exerciseIndex, int toBlock) {
    setState(() {
      final row = _blocks[fromBlock].rows.removeAt(exerciseIndex);
      final target = _blocks[toBlock];
      target.rows.add(row);
      _adaptRowToBlock(row, target);
    });
  }

  Future<void> _chooseExercise(
    BuildContext context,
    List<ExerciseEntity> catalog,
    int blockIndex,
  ) async {
    final selected = await showModalBottomSheet<ExerciseEntity>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ExercisePicker(exercises: catalog),
    );
    if (selected != null && mounted) {
      setState(() {
        final block = _blocks[blockIndex];
        final row = _ExerciseRowData.fromExercise(selected);
        block.rows.add(row);
        _adaptRowToBlock(row, block);
      });
    }
  }

  void _adaptRowToBlock(_ExerciseRowData row, _BlockRowData block) {
    if (block.format == WorkoutBlockFormat.amrap) {
      row.targetType = WorkoutTargetType.repetitions;
      row.sets = [row.sets.first.copy()..restSeconds = 0];
      return;
    }
    if (!block.isRoundBased) return;
    if (block.format == WorkoutBlockFormat.tabata) {
      row.targetType = WorkoutTargetType.duration;
      row.sets.first
        ..targetValue = 20
        ..restSeconds = 0;
    }
    _syncBlockRounds(block);
    if (block.format == WorkoutBlockFormat.tabata) {
      for (final set in row.sets) {
        set
          ..targetValue = 20
          ..restSeconds = 0;
      }
    }
  }

  void _save(BuildContext context) {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_blocks.any((block) => block.rows.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cada bloque necesita al menos un ejercicio.'),
        ),
      );
      return;
    }
    final input = CreatePersonalWorkoutInput(
      name: _nameController.text,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text,
      estimatedDurationMinutes: int.tryParse(_durationController.text),
      blocks: _blocks.map((block) => block.toDraft()).toList(),
    );
    context.read<WorkoutEditorCubit>().save(input);
  }
}

class _TabataSummary extends StatelessWidget {
  const _TabataSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1FFF8A50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44FF8A50)),
      ),
      child: const Row(
        children: [
          Icon(Icons.timer_rounded, color: Color(0xFFFF8A50)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '8 rondas · 20 s de trabajo · 10 s de recuperación',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmomSummary extends StatelessWidget {
  const _EmomSummary({required this.cycles, required this.exerciseCount});

  final int cycles;
  final int exerciseCount;

  @override
  Widget build(BuildContext context) {
    final minutes = cycles * (exerciseCount == 0 ? 1 : exerciseCount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1F55B9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x4455B9FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.av_timer_rounded, color: Color(0xFF79C8FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exerciseCount == 0
                  ? '$cycles minutos con un ejercicio'
                  : '$minutes minutos · $exerciseCount ${exerciseCount == 1 ? 'ejercicio' : 'ejercicios'} × $cycles ${cycles == 1 ? 'vuelta' : 'vueltas'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockSequenceOverview extends StatelessWidget {
  const _BlockSequenceOverview({required this.block});

  final _BlockRowData block;

  @override
  Widget build(BuildContext context) {
    final slotCount = block.format == WorkoutBlockFormat.superset
        ? 2
        : block.rows.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            block.sequenceTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          if (slotCount == 0)
            Text(
              block.emptySequenceText,
              style: const TextStyle(color: Colors.white54),
            )
          else
            for (var index = 0; index < slotCount; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      child: Text(
                        block.positionLabel(index),
                        style: const TextStyle(
                          color: Color(0xFFFF8A50),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        index < block.rows.length
                            ? block.rows[index].exercise.name
                            : 'Pendiente de elegir',
                        style: TextStyle(
                          color: index < block.rows.length
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BlockRowData {
  _BlockRowData({
    required this.name,
    this.format = WorkoutBlockFormat.straightSets,
    this.rounds = 1,
    this.restAfterSeconds = 0,
    this.timeCapSeconds = 600,
    List<_ExerciseRowData>? rows,
  }) : rows = rows ?? [];

  final Object identity = Object();
  String name;
  WorkoutBlockFormat format;
  int rounds;
  int restAfterSeconds;
  int timeCapSeconds;
  final List<_ExerciseRowData> rows;

  bool get isRoundBased =>
      format == WorkoutBlockFormat.superset ||
      format == WorkoutBlockFormat.circuit ||
      format == WorkoutBlockFormat.intervals ||
      format == WorkoutBlockFormat.tabata ||
      format == WorkoutBlockFormat.emom;

  bool get fixedSetCount => isRoundBased || format == WorkoutBlockFormat.amrap;

  int get maxRounds {
    if (format != WorkoutBlockFormat.emom || rows.isEmpty) return 20;
    final capacity = 60 ~/ rows.length;
    return capacity < 20 ? capacity : 20;
  }

  int get maxExercises => format == WorkoutBlockFormat.superset
      ? 2
      : (format == WorkoutBlockFormat.intervals ||
            format == WorkoutBlockFormat.tabata)
      ? 1
      : format == WorkoutBlockFormat.emom
      ? _emomExerciseCapacity
      : 20;

  int get _emomExerciseCapacity {
    final capacity = 60 ~/ rounds;
    return capacity < 20 ? capacity : 20;
  }

  bool get showsSequenceOverview =>
      format == WorkoutBlockFormat.superset ||
      format == WorkoutBlockFormat.circuit ||
      format == WorkoutBlockFormat.emom ||
      format == WorkoutBlockFormat.amrap;

  String get sequenceTitle => switch (format) {
    WorkoutBlockFormat.superset => 'Pareja de ejercicios',
    WorkoutBlockFormat.circuit => 'Orden de las estaciones',
    WorkoutBlockFormat.emom => 'Orden de los minutos',
    WorkoutBlockFormat.amrap => 'Secuencia de cada vuelta',
    _ => 'Ejercicios del bloque',
  };

  String get emptySequenceText => switch (format) {
    WorkoutBlockFormat.circuit => 'Añade al menos dos estaciones.',
    WorkoutBlockFormat.emom => 'Añade el movimiento del primer minuto.',
    WorkoutBlockFormat.amrap => 'Añade el primer movimiento de la vuelta.',
    _ => 'Añade el primer ejercicio.',
  };

  String get addExerciseLabel => switch (format) {
    WorkoutBlockFormat.superset when rows.isEmpty => 'Elegir ejercicio A1',
    WorkoutBlockFormat.superset when rows.length == 1 => 'Elegir ejercicio A2',
    WorkoutBlockFormat.superset => 'Superserie completa',
    WorkoutBlockFormat.circuit => 'Añadir estación al circuito',
    WorkoutBlockFormat.emom => 'Añadir minuto al EMOM',
    WorkoutBlockFormat.amrap => 'Añadir movimiento al AMRAP',
    WorkoutBlockFormat.intervals ||
    WorkoutBlockFormat.tabata => 'Elegir ejercicio',
    _ => 'Añadir ejercicio al bloque',
  };

  String positionLabel(int index) => switch (format) {
    WorkoutBlockFormat.superset => 'A${index + 1}',
    WorkoutBlockFormat.circuit => 'E${index + 1}',
    WorkoutBlockFormat.emom => 'M${index + 1}',
    WorkoutBlockFormat.amrap => '${index + 1}.',
    _ => '${index + 1}',
  };

  String setSectionLabel(int setCount) => switch (format) {
    WorkoutBlockFormat.superset ||
    WorkoutBlockFormat.circuit => 'Objetivo en cada ronda ($setCount)',
    WorkoutBlockFormat.intervals ||
    WorkoutBlockFormat.tabata => 'Intervalos ($setCount)',
    WorkoutBlockFormat.emom => 'Objetivo en cada vuelta ($setCount)',
    WorkoutBlockFormat.amrap => 'Objetivo por vuelta',
    _ => 'Series ($setCount)',
  };

  WorkoutBlockDraft toDraft() => WorkoutBlockDraft(
    name: name,
    format: format,
    rounds: rounds,
    restAfterSeconds: restAfterSeconds,
    timeCapSeconds: format == WorkoutBlockFormat.amrap ? timeCapSeconds : null,
    exercises: rows.map((row) => row.toDraft()).toList(),
  );
}

class _ExerciseRowData {
  _ExerciseRowData({
    required this.exercise,
    required this.targetType,
    required this.sets,
  });

  factory _ExerciseRowData.fromExercise(
    ExerciseEntity exercise, {
    int setCount = 3,
  }) {
    final type = exercise.exerciseType.toLowerCase().contains('dur')
        ? WorkoutTargetType.duration
        : WorkoutTargetType.repetitions;
    return _ExerciseRowData(
      exercise: exercise,
      targetType: type,
      sets: List.generate(
        setCount,
        (_) => _SetRowData(
          targetValue: type == WorkoutTargetType.duration ? 30 : 10,
        ),
      ),
    );
  }

  final Object identity = Object();
  final ExerciseEntity exercise;
  WorkoutTargetType targetType;
  List<_SetRowData> sets;

  WorkoutExerciseDraft toDraft() => WorkoutExerciseDraft(
    exerciseId: exercise.id,
    sets: sets
        .map(
          (set) => WorkoutSetDraft(
            targetType: targetType,
            targetValue: set.targetValue,
            restAfterSeconds: set.restSeconds,
            targetLoadKg: set.loadKg,
            targetRir: set.rir,
          ),
        )
        .toList(),
  );
}

class _SetRowData {
  _SetRowData({
    required this.targetValue,
    this.restSeconds = 60,
    this.loadKg,
    this.rir = 2,
  });

  double targetValue;
  int restSeconds;
  double? loadKg;
  double? rir;

  _SetRowData copy() => _SetRowData(
    targetValue: targetValue,
    restSeconds: restSeconds,
    loadKg: loadKg,
    rir: rir,
  );
}

class _ExerciseEditorCard extends StatefulWidget {
  const _ExerciseEditorCard({
    super.key,
    required this.index,
    required this.positionLabel,
    required this.setSectionLabel,
    required this.data,
    required this.enabled,
    required this.fixedSetCount,
    required this.fixedTarget,
    required this.moveTargets,
    required this.onMoveToBlock,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final String positionLabel;
  final String setSectionLabel;
  final _ExerciseRowData data;
  final bool enabled;
  final bool fixedSetCount;
  final bool fixedTarget;
  final List<({int index, String name})> moveTargets;
  final ValueChanged<int> onMoveToBlock;
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
                  child: Text(widget.positionLabel),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                PopupMenuButton<int>(
                  enabled: widget.enabled,
                  tooltip: 'Organizar ejercicio',
                  onSelected: (value) {
                    if (value == -1) widget.onMoveUp?.call();
                    if (value == -2) widget.onMoveDown?.call();
                    if (value == -3) widget.onRemove();
                    if (value >= 0) widget.onMoveToBlock(value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: -1,
                      enabled: widget.onMoveUp != null,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.arrow_upward_rounded),
                        title: Text('Subir'),
                      ),
                    ),
                    PopupMenuItem(
                      value: -2,
                      enabled: widget.onMoveDown != null,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.arrow_downward_rounded),
                        title: Text('Bajar'),
                      ),
                    ),
                    for (final target in widget.moveTargets)
                      PopupMenuItem(
                        value: target.index,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.drive_file_move_outline),
                          title: Text('Mover a ${target.name}'),
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: -3,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Quitar ejercicio'),
                      ),
                    ),
                  ],
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
              onChanged: widget.enabled && !widget.fixedTarget
                  ? (value) => setState(() {
                      if (value == null) return;
                      data.targetType = value;
                      final defaultTarget = switch (value) {
                        WorkoutTargetType.repetitions => 10.0,
                        WorkoutTargetType.duration => 30.0,
                        WorkoutTargetType.distance => 1000.0,
                      };
                      for (final set in data.sets) {
                        set.targetValue = defaultTarget;
                      }
                    })
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              widget.setSectionLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (data.sets.length >= 2)
                    TextButton.icon(
                      onPressed: !widget.enabled
                          ? null
                          : () => setState(() {
                              final first = data.sets.first;
                              data.sets = List.generate(
                                data.sets.length,
                                (_) => first.copy(),
                              );
                            }),
                      icon: const Icon(Icons.copy_all_rounded, size: 17),
                      label: const Text('Igualar'),
                    ),
                  if (!widget.fixedSetCount) ...[
                    IconButton(
                      tooltip: 'Quitar última serie',
                      onPressed: !widget.enabled || data.sets.length <= 1
                          ? null
                          : () => setState(data.sets.removeLast),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    IconButton(
                      tooltip: 'Añadir serie',
                      onPressed: !widget.enabled || data.sets.length >= 20
                          ? null
                          : () => setState(
                              () => data.sets.add(data.sets.last.copy()),
                            ),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...List.generate(
              data.sets.length,
              (index) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _SetEditor(
                  key: ValueKey(data.sets[index]),
                  index: index,
                  data: data.sets[index],
                  targetType: data.targetType,
                  enabled: widget.enabled,
                  targetEnabled: widget.enabled && !widget.fixedTarget,
                  showRest: !widget.fixedSetCount,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetEditor extends StatelessWidget {
  const _SetEditor({
    super.key,
    required this.index,
    required this.data,
    required this.targetType,
    required this.enabled,
    required this.targetEnabled,
    required this.showRest,
  });

  final int index;
  final _SetRowData data;
  final WorkoutTargetType targetType;
  final bool enabled;
  final bool targetEnabled;
  final bool showRest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Serie ${index + 1}',
            style: const TextStyle(
              color: Color(0xFFFF8A50),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _NumberField(
                label: switch (targetType) {
                  WorkoutTargetType.repetitions => 'Repeticiones',
                  WorkoutTargetType.duration => 'Tiempo',
                  WorkoutTargetType.distance => 'Distancia',
                },
                initialValue: _numberText(data.targetValue),
                suffix: switch (targetType) {
                  WorkoutTargetType.repetitions => 'reps',
                  WorkoutTargetType.duration => 's',
                  WorkoutTargetType.distance => 'm',
                },
                enabled: targetEnabled,
                integer: targetType != WorkoutTargetType.distance,
                min: 0.01,
                max: 100000,
                onChanged: (value) => data.targetValue = value,
              ),
              _NumberField(
                label: 'Carga',
                initialValue: data.loadKg == null
                    ? ''
                    : _numberText(data.loadKg!),
                suffix: 'kg',
                enabled: enabled,
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
                enabled: enabled,
                optional: true,
                min: 0,
                max: 10,
                onChanged: (value) => data.rir = value,
                onCleared: () => data.rir = null,
              ),
              if (showRest)
                _NumberField(
                  label: 'Descanso',
                  initialValue: data.restSeconds.toString(),
                  suffix: 's',
                  enabled: enabled,
                  integer: true,
                  min: 0,
                  max: 3600,
                  onChanged: (value) => data.restSeconds = value.round(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
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
                          onTap: () => Navigator.of(context).pop(exercise),
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
  const _EmptyExercises();

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
              'Este bloque todavía está vacío',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Usa el botón superior para añadir su primera posición.',
              style: TextStyle(color: Colors.white60),
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

WorkoutTargetType _targetTypeOf(WorkoutSet set) {
  if (set.targetReps != null) return WorkoutTargetType.repetitions;
  if (set.targetDurationSeconds != null) return WorkoutTargetType.duration;
  return WorkoutTargetType.distance;
}

double _targetValueOf(WorkoutSet set) =>
    set.targetReps?.toDouble() ??
    set.targetDurationSeconds?.toDouble() ??
    set.targetDistanceMeters!;
