import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_editor_ui/duration_input_formatter.dart';

import '../data/admin_builtin_assessment_authoring_repository.dart';
import 'admin_builtin_assessment_authoring_values.dart';

class AdminBuiltinAssessmentPreview extends StatefulWidget {
  const AdminBuiltinAssessmentPreview({
    super.key,
    required this.revision,
    required this.repository,
    required this.enabled,
  });
  final AdminBuiltinAssessmentRevision revision;
  final AdminBuiltinAssessmentAuthoringRepository repository;
  final bool enabled;
  @override
  State<AdminBuiltinAssessmentPreview> createState() =>
      _AdminBuiltinAssessmentPreviewState();
}

class _AdminBuiltinAssessmentPreviewState
    extends State<AdminBuiltinAssessmentPreview> {
  final _form = GlobalKey<FormState>();
  final _age = TextEditingController(text: '30');
  final _marks = <String, TextEditingController>{};
  String _category = 'men', _milestone = 'entry';
  Map<String, dynamic>? _result, _before;
  bool _busy = false;
  String? _error;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant AdminBuiltinAssessmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        widget.repository != oldWidget.repository ||
        widget.revision.id != oldWidget.revision.id ||
        widget.revision.editVersion != oldWidget.revision.editVersion) {
      _generation++;
      _result = null;
      _before = null;
      _error = null;
      _busy = false;
    }
  }

  @override
  void dispose() {
    _age.dispose();
    for (final controller in _marks.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {
    _generation++;
    _result = null;
    _before = null;
    _error = null;
    _busy = false;
  });

  List<Map> get _tests {
    final tests = (widget.revision.definition['tests'] as List).cast<Map>();
    if (!widget.revision.isFas) return tests;
    final age = int.tryParse(_age.text);
    if (age == null) return [];
    return tests.where((test) {
      final below = test['requiredBelowAge'] as int?;
      return below == null || age < below;
    }).toList();
  }

  int? _value(Map test) {
    final raw = _marks[test['id']]?.text.trim() ?? '';
    if (test['unit'] == 'repetitions') return int.tryParse(raw);
    final seconds = parsePerformanceTime(raw);
    if (seconds == null) return null;
    final millis = seconds * 1000;
    if ((millis - millis.round()).abs() > .00001) return null;
    return millis.round();
  }

  Future<void> _simulate() async {
    if (_busy || !widget.enabled || !_form.currentState!.validate()) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _before = null;
    });
    final tests = _tests;
    final marks = [
      for (final test in tests)
        {'test_id': test['id'] as String, 'value': _value(test)!},
    ];
    Future<Map<String, dynamic>> calculate(String id) =>
        widget.repository.preview(
          revisionId: id,
          category: _category,
          marks: marks,
          age: widget.revision.isFas ? int.parse(_age.text) : null,
          milestone: widget.revision.isFas ? null : _milestone,
        );
    try {
      final values = await Future.wait([
        calculate(widget.revision.id),
        if (widget.revision.baseId != null) calculate(widget.revision.baseId!),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = values.first;
        _before = values.length > 1 ? values.last : null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'No se pudo simular esta versión. Las marcas introducidas se conservan.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Simular y comparar resultados'),
    subtitle: const Text('No guarda evaluaciones ni modifica preparaciones.'),
    childrenPadding: const EdgeInsets.all(16),
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.enabled)
              const Text(
                'Guarda los cambios para simular la versión exacta del borrador.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ['men', 'women'])
                  ChoiceChip(
                    label: Text(category == 'men' ? 'Hombres' : 'Mujeres'),
                    selected: _category == category,
                    onSelected: _busy
                        ? null
                        : (_) {
                            _category = category;
                            _changed();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.revision.isFas)
              TextFormField(
                controller: _age,
                decoration: const InputDecoration(
                  labelText: 'Edad en la evaluación',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _changed(),
                validator: (raw) {
                  final age = int.tryParse(raw ?? '');
                  return age == null || age < 17 || age > 120
                      ? 'Indica una edad entre 17 y 120 años.'
                      : null;
                },
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _milestone,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Hito de la simulación',
                ),
                items: [
                  for (final group in [
                    'entry',
                    'end_of_general_military_training',
                    'end_of_training',
                  ])
                    DropdownMenuItem(
                      value: group,
                      child: Text(
                        builtinGroup(group),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        _milestone = value!;
                        _changed();
                      },
              ),
            for (final test in _tests) ...[
              const SizedBox(height: 12),
              Text(test['name'] as String),
              const SizedBox(height: 4),
              TextFormField(
                key: ValueKey('builtin-preview-${test['id']}'),
                controller: _marks.putIfAbsent(
                  test['id'] as String,
                  TextEditingController.new,
                ),
                enabled: !_busy,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: test['unit'] != 'repetitions',
                ),
                inputFormatters: [
                  if (test['unit'] == 'repetitions')
                    FilteringTextInputFormatter.digitsOnly,
                  if (test['unit'] != 'repetitions' &&
                      test['id'] != 'agility_speed_circuit')
                    const DurationInputFormatter(allowFraction: true),
                ],
                decoration: InputDecoration(
                  labelText: test['unit'] == 'repetitions'
                      ? 'Repeticiones'
                      : test['id'] == 'agility_speed_circuit'
                      ? 'Segundos (ej.: 13,25)'
                      : 'Tiempo (min:seg)',
                ),
                onChanged: (_) => _changed(),
                validator: (_) {
                  final value = _value(test);
                  return value == null || value < 0
                      ? 'Introduce una marca válida, con hasta tres decimales.'
                      : null;
                },
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: !widget.enabled || _busy ? null : _simulate,
              icon: const Icon(Icons.calculate_outlined),
              label: Text(_busy ? 'Simulando…' : 'Simular estas marcas'),
            ),
            if (_error != null) Text(_error!),
            if (_result != null) ...[
              const SizedBox(height: 16),
              Text(
                _result!['meets_all_minimums'] == true
                    ? 'Cumple todos los mínimos de esta versión.'
                    : 'No cumple todos los mínimos de esta versión.',
              ),
              if (widget.revision.isFas)
                const Text(
                  'Se muestran puntos por prueba, sin inventar una puntuación total.',
                ),
              for (final raw in _result!['results'] as List)
                _resultRow(raw as Map),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _resultRow(Map row) {
    final previous = (_before?['results'] as List? ?? [])
        .cast<Map>()
        .where((item) => item['test_id'] == row['test_id'])
        .firstOrNull;
    String outcome(Map item) =>
        '${item['meets_minimum'] == true ? 'Cumple mínimo' : 'No cumple mínimo'}${item['points'] == null ? '' : ' · ${item['points']} puntos'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(row['name'] as String),
            if (previous != null) Text('Base: ${outcome(previous)}'),
            Text('Versión seleccionada: ${outcome(row)}'),
            Text(
              'Marca: ${builtinMark((row['mark'] as num).toInt(), row['unit'] as String, row['test_id'] as String)}',
            ),
            if (row['scored_mark'] != null && row['scored_mark'] != row['mark'])
              Text(
                'Marca usada para puntuar: ${builtinMark((row['scored_mark'] as num).toInt(), row['unit'] as String, row['test_id'] as String)}',
              ),
          ],
        ),
      ),
    );
  }
}
