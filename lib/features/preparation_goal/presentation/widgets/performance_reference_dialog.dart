import 'performance_equipment_labels.dart';

import 'package:flutter/material.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/performance_time.dart';

class PerformanceReferenceInput {
  const PerformanceReferenceInput(this.reference, this.testId, this.equipment);
  final Map<String, dynamic> reference;
  final String? testId;
  final Set<String> equipment;
}

class PerformanceReferenceDialog extends StatefulWidget {
  const PerformanceReferenceDialog({
    required this.data,
    this.objective,
    this.existing,
    this.initialWorkCode,
    this.initialMeasurement,
    super.key,
  });
  final PreparationTrainingData data;
  final Map<String, dynamic>? objective;
  final Map<String, dynamic>? existing;
  final String? initialWorkCode;
  final String? initialMeasurement;
  @override
  State<PerformanceReferenceDialog> createState() =>
      _PerformanceReferenceDialogState();
}

class _PerformanceReferenceDialogState
    extends State<PerformanceReferenceDialog> {
  final _form = GlobalKey<FormState>();
  final _setup = TextEditingController();
  final _rir = TextEditingController();
  final _rpe = TextEditingController();
  final _rest = TextEditingController();
  final _load = TextEditingController();
  final _mass = TextEditingController();
  final _increment = TextEditingController();
  final _window = TextEditingController();
  final _distance = TextEditingController();
  final _series = <TextEditingController>[];
  final _removedSeries = <TextEditingController>[];
  late StrengthExerciseDefinition _goal, _work;
  late StrengthMeasurement _goalMode, _mode;
  late StrengthLoadMode _loadMode;
  late DateTime _date;
  bool _confirmed = false, _material = false;
  int _frequency = 1;
  String? _error;
  String? _kind;
  int _step = 0;
  bool get _maximum => _kind == 'capacity_test' || _kind == 'official_test';

  bool get _practice =>
      _work.movementModes.contains('plyometric') ||
      const [
        'kettlebell_swing',
        'medicine_ball_chest_throw',
      ].contains(_work.code);
  bool get _rirRelevant =>
      !_maximum &&
      !_practice &&
      const [
        StrengthMeasurement.reps,
        StrengthMeasurement.loadReps,
        StrengthMeasurement.repsInTime,
      ].contains(_mode);
  bool get _specific => _goal.code == _work.code;
  bool get _supportsOfficial =>
      _specific && _workOptions.any((option) => option.mode == _goalMode);
  bool get _needsSetup =>
      _work.code == 'push_up_incline' ||
      _loadMode == StrengthLoadMode.assisted ||
      _mode == StrengthMeasurement.reactiveMetrics;
  Map<String, dynamic> get _parameters =>
      Map<String, dynamic>.from(widget.objective?['parameters'] as Map? ?? {});
  List<StrengthExerciseDefinition> get _variants => widget.data.catalog
      .where(
        (p) =>
            p.code == _goal.code ||
            widget.data.relations.any(
              (r) => r['goal_code'] == _goal.code && r['work_code'] == p.code,
            ),
      )
      .toList();
  List<StrengthMeasurementOption> get _workOptions => _work.measurements
      .where(
        (m) =>
            m.mode != StrengthMeasurement.maxLoad &&
            (!_specific ||
                m.mode == _goalMode ||
                (_goalMode == StrengthMeasurement.maxLoad &&
                    m.mode == StrengthMeasurement.loadReps) ||
                (_goalMode == StrengthMeasurement.repsInTime &&
                    m.mode == StrengthMeasurement.reps)),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    final old = widget.existing?['reference'] as Map?;
    final task = old?['task'] as Map?;
    final savedKind = old?['reference_kind'] as String?;
    _kind = savedKind == 'legacy_work' ? null : savedKind;
    _rpe.text = old?['reported_rpe']?.toString() ?? '';
    final code = widget.objective?['profile_code'] ?? old?['goal_code'];
    _goal = widget.data.catalog.firstWhere(
      (p) => p.code == code,
      orElse: () =>
          widget.data.catalog.firstWhere((p) => p.code == 'push_up_standard'),
    );
    _goalMode = StrengthMeasurement.values.firstWhere(
      (m) =>
          m.code ==
          (widget.objective?['measurement'] ?? old?['goal_measurement']),
      orElse: () => _goal.measurements.first.mode,
    );
    _work = widget.data.catalog.firstWhere(
      (p) => p.code == (task?['exercise_code'] ?? widget.initialWorkCode),
      orElse: () => _goal,
    );
    _mode = _workOptions
        .firstWhere(
          (m) =>
              m.mode.code ==
              (task?['measurement'] ??
                  widget.initialMeasurement ??
                  (_goalMode == StrengthMeasurement.repsInTime
                      ? StrengthMeasurement.reps.code
                      : _goalMode.code)),
          orElse: () => _workOptions.first,
        )
        .mode;
    if (_kind == 'official_test' && !_supportsOfficial) _kind = null;
    _loadMode = _work.measurements
        .firstWhere((m) => m.mode == _mode)
        .loadModes
        .first;
    if (task?['load_mode'] != null) {
      _loadMode = StrengthLoadMode.values.firstWhere(
        (m) => m.code == task!['load_mode'],
      );
    }
    _date = old?['observed_on'] == null
        ? DateTime.now()
        : DateTime.parse(old!['observed_on'] as String);
    final savedSetup = task?['setup_key'] as String? ?? '';
    _setup.text = savedSetup.startsWith('standard:') ? '' : savedSetup;
    _rir.text = old?['reported_rir']?.toString() ?? '';
    _rest.text = old?['rest_seconds']?.toString() ?? '';
    _load.text = task?['external_load_kg']?.toString() ?? '';
    _mass.text = task?['body_mass_kg']?.toString() ?? '';
    _increment.text = old?['load_step_kg']?.toString() ?? '';
    _window.text =
        (_parameters['fixed_duration_seconds'] ??
                task?['fixed_duration_seconds'])
            ?.toString() ??
        '';
    _distance.text =
        (_parameters['fixed_distance_meters'] ?? task?['fixed_distance_meters'])
            ?.toString() ??
        '';
    _frequency = old?['frequency'] as int? ?? 1;
    for (final value in old?['targets'] as List? ?? ['']) {
      _series.add(TextEditingController(text: value.toString()));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _setup,
      _rir,
      _rpe,
      _rest,
      _load,
      _mass,
      _increment,
      _window,
      _distance,
      ..._series,
      ..._removedSeries,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) => parsePerformanceTime(c.text);
  Widget _numeric(
    TextEditingController c,
    String label, {
    bool required = true,
    bool integer = false,
    bool enabled = true,
    bool time = false,
    bool allowZero = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      enabled: enabled,
      keyboardType: time
          ? TextInputType.datetime
          : TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(
        labelText: label,
        helperMaxLines: 2,
        helperText: time ? 'Minutos:segundos (1:30) o segundos (90).' : null,
      ),
      validator: (_) {
        if (!required && c.text.trim().isEmpty) return null;
        final v = _n(c);
        return v == null ||
                !v.isFinite ||
                (allowZero ? v < 0 : v <= 0) ||
                (!time && c.text.contains(':')) ||
                v > 3600 ||
                (integer && v % 1 != 0)
            ? 'Introduce una cantidad positiva${integer ? ' entera' : ''}.'
            : null;
      },
    ),
  );
  void _changeWork(StrengthExerciseDefinition work) {
    setState(() {
      _work = work;
      if (_kind == 'official_test' && !_supportsOfficial) _kind = null;
      _mode = _workOptions
          .firstWhere(
            (m) => m.mode == _goalMode,
            orElse: () => _workOptions.first,
          )
          .mode;
      _loadMode = work.measurements
          .firstWhere((m) => m.mode == _mode)
          .loadModes
          .first;
      _confirmed = false;
      _material = false;
      _setup.clear();
      _load.clear();
      _mass.clear();
      _rir.clear();
      _rpe.clear();
      _rest.clear();
      for (final s in _series) {
        s.clear();
      }
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (!_confirmed || (!_material && _work.requiredEquipment.isNotEmpty)) {
      setState(
        () => _error = 'Confirma que los datos son reales, la técnica válida y el material disponible.',
      );
      return;
    }
    final rir = _rirRelevant ? _n(_rir) : null;
    if (_rirRelevant && rir != null && (rir < 0 || rir > 10)) {
      setState(
        () => _error =
            'Indica un margen de 0 a 10 o déjalo vacío si no lo sabes.',
      );
      return;
    }
    final rpe = !_maximum && _mode == StrengthMeasurement.duration
        ? _n(_rpe)
        : null;
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      setState(() => _error = 'Indica un esfuerzo de 1 a 10.');
      return;
    }
    // Una serie no tiene intervalo entre series: no inventamos un descanso.
    final rest = _series.length == 1 ? 0.0 : _n(_rest)!;
    if (_series.length > 1 && (rest < 30 || rest > 600)) {
      setState(() => _error = 'Registra un descanso de 30–600 segundos.');
      return;
    }
    final targets = _series
        .map((s) => _mode == StrengthMeasurement.passFail ? 1 : _n(s)!)
        .toList();
    final obj = widget.objective;
    final protocol = obj != null && _specific
        ? obj['protocol_key'] as String
        : 'working_${_work.code}_v1';
    final task = <String, dynamic>{
      'schema_version': 1,
      'exercise_code': _work.code,
      'exercise_version': _work.definitionVersion,
      'protocol_key': protocol,
      'protocol_version': obj != null && _specific
          ? obj['protocol_version']
          : 1,
      'setup_key': _setup.text.trim().isNotEmpty
          ? _setup.text.trim()
          : 'standard:$protocol:${_work.code}:${_work.definitionVersion}:${_mode.code}',
      'measurement': _mode.code,
      'load_mode': _loadMode.code,
      'policy_version': 'reference_v2',
      'target_value': targets.first,
      'intent': _maximum
          ? 'control'
          : _practice || _mode == StrengthMeasurement.passFail
          ? 'practice'
          : 'work',
      'records_stimulus_responses': _work.movementPatterns.contains(
        'reactive_agility',
      ),
      'instructions': obj != null && _specific
          ? obj['instructions']
          : _work.notes,
      if (_mode == StrengthMeasurement.repsInTime)
        'fixed_duration_seconds': _n(_window),
      if (_mode == StrengthMeasurement.timeForDistance)
        'fixed_distance_meters': _n(_distance),
      if (_loadMode != StrengthLoadMode.bodyweight && _n(_load) != null)
        'external_load_kg': _n(_load),
      if (_loadMode == StrengthLoadMode.bodyweightPlusExternal)
        'body_mass_kg': _n(_mass),
    };
    Navigator.of(context).pop(
      PerformanceReferenceInput(
        {
          'program_objective_key': obj?['program_objective_key'],
          'equipment_confirmed': _material || _work.requiredEquipment.isEmpty,
          'goal_code': _goal.code,
          'goal_version': _goal.definitionVersion,
          'goal_measurement': _goalMode.code,
          'task': task,
          'targets': targets,
          'observed_on':
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
          'current_capacity_confirmed': true,
          'reported_rir': rir,
          'reported_rpe': rpe,
          'reference_kind': _kind,
          'rest_seconds': rest.toInt(),
          'frequency': _frequency,
          'load_step_kg': _mode == StrengthMeasurement.loadReps
              ? _n(_increment)
              : null,
        },
        obj?['test_id'] as String? ?? widget.existing?['test_id'] as String?,
        _work.requiredEquipment.toSet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialog = AlertDialog(
      title: Text(
        ['Qué has realizado', 'Tu resultado real', 'Tu contexto'][_step],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Paso ${_step + 1} de 3'),
                const SizedBox(height: 12),
                if (_step == 0) ...[
                  Text(
                    'Puedes empezar con una sola serie o un intento reciente. Indica qué tipo de dato es: el motor elegirá después el trabajo, sin copiar tu máximo como entrenamiento.',
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('reference-kind-$_supportsOfficial'),
                    initialValue: _kind,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Qué estás registrando',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'performed_set',
                        child: Text('Una serie de entrenamiento'),
                      ),
                      const DropdownMenuItem(
                        value: 'repeated_work',
                        child: Text('Varias series del mismo entrenamiento'),
                      ),
                      const DropdownMenuItem(
                        value: 'capacity_test',
                        child: Text('Mi máximo con técnica válida'),
                      ),
                      if (_supportsOfficial)
                        const DropdownMenuItem(
                          value: 'official_test',
                          child: Text(
                            'Una marca con el protocolo de la prueba',
                          ),
                        ),
                    ],
                    validator: (v) =>
                        v == null ? 'Elige qué representa el dato.' : null,
                    onChanged: (v) => setState(() {
                      _kind = v;
                      if (v == 'repeated_work' && _series.length == 1) {
                        _series.add(TextEditingController());
                      }
                      if (v == 'official_test' &&
                          _specific &&
                          _workOptions.any(
                            (option) => option.mode == _goalMode,
                          )) {
                        _mode = _goalMode;
                      }
                      if (v != 'repeated_work') {
                        while (_series.length > 1) {
                          _removedSeries.add(_series.removeLast());
                        }
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (widget.objective != null)
                    Text('Prueba: ${widget.objective!['name']}')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _goal.code,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      decoration: const InputDecoration(
                        labelText: 'Movimiento que quieres mejorar',
                      ),
                      items: [
                        for (final p in widget.data.catalog)
                          DropdownMenuItem(
                            value: p.code,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: widget.existing != null
                          ? null
                          : (v) {
                              _goal = widget.data.catalog.firstWhere(
                                (p) => p.code == v,
                              );
                              _goalMode = _goal.measurements.first.mode;
                              _changeWork(_goal);
                            },
                    ),
                  if (widget.objective == null)
                    DropdownButtonFormField<StrengthMeasurement>(
                      key: ValueKey('goal_${_goal.code}'),
                      initialValue: _goalMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Qué quieres mejorar',
                      ),
                      items: [
                        for (final m in _goal.measurements)
                          DropdownMenuItem(
                            value: m.mode,
                            child: Text(performanceMeasurementLabel(m.mode)),
                          ),
                      ],
                      onChanged: widget.existing != null
                          ? null
                          : (v) {
                              _goalMode = v!;
                              _changeWork(_goal);
                            },
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('variant_${_goal.code}_${_work.code}'),
                    initialValue: _work.code,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Variante que has realizado',
                    ),
                    items: [
                      for (final p in _variants)
                        DropdownMenuItem(
                          value: p.code,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) =>
                        _changeWork(_variants.firstWhere((p) => p.code == v)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _specific
                        ? (widget.objective?['instructions'] as String? ??
                              _work.notes)
                        : 'Esta variante es un apoyo o una regresión. No equivale a una marca de la prueba. ${_work.notes}',
                  ),
                  if (_goalMode == StrengthMeasurement.maxLoad)
                    const Text(
                      'Para preparar fuerza máxima usamos una dosis submáxima con carga, no un intento máximo diario.',
                    ),
                  if (_workOptions.length > 1)
                    DropdownButtonFormField<StrengthMeasurement>(
                      key: ValueKey('work_${_work.code}_${_mode.code}'),
                      initialValue: _mode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Medición de esta práctica',
                      ),
                      items: [
                        for (final m in _workOptions)
                          DropdownMenuItem(
                            value: m.mode,
                            child: Text(performanceMeasurementLabel(m.mode)),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _mode = v!;
                        _loadMode = _work.measurements
                            .firstWhere((m) => m.mode == _mode)
                            .loadModes
                            .first;
                        for (final c in _series) {
                          c.clear();
                        }
                        _rir.clear();
                        _confirmed = false;
                      }),
                    ),
                  if (_goalMode == StrengthMeasurement.repsInTime &&
                      _mode == StrengthMeasurement.reps)
                    const Text(
                      'Esta serie submáxima prepara la base de la prueba. No es un resultado de la ventana oficial ni sustituye su práctica específica.',
                    ),
                ],
                if (_step == 1) ...[
                  Text(
                    _work.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _setup,
                    maxLength: 500,
                    maxLines: 2,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: _needsSetup
                          ? 'Cómo has preparado esta variante'
                          : 'Condiciones (opcional)',
                      helperMaxLines: 4,
                      helperText: _needsSetup
                          ? 'Indica la altura del apoyo, la banda o ayuda utilizada, o el instrumento de medición, según esta variante.'
                          : 'Vacío si seguiste las condiciones descritas. Anota solo cambios de superficie, apoyos o material.',
                    ),
                    validator: (v) => _needsSetup && (v?.trim().length ?? 0) < 3
                        ? 'Describe el apoyo, ayuda o instrumento para poder repetirlo.'
                        : null,
                  ),
                  if (_work.measurements
                          .firstWhere((m) => m.mode == _mode)
                          .loadModes
                          .length >
                      1)
                    DropdownButtonFormField<StrengthLoadMode>(
                      isExpanded: true,
                      key: ValueKey('load_${_work.code}_${_mode.code}'),
                      initialValue: _loadMode,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de carga',
                      ),
                      items: [
                        for (final m
                            in _work.measurements
                                .firstWhere((m) => m.mode == _mode)
                                .loadModes)
                          DropdownMenuItem(
                            value: m,
                            child: Text(switch (m) {
                              StrengthLoadMode.bodyweight => 'Peso corporal',
                              StrengthLoadMode.externalLoad => 'Carga externa',
                              StrengthLoadMode.bodyweightPlusExternal =>
                                'Peso corporal y lastre',
                              StrengthLoadMode.assisted => 'Asistencia',
                            }),
                          ),
                      ],
                      onChanged: (v) => setState(() => _loadMode = v!),
                    ),
                  if (_mode == StrengthMeasurement.repsInTime)
                    _numeric(
                      _window,
                      'Tiempo de la prueba',
                      time: true,
                      enabled: _parameters['fixed_duration_seconds'] == null,
                    ),
                  if (_mode == StrengthMeasurement.timeForDistance)
                    _numeric(
                      _distance,
                      'Trayecto o altura fija · metros',
                      enabled: _parameters['fixed_distance_meters'] == null,
                    ),
                  if (_mode == StrengthMeasurement.reactiveMetrics)
                    const Text(
                      'Registra segundos de contacto obtenidos con instrumento adecuado. Indica el instrumento utilizado. Un cronómetro manual no sirve.',
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Series que has realizado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (var i = 0; i < _series.length; i++)
                    Row(
                      children: [
                        Expanded(
                          child: _mode == StrengthMeasurement.passFail
                              ? Text(
                                  'Intento ${i + 1} conseguido con técnica válida',
                                )
                              : _numeric(
                                  _series[i],
                                  'Serie ${i + 1} · ${performanceMeasurementLabel(_mode)}',
                                  time: const [
                                    StrengthMeasurement.duration,
                                    StrengthMeasurement.timeForCourse,
                                    StrengthMeasurement.timeForDistance,
                                  ].contains(_mode),
                                  integer: const [
                                    StrengthMeasurement.reps,
                                    StrengthMeasurement.loadReps,
                                    StrengthMeasurement.repsInTime,
                                  ].contains(_mode),
                                ),
                        ),
                        if (_series.length > 2)
                          IconButton(
                            tooltip: 'Quitar serie ${i + 1}',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(() {
                              _removedSeries.add(_series.removeAt(i));
                            }),
                          ),
                      ],
                    ),
                  if (_kind == 'repeated_work' && _series.length < 6)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _series.add(TextEditingController())),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir serie realizada'),
                    ),
                  if (_series.length > 1)
                    _numeric(
                      _rest,
                      'Descanso entre series',
                      time: true,
                      integer: true,
                    ),
                  if (_rirRelevant) ...[
                    const Text(
                      'RIR: cuántas repeticiones más crees que podrías haber hecho con la misma técnica. '
                      'Por ejemplo: hiciste 8 y calculas que quedaban 3; registra 8 en la serie y 3 aquí. No es un máximo de 11 medido.',
                    ),
                    _numeric(
                      _rir,
                      'Repeticiones que quedaban · 0 a 10 (opcional)',
                      required: false,
                      allowZero: true,
                    ),
                  ],
                  if (!_maximum && _mode == StrengthMeasurement.duration) ...[
                    const Text(
                      '¿Cuánto esfuerzo supuso mantener la postura? 5: moderado; 7: difícil pero controlado; 10: tu límite. Si no lo sabes, déjalo vacío.',
                    ),
                    _numeric(
                      _rpe,
                      'Esfuerzo · 1 a 10 (opcional)',
                      required: false,
                    ),
                  ],
                  if (_loadMode != StrengthLoadMode.bodyweight)
                    _numeric(
                      _load,
                      _loadMode == StrengthLoadMode.assisted
                          ? 'Asistencia medida · kg (opcional para banda)'
                          : 'Carga externa utilizada · kg',
                      required: _loadMode != StrengthLoadMode.assisted,
                    ),
                  if (_loadMode == StrengthLoadMode.bodyweightPlusExternal)
                    _numeric(_mass, 'Masa corporal en esa fecha · kg'),
                  if (_mode == StrengthMeasurement.loadReps && !_practice) ...[
                    _numeric(
                      _increment,
                      'Menor aumento de carga disponible · kg',
                      required: false,
                    ),
                  ],
                ],
                if (_step == 2) ...[
                  Text(
                    '${_work.name}: ${_series.length} ${_series.length == 1 ? 'serie registrada' : 'series registradas'}. Estos datos describen lo realizado; aún no son tu entrenamiento pautado.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Sesiones por semana que ya toleras',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text('Una sesión por semana'),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('Dos sesiones por semana'),
                      ),
                    ],
                    onChanged: (v) => _frequency = v!,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      'Realizado el ${_date.day}/${_date.month}/${_date.year}',
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate:
                            _date.isBefore(
                              DateTime.now().subtract(const Duration(days: 14)),
                            )
                            ? DateTime.now()
                            : _date,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 14),
                        ),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                  if (_work.requiredEquipment.isNotEmpty)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _material,
                      onChanged: (v) => setState(() => _material = v!),
                      title: Text(
                        'Dispongo de: ${_work.requiredEquipment.map(performanceEquipmentLabel).join(', ')} y puedo seguir las condiciones de esta variante.',
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v!),
                    title: const Text(
                      'Son datos realizados, con técnica válida y sin molestias; representan mi capacidad actual',
                    ),
                  ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() {
              _step--;
              _error = null;
            }),
            child: const Text('Atrás'),
          ),
        FilledButton(
          onPressed: () {
            if (_step == 2) {
              _save();
              return;
            }
            if (!_form.currentState!.validate()) return;
            setState(() {
              _step++;
              _error = null;
            });
          },
          child: Text(_step == 2 ? 'Guardar referencia' : 'Continuar'),
        ),
      ],
    );
    if (MediaQuery.sizeOf(context).width >= 600) return dialog;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: dialog.title,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Padding(padding: const EdgeInsets.all(20), child: dialog.content),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_step > 0) dialog.actions![1],
              if (_step > 0) const SizedBox(width: 12),
              Expanded(child: dialog.actions!.last),
            ],
          ),
        ),
      ),
    );
  }
}

String performanceMeasurementLabel(StrengthMeasurement m) => switch (m) {
  StrengthMeasurement.reps => 'Repeticiones',
  StrengthMeasurement.loadReps => 'Repeticiones con carga',
  StrengthMeasurement.duration => 'Segundos válidos',
  StrengthMeasurement.repsInTime => 'Repeticiones en tiempo fijo',
  StrengthMeasurement.maxLoad => 'Fuerza máxima con carga',
  StrengthMeasurement.timeForDistance => 'Tiempo sobre trayecto fijo',
  StrengthMeasurement.timeForCourse => 'Tiempo de circuito',
  StrengthMeasurement.distance => 'Distancia · metros',
  StrengthMeasurement.height => 'Altura · metros',
  StrengthMeasurement.passFail => 'Éxito técnico',
  StrengthMeasurement.reactiveMetrics => 'Contacto medido · segundos',
};
