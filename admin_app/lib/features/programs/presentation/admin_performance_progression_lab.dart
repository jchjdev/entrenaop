import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/performance_progression_policy.dart';
import 'package:workout_core/performance_training_contract.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_training_policy.dart' show StrengthTask;

import 'admin_performance_execution_dialog.dart';

/// Flujo de revisión deportiva con referencias ficticias y catálogo real.
/// No escribe programas, referencias del deportista ni sesiones de agenda.
class AdminPerformanceProgressionLab extends StatefulWidget {
  const AdminPerformanceProgressionLab({super.key, required this.repository});
  final AdminExerciseRepository repository;
  @override
  State<AdminPerformanceProgressionLab> createState() =>
      _AdminPerformanceProgressionLabState();
}

class _AdminPerformanceProgressionLabState
    extends State<AdminPerformanceProgressionLab> {
  late Future<List<AdminCatalogExercise>> _catalog;
  final _selected = <String>{'push', 'pull', 'plank', 'bench'};
  final _inputs = {
    for (final spec in _specs.where((s) => s.model != null))
      spec.id: _LabInput(spec.example),
  };
  var _step = 0;
  var _confirmed = false;
  var _symptoms = false;
  var _equipmentAvailable = true;
  final _formKey = GlobalKey<FormState>();
  final _headingKey = GlobalKey();
  PerformancePreparationPreview? _preview;
  Map<String, PerformanceProgressionDecision> _decisions = {};

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.listOfficial();
  }

  @override
  void dispose() {
    for (final input in _inputs.values) {
      input.load.dispose();
    }
    super.dispose();
  }

  List<_LabSpec> get _goals =>
      _specs.where((s) => _selected.contains(s.id)).toList();
  List<PerformanceQuestionBlock> get _blocks =>
      _goals.map((s) => s.block).toSet().toList();

  void _showStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final heading = _headingKey.currentContext;
      if (mounted && heading != null) {
        Scrollable.ensureVisible(
          heading,
          duration: const Duration(milliseconds: 200),
          alignment: 0.05,
        );
      }
    });
  }

  void _example() {
    setState(() {
      _selected
        ..clear()
        ..addAll({'push', 'pull', 'plank', 'bench'});
      _confirmed = true;
      _symptoms = false;
      _equipmentAvailable = true;
      _step = 0;
      _preview = null;
      for (final spec in _specs.where((s) => s.model != null)) {
        final input = _inputs[spec.id]!;
        input.resetSeries(spec.example);
        input.load.text = '40';
        input.executions.clear();
      }
    });
    _showStep();
  }

  StrengthTask _task(_LabSpec spec, {bool working = false}) => StrengthTask(
    exerciseCode: spec.code,
    exerciseVersion: 1,
    protocolKey: 'lab_${spec.id}_${working ? 'work' : 'goal'}',
    protocolVersion: 1,
    setupKey: 'lab_${spec.id}_fixed_setup',
    measurement:
        working && spec.model == PerformanceProgressionModel.loadAndRepetitions
        ? StrengthMeasurement.loadReps
        : spec.measurement,
  );

  PerformanceProgressionDose _dose(_LabSpec spec) {
    final input = _inputs[spec.id]!;
    return PerformanceProgressionDose(
      task: _task(
        spec,
        working: spec.model == PerformanceProgressionModel.loadAndRepetitions,
      ),
      model: spec.model!,
      loadMode: spec.loadMode,
      targets: input.series.map((series) => int.parse(series.value.trim())),
      restSeconds: spec.model == PerformanceProgressionModel.duration
          ? 60
          : 120,
      targetRir: spec.model == PerformanceProgressionModel.duration ? null : 3,
      loadKg: spec.model == PerformanceProgressionModel.loadAndRepetitions
          ? double.parse(input.load.text.replaceAll(',', '.'))
          : null,
    );
  }

  Future<void> _record(
    _LabSpec spec, {
    PerformanceProgressionExposure? initial,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    final input = _inputs[spec.id]!;
    final date = DateTime.now().toUtc().subtract(
      Duration(days: input.executions.isEmpty ? 2 : 5),
    );
    final id = initial?.id ?? '${spec.id}_manual_${input.nextExecutionId++}';
    final dose = initial?.dose ?? _dose(spec);
    final record = await showDialog<PerformanceProgressionExposure>(
      context: context,
      builder: (context) => AdminPerformanceExecutionDialog(
        id: id,
        label: spec.label,
        dose: dose,
        date: date,
        initial: initial,
      ),
    );
    if (!mounted || record == null) return;
    setState(() {
      if (initial == null) {
        input.executions.add(record);
      } else {
        input.executions[input.executions.indexOf(initial)] = record;
      }
      _preview = null;
    });
  }

  void _executionExamples(_LabSpec spec) {
    if (!_formKey.currentState!.validate()) return;
    final dose = _dose(spec);
    final input = _inputs[spec.id]!;
    final now = DateTime.now().toUtc();
    setState(() {
      input.executions
        ..clear()
        ..addAll([
          for (final age in [2, 5])
            PerformanceProgressionExposure(
              id: '${spec.id}_example_${input.nextExecutionId++}',
              performedOn: now.subtract(Duration(days: age)),
              dose: dose,
              conditionsConfirmed: true,
              tolerated: true,
              stop: PerformanceExecutionStop.none,
              actualBodyMassKg: dose.bodyMassKg,
              sets: [
                for (final target in dose.targets)
                  PerformanceProgressionSet(
                    validUnits: target,
                    techniqueValid: true,
                    rir: dose.targetRir,
                    actualLoadKg: dose.loadKg,
                  ),
              ],
            ),
        ]);
      _preview = null;
    });
  }

  void _calculate(List<AdminCatalogExercise> catalog) {
    final now = DateTime.now().toUtc();
    final profiles = catalog
        .map((e) => e.trainingProfile)
        .whereType<StrengthExerciseDefinition>()
        .toList();
    final goals = <PerformanceTrainingGoal>[];
    final proposals = <PerformanceModuleProposal>[];
    final decisions = <String, PerformanceProgressionDecision>{};
    for (final spec in _goals) {
      final target = _task(spec);
      final goal = PerformanceTrainingGoal(
        id: spec.id,
        task: target,
        capability: spec.capability,
        questionBlock: spec.block,
        loadMode: spec.loadMode,
      );
      goals.add(goal);
      if (spec.model == null) continue;
      final input = _inputs[spec.id]!;
      final dose = _dose(spec);
      final decision = PerformanceProgressionPolicy().preview(
        goal: goal,
        catalog: profiles,
        equipment: _equipmentAvailable
            ? profiles.expand((p) => p.requiredEquipment).toSet()
            : {},
        calibratedDose: dose,
        calibratedOn: now.subtract(const Duration(days: 7)),
        now: now,
        currentCapacityConfirmed: _confirmed,
        hasSymptoms: _symptoms,
        history: input.executions,
      );
      decisions[spec.id] = decision;
      proposals.add(decision.proposal);
    }
    setState(() {
      _decisions = decisions;
      _preview = PerformancePreparationPreview(
        goals: goals,
        proposals: proposals,
      );
      _step++;
    });
    _showStep();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<AdminCatalogExercise>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                const Text('No se pudo cargar la biblioteca oficial.'),
                TextButton(
                  onPressed: () => setState(
                    () => _catalog = widget.repository.listOfficial(),
                  ),
                  child: const Text('Reintentar catálogo'),
                ),
              ],
            );
          }
          final catalog = snapshot.data ?? [];
          final blocks = _blocks;
          final atSummary = _step > blocks.length;
          final title = _step == 0
              ? 'Objetivos y contexto'
              : atSummary
              ? 'Propuestas para revisión'
              : _blockName(blocks[_step - 1]);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Laboratorio local v1 conservado para revisión de contratos. No representa el planificador v2 del servidor ni publica entrenamientos. Las semanas reales se revisan desde la preparación del deportista.',
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (_step + 1) / (blocks.length + 2)),
              const SizedBox(height: 12),
              Text(
                'Paso ${_step + 1} de ${blocks.length + 2} · $title',
                key: _headingKey,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: _step == 0
                    ? _context()
                    : atSummary
                    ? _summary()
                    : _block(blocks[_step - 1], catalog),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _step--;
                          _preview = null;
                        });
                        _showStep();
                      },
                      child: const Text('Atrás'),
                    ),
                  if (!atSummary)
                    FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () {
                              if (!_formKey.currentState!.validate()) return;
                              if (_step == blocks.length) {
                                _calculate(catalog);
                              } else {
                                setState(() => _step++);
                                _showStep();
                              }
                            },
                      child: Text(
                        _step == blocks.length
                            ? 'Calcular propuestas'
                            : 'Continuar',
                      ),
                    ),
                  TextButton(
                    onPressed: _example,
                    child: const Text('Cargar ejemplo completo'),
                  ),
                ],
              ),
            ],
          );
        },
      );

  Widget _context() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Elige objetivos ficticios. En el recorrido del deportista vendrán del programa; esta pantalla aún no los configura en ADMIN.',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final spec in _specs)
            FilterChip(
              label: Text(spec.label),
              selected: _selected.contains(spec.id),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _selected.add(spec.id);
                } else {
                  _selected.remove(spec.id);
                }
              }),
            ),
        ],
      ),
      SwitchListTile(
        title: const Text(
          'Las referencias representan la capacidad de trabajo actual',
        ),
        subtitle: const Text(
          'En este laboratorio se simulan series ya realizadas, no marcas máximas de examen.',
        ),
        value: _confirmed,
        onChanged: (v) => setState(() => _confirmed = v),
      ),
      SwitchListTile(
        title: const Text('Presenta molestias o limitación'),
        value: _symptoms,
        onChanged: (v) => setState(() => _symptoms = v),
      ),
      SwitchListTile(
        title: const Text('Material requerido disponible (simulado)'),
        value: _equipmentAvailable,
        onChanged: (v) => setState(() => _equipmentAvailable = v),
      ),
    ],
  );

  Widget _block(
    PerformanceQuestionBlock block,
    List<AdminCatalogExercise> catalog,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final spec in _goals.where((s) => s.block == block)) ...[
        Text(spec.label, style: Theme.of(context).textTheme.titleMedium),
        if (!catalog.any(
          (e) =>
              e.trainingProfile?.code == spec.code &&
              e.trainingProfile?.definitionVersion == 1,
        ))
          const Text(
            'Falta el perfil oficial v1: esta tarea no producirá dosis.',
          ),
        if (spec.model == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Objetivo conservado. Su dosificación aún no está implementada; aparecerá pendiente en el resumen.',
            ),
          )
        else ...[
          _referenceHelp(spec),
          _seriesEditor(spec),
          if (spec.model == PerformanceProgressionModel.loadAndRepetitions)
            TextFormField(
              key: ValueKey('load_${spec.id}'),
              controller: _inputs[spec.id]!.load,
              decoration: const InputDecoration(
                labelText: 'Carga externa de trabajo (kg)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final kg = double.tryParse((value ?? '').replaceAll(',', '.'));
                return kg == null || !kg.isFinite || kg <= 0
                    ? 'Introduce una carga positiva.'
                    : null;
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              spec.model == PerformanceProgressionModel.duration
                  ? 'Dosis calibrada en este montaje. Descanso: 60 s. Progresión candidata: +2 s en una serie.'
                  : spec.model == PerformanceProgressionModel.loadAndRepetitions
                  ? 'Trabajo calibrado a RIR 3, descanso 120 s. Horquilla 4–6; escalón simulado de carga: 2,5 kg.'
                  : 'Trabajo calibrado a RIR 3, descanso 120 s. Progresión candidata: +1 repetición total.',
            ),
          ),
          _executionList(spec),
          const SizedBox(height: 20),
        ],
      ],
    ],
  );

  Widget _executionList(_LabSpec spec) {
    final input = _inputs[spec.id]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ejecuciones registradas: ${input.executions.length}'),
        const Text(
          'Registra resultados ficticios. El motor decide qué respuesta representan.',
        ),
        for (final (index, record) in input.executions.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Ejecución ${index + 1} · ${record.performedOn.day}/${record.performedOn.month}',
            ),
            subtitle: Text(
              'Realizado: ${record.sets.map((s) => s.validUnits?.toString() ?? '?').join(' / ')} ${spec.model == PerformanceProgressionModel.duration ? 'segundos' : 'repeticiones'}',
            ),
            onTap: () => _record(spec, initial: record),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Editar registro ${index + 1} de ${spec.label}',
                  onPressed: () => _record(spec, initial: record),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Quitar registro ${index + 1} de ${spec.label}',
                  onPressed: () =>
                      setState(() => input.executions.remove(record)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: ValueKey('add_execution_${spec.id}'),
              onPressed: input.executions.length >= 2
                  ? null
                  : () => _record(spec),
              icon: const Icon(Icons.add),
              label: const Text('Registrar ejecución'),
            ),
            TextButton(
              key: ValueKey('example_executions_${spec.id}'),
              onPressed: () => _executionExamples(spec),
              child: const Text('Cargar dos registros de ejemplo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _referenceHelp(_LabSpec spec) {
    final isDuration = spec.model == PerformanceProgressionModel.duration;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDuration
                ? 'Introduce los segundos mantenidos con la postura válida del ejercicio. Esta referencia no utiliza RIR.'
                : 'Introduce las repeticiones realizadas en cada serie dejando unas 3 más posibles con buena técnica (RIR 3). Aquí la referencia se simula.',
          ),
          if (!isDuration)
            const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Cómo entender el margen de repeticiones (RIR)'),
              childrenPadding: EdgeInsets.only(bottom: 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Al terminar: ¿cuántas repeticiones más podrías haber hecho seguidas, con la misma técnica y sin descansar? Ese margen estimado es el RIR.',
                ),
                SizedBox(height: 8),
                Text(
                  'Ejemplo: hiciste 8 y crees que podrías haber hecho 3 más. La referencia es 8 repeticiones y RIR 3; las 3 restantes no se realizan.',
                ),
                SizedBox(height: 8),
                Text(
                  'Este ensayo supone RIR 3. En una ejecución real se debe registrar el margen que declares, aunque sea distinto del objetivo. Si no sabes estimarlo, debe quedar sin dato.',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _seriesEditor(_LabSpec spec) {
    final input = _inputs[spec.id]!;
    final unit = spec.model == PerformanceProgressionModel.duration
        ? 'segundos'
        : 'repeticiones';
    return Column(
      key: ValueKey('targets_${spec.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Dosis de trabajo · ${input.series.length} ${input.series.length == 1 ? 'serie' : 'series'}',
          ),
        ),
        for (final (i, series) in input.series.indexed)
          Padding(
            // La identidad de la serie conserva su valor al quitar otra fila.
            key: ValueKey('series_${spec.id}_${series.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: series.value,
                    decoration: InputDecoration(
                      labelText: 'Serie ${i + 1}',
                      suffixText: unit,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => series.value = value,
                    validator: (value) {
                      final target = int.tryParse((value ?? '').trim());
                      return target == null || target < 1 || target > 3600
                          ? 'Introduce un entero entre 1 y 3600.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar serie ${i + 1}',
                  onPressed: input.series.length == 1
                      ? null
                      : () => setState(() => input.series.remove(series)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: input.series.length >= 6
                ? null
                : () => setState(input.addSeries),
            icon: const Icon(Icons.add),
            label: const Text('Añadir serie'),
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    final preview = _preview;
    if (preview == null) {
      return const Text('Vuelve al bloque anterior para recalcular.');
    }
    final ready = preview.proposals.length - preview.pending.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Objetivos con propuesta: $ready/${preview.goals.length}'),
        const Text(
          'Revisión experimental de una exposición por objetivo. Coordinación, evolución por meses y publicación pendientes.',
        ),
        const SizedBox(height: 12),
        for (final proposal in preview.proposals) ...[
          Text(
            _specs.firstWhere((s) => s.id == proposal.goal.id).label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_decisions[proposal.goal.id]?.dose
              case final PerformanceProgressionDose dose) ...[
            Text(
              '${_actionName(_decisions[proposal.goal.id]!.action!)} · ${dose.targets.join(' / ')} ${dose.model == PerformanceProgressionModel.duration ? 'segundos' : 'repeticiones'}${dose.loadKg == null ? '' : ' · ${dose.loadKg} kg'}',
            ),
          ] else
            Text(switch (proposal.status) {
              PerformanceProposalStatus.blocked =>
                'Bloqueado por molestias o limitación',
              PerformanceProposalStatus.needsData => 'Faltan datos o material',
              PerformanceProposalStatus.needsCalibration =>
                'Necesita calibración de trabajo',
              _ => 'Dosificación pendiente',
            }),
          Text(_reason(proposal.reasons.first)),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _LabInput {
  _LabInput(List<int> example) {
    resetSeries(example);
  }
  final series = <_LabSeries>[];
  var _nextSeriesId = 0;
  final load = TextEditingController(text: '40');
  final executions = <PerformanceProgressionExposure>[];
  var nextExecutionId = 0;

  void resetSeries(List<int> values) {
    series
      ..clear()
      ..addAll(values.map((value) => _LabSeries(_nextSeriesId++, '$value')));
  }

  void addSeries() =>
      series.add(_LabSeries(_nextSeriesId++, series.last.value));
}

class _LabSeries {
  _LabSeries(this.id, this.value);
  final int id;
  String value;
}

class _LabSpec {
  const _LabSpec(
    this.id,
    this.label,
    this.code,
    this.capability,
    this.block,
    this.measurement, {
    this.model,
    this.loadMode = StrengthLoadMode.bodyweight,
    this.example = const [],
  });
  final String id;
  final String label;
  final String code;
  final PerformanceCapability capability;
  final PerformanceQuestionBlock block;
  final StrengthMeasurement measurement;
  final PerformanceProgressionModel? model;
  final StrengthLoadMode loadMode;
  final List<int> example;
}

const _specs = [
  _LabSpec(
    'push',
    'Flexiones',
    'push_up_standard',
    PerformanceCapability.repetitions,
    PerformanceQuestionBlock.pushes,
    StrengthMeasurement.reps,
    model: PerformanceProgressionModel.repetitions,
    example: [8, 8],
  ),
  _LabSpec(
    'pull',
    'Dominadas',
    'pull_up_pronated',
    PerformanceCapability.repetitions,
    PerformanceQuestionBlock.pulls,
    StrengthMeasurement.reps,
    model: PerformanceProgressionModel.repetitions,
    example: [4, 4],
  ),
  _LabSpec(
    'plank',
    'Plancha',
    'front_plank_forearms',
    PerformanceCapability.isometricEndurance,
    PerformanceQuestionBlock.isometrics,
    StrengthMeasurement.duration,
    model: PerformanceProgressionModel.duration,
    example: [20, 20],
  ),
  _LabSpec(
    'hang',
    'Suspensión',
    'supinated_flexed_arm_hang',
    PerformanceCapability.isometricEndurance,
    PerformanceQuestionBlock.isometrics,
    StrengthMeasurement.duration,
    model: PerformanceProgressionModel.duration,
    example: [15, 15],
  ),
  _LabSpec(
    'bench',
    'Fuerza en banca',
    'bench_press_barbell',
    PerformanceCapability.maximalStrength,
    PerformanceQuestionBlock.strengthAndLowerBody,
    StrengthMeasurement.maxLoad,
    model: PerformanceProgressionModel.loadAndRepetitions,
    loadMode: StrengthLoadMode.externalLoad,
    example: [4, 4],
  ),
  _LabSpec(
    'timed_push',
    'Flexiones cronometradas',
    'push_up_standard',
    PerformanceCapability.repetitionsInTime,
    PerformanceQuestionBlock.pushes,
    StrengthMeasurement.repsInTime,
  ),
  _LabSpec(
    'rope',
    'Cuerda',
    'rope_climb',
    PerformanceCapability.ropeClimb,
    PerformanceQuestionBlock.rope,
    StrengthMeasurement.timeForDistance,
  ),
  _LabSpec(
    'jump',
    'Salto horizontal',
    'standing_broad_jump',
    PerformanceCapability.jumpOrThrow,
    PerformanceQuestionBlock.jumpsAndThrows,
    StrengthMeasurement.distance,
  ),
  _LabSpec(
    'reactive_jump',
    'Reactividad de saltos',
    'pogo_jumps',
    PerformanceCapability.powerPractice,
    PerformanceQuestionBlock.powerAndReactivity,
    StrengthMeasurement.reactiveMetrics,
  ),
  _LabSpec(
    'course',
    'Recorrido prefijado',
    'shuttle_5_10_5',
    PerformanceCapability.plannedCourse,
    PerformanceQuestionBlock.coursesAndAgility,
    StrengthMeasurement.timeForCourse,
  ),
  _LabSpec(
    'agility',
    'Agilidad reactiva',
    'reactive_direction_drill',
    PerformanceCapability.reactiveAgility,
    PerformanceQuestionBlock.coursesAndAgility,
    StrengthMeasurement.timeForCourse,
  ),
  _LabSpec(
    'carry',
    'Transporte',
    'suitcase_carry',
    PerformanceCapability.carry,
    PerformanceQuestionBlock.carries,
    StrengthMeasurement.distance,
    loadMode: StrengthLoadMode.externalLoad,
  ),
];

String _blockName(PerformanceQuestionBlock block) => switch (block) {
  PerformanceQuestionBlock.pushes => 'Empujes',
  PerformanceQuestionBlock.pulls => 'Tirones',
  PerformanceQuestionBlock.isometrics => 'Isométricos',
  PerformanceQuestionBlock.strengthAndLowerBody => 'Fuerza con carga',
  PerformanceQuestionBlock.rope => 'Cuerda',
  PerformanceQuestionBlock.jumpsAndThrows => 'Saltos y lanzamientos',
  PerformanceQuestionBlock.powerAndReactivity => 'Potencia y reactividad',
  PerformanceQuestionBlock.coursesAndAgility => 'Circuitos y agilidad',
  PerformanceQuestionBlock.carries => 'Transportes',
  _ => block.name,
};

String _actionName(PerformanceProgressionAction action) => switch (action) {
  PerformanceProgressionAction.establish => 'Dosis inicial',
  PerformanceProgressionAction.progress => 'Progresar',
  PerformanceProgressionAction.maintain => 'Mantener',
  PerformanceProgressionAction.reduce => 'Reducir',
};

String _reason(String reason) => switch (reason) {
  'use_confirmed_working_dose' => 'Se utiliza la dosis de trabajo calibrada.',
  'two_comparable_exposures_needed' =>
    'Faltan dos exposiciones comparables; se conserva la dosis.',
  'two_tolerated_exposures_increase_one_target' =>
    'Dos ejecuciones válidas y toleradas permiten aumentar una serie.',
  'consolidated_range_increase_load' =>
    'Horquilla consolidada: sube carga y vuelve al extremo bajo.',
  'repeated_difficulty_reduce_one_target' =>
    'La dificultad repetida reduce una serie sin cambiar el resto.',
  'mixed_incomplete_or_time_limited_response' =>
    'La información no justifica un cambio; se conserva la dosis.',
  'latest_doses_not_comparable' => 'La referencia actual cambió; los registros conservan su dosis original y no son comparables.',
  'execution_conditions_not_confirmed' => 'Falta confirmar que se mantuvieron variante, montaje y descansos; se conserva la dosis.',
  'actual_load_not_comparable' => 'La carga utilizada o la masa corporal faltan o difieren de la dosis; se conserva la propuesta sin atribuir mejora.',
  'confirm_current_capacity' =>
    'Confirma que las dosis representan capacidad de trabajo actual.',
  'required_equipment_missing' => 'Falta material requerido para la variante.',
  'update_comparable_working_reference' =>
    'Revisa la referencia; banca necesita series de 4–6 en este ensayo.',
  'difficulty_at_minimum_update_reference' =>
    'La dosis ya está en el mínimo; hace falta recalibrar.',
  'symptoms_or_limitation' => 'La prescripción automática permanece bloqueada.',
  'policy_not_available' => 'El objetivo permanece visible; su política de dosis aún no está disponible.',
  'task_or_model_not_covered' =>
    'Perfil, tarea o modelo incompatibles con esta política.',
  _ => 'Es necesario revisar la comparabilidad de los datos.',
};
