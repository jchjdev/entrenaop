import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:workout_core/strength_exercise_catalog.dart';

class AdminPerformanceStrategySection extends StatefulWidget {
  const AdminPerformanceStrategySection({
    required this.program,
    required this.tests,
    required this.repository,
    super.key,
  });
  final AdminProgram program;
  final List<AdminProgramTest> tests;
  final AdminProgramRepository repository;
  @override
  State<AdminPerformanceStrategySection> createState() =>
      _AdminPerformanceStrategySectionState();
}

class _AdminPerformanceStrategySectionState
    extends State<AdminPerformanceStrategySection> {
  late Future<AdminPerformanceSetup> _setup = widget.repository
      .loadPerformanceSetup(widget.program.id);
  Future<void> _edit(
    AdminProgramTest test,
    AdminPerformanceSetup setup,
    Map<String, dynamic>? binding,
  ) async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RetainedSaveDialog<Map<String, dynamic>>(
        save: (value) => widget.repository.savePerformanceStrategy(
          test.id,
          value.isEmpty ? null : value,
        ),
        errorMessage: 'No se pudo guardar la estrategia. Revisa sus datos e inténtalo otra vez; el formulario se conserva.',
        builder: (_, submit, saving, error, markDirty) => _StrategyDialog(
          test: test,
          setup: setup,
          binding: binding,
          onSubmit: submit,
          saving: saving,
          error: error,
          onDirtyChanged: markDirty,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _setup = widget.repository.loadPerformanceSetup(widget.program.id);
      _setup.ignore();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminPerformanceSetup>(
    future: _setup,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('No se pudo consultar la cobertura de fuerza.');
      }
      final data = snapshot.data;
      if (data == null) return const LinearProgressIndicator();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cómo se prepara cada prueba',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Vincula la tarea y sus condiciones. El motor elegirá dosis y apoyos según la capacidad y los resultados de cada persona; no necesitas diseñar su rutina individual.',
          ),
          for (final test in widget.tests.where(
            (t) => t.measurementProtocol != 'run_2000m_v1',
          ))
            Builder(
              builder: (context) {
                final binding = data.bindings
                    .where((b) => b['test_id'] == test.id)
                    .firstOrNull;
                final profile = data.profiles
                    .where(
                      (p) =>
                          p.code == binding?['profile_code'] &&
                          p.definitionVersion == binding?['profile_version'],
                    )
                    .firstOrNull;
                return Card(
                  child: ListTile(
                    title: Text(test.name),
                    subtitle: Text(
                      binding == null
                          ? 'Sin estrategia de fuerza vinculada'
                          : profile?.name ?? 'Variante vinculada',
                    ),
                    trailing: widget.program.enabled
                        ? const Icon(Icons.lock_outline)
                        : TextButton(
                            onPressed: () => _edit(test, data, binding),
                            child: Text(
                              binding == null ? 'Configurar' : 'Revisar',
                            ),
                          ),
                  ),
                );
              },
            ),
          if (widget.program.enabled)
            const Text(
              'Para cambiar una estrategia publicada, crea una nueva versión del programa.',
            ),
        ],
      );
    },
  );
}

class _StrategyDialog extends StatefulWidget {
  const _StrategyDialog({
    required this.test,
    required this.setup,
    this.binding,
    required this.onSubmit,
    required this.saving,
    required this.error,
    required this.onDirtyChanged,
  });
  final AdminProgramTest test;
  final AdminPerformanceSetup setup;
  final Map<String, dynamic>? binding;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  final bool saving;
  final String? error;
  final ValueChanged<bool> onDirtyChanged;
  @override
  State<_StrategyDialog> createState() => _StrategyDialogState();
}

class _StrategyDialogState extends State<_StrategyDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController(), _condition = TextEditingController();
  StrengthExerciseDefinition? _profile;
  StrengthMeasurement? _mode;
  bool _confirmed = false;
  late final String _initialSnapshot;
  String get _snapshot => jsonEncode([
    _note.text,
    _condition.text,
    _profile?.code,
    _profile?.definitionVersion,
    _mode?.code,
    _confirmed,
  ]);
  void _markDirty() => widget.onDirtyChanged(_snapshot != _initialSnapshot);
  void _change(VoidCallback change) {
    setState(change);
    _markDirty();
  }

  List<StrengthMeasurement> _modes(StrengthExerciseDefinition p) => p
      .measurements
      .map((o) => o.mode)
      .where(
        (m) => switch (m) {
          StrengthMeasurement.reps || StrengthMeasurement.repsInTime =>
            widget.test.unit == 'repetitions' &&
                widget.test.betterDirection == 'higher',
          StrengthMeasurement.duration =>
            widget.test.unit == 'seconds' &&
                widget.test.betterDirection == 'higher',
          StrengthMeasurement.timeForDistance ||
          StrengthMeasurement.timeForCourse =>
            widget.test.unit == 'seconds' &&
                widget.test.betterDirection == 'lower',
          StrengthMeasurement.distance || StrengthMeasurement.height =>
            widget.test.unit == 'meters' &&
                widget.test.betterDirection == 'higher',
          _ => false,
        },
      )
      .toList();
  @override
  void initState() {
    super.initState();
    _profile = widget.setup.profiles
        .where(
          (p) =>
              p.code == widget.binding?['profile_code'] &&
              p.definitionVersion == widget.binding?['profile_version'],
        )
        .firstOrNull;
    _mode = StrengthMeasurement.values
        .where((m) => m.code == widget.binding?['measurement_mode'])
        .firstOrNull;
    _note.text = widget.binding?['review_note'] as String? ?? '';
    final params = widget.binding?['training_parameters'] as Map?;
    _condition.text =
        (params?['fixed_duration_seconds'] ?? params?['fixed_distance_meters'])
            ?.toString() ??
        '';
    _initialSnapshot = _snapshot;
  }

  @override
  void dispose() {
    _note.dispose();
    _condition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Preparar ${widget.test.name}'),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          onChanged: _markDirty,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.error != null)
                Text(
                  widget.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Text(widget.test.protocolNotes),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _profile == null
                    ? null
                    : '${_profile!.code}:${_profile!.definitionVersion}',
                isExpanded: true,
                menuMaxHeight: 300,
                decoration: const InputDecoration(
                  labelText: 'Variante exacta de la prueba',
                ),
                items: [
                  for (final p in widget.setup.profiles.where(
                    (p) => _modes(p).isNotEmpty,
                  ))
                    DropdownMenuItem(
                      value: '${p.code}:${p.definitionVersion}',
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                validator: (v) =>
                    v == null ? 'Selecciona una variante compatible.' : null,
                onChanged: (v) => _change(() {
                  _profile = widget.setup.profiles.firstWhere(
                    (p) => '${p.code}:${p.definitionVersion}' == v,
                  );
                  _mode = _modes(_profile!).first;
                  _confirmed = false;
                }),
              ),
              if (_profile != null)
                DropdownButtonFormField<StrengthMeasurement>(
                  key: ValueKey(_profile!.code),
                  initialValue: _mode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Resultado que mide la prueba',
                  ),
                  items: [
                    for (final m in _modes(_profile!))
                      DropdownMenuItem(
                        value: m,
                        child: Text(switch (m) {
                          StrengthMeasurement.reps => 'Máximas repeticiones',
                          StrengthMeasurement.repsInTime =>
                            'Repeticiones en ventana fija',
                          StrengthMeasurement.duration => 'Duración válida',
                          StrengthMeasurement.timeForDistance =>
                            'Tiempo sobre distancia o altura fija',
                          StrengthMeasurement.timeForCourse =>
                            'Tiempo de recorrido identificado',
                          StrengthMeasurement.distance => 'Distancia',
                          StrengthMeasurement.height => 'Altura',
                          _ => m.code,
                        }),
                      ),
                  ],
                  onChanged: (v) => _change(() => _mode = v),
                ),
              if (_mode == StrengthMeasurement.repsInTime ||
                  _mode == StrengthMeasurement.timeForDistance)
                TextFormField(
                  controller: _condition,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _mode == StrengthMeasurement.repsInTime
                        ? 'Ventana oficial · segundos'
                        : 'Distancia o altura fija · metros',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    return n == null || !n.isFinite || n <= 0
                        ? 'Introduce la condición oficial.'
                        : null;
                  },
                ),
              TextFormField(
                controller: _note,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Justificación y revisión del protocolo',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? 'Explica la correspondencia con la prueba.'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: (v) => _change(() => _confirmed = v!),
                title: const Text(
                  'He comprobado que variante, medición y condiciones corresponden al protocolo; compartir músculos no basta',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      if (widget.binding != null)
        TextButton(
          onPressed: () => widget.onSubmit(<String, dynamic>{}),
          child: const Text('Desvincular'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: !_confirmed
            ? null
            : () {
                if (!_form.currentState!.validate()) return;
                widget.onSubmit({
                  'profile_code': _profile!.code,
                  'profile_version': _profile!.definitionVersion,
                  'measurement_mode': _mode!.code,
                  'review_note': _note.text.trim(),
                  'training_parameters': {
                    if (_mode == StrengthMeasurement.repsInTime)
                      'fixed_duration_seconds': double.parse(
                        _condition.text.replaceAll(',', '.'),
                      ),
                    if (_mode == StrengthMeasurement.timeForDistance)
                      'fixed_distance_meters': double.parse(
                        _condition.text.replaceAll(',', '.'),
                      ),
                  },
                });
              },
        child: Text(widget.saving ? 'Guardando…' : 'Guardar estrategia'),
      ),
    ],
  );
}
