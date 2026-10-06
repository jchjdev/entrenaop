import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_scoring_editor.dart';
import 'package:flutter/material.dart';

class AdminProgramAttemptPreviewPage extends StatefulWidget {
  const AdminProgramAttemptPreviewPage({
    super.key,
    required this.program,
    required this.tests,
    required this.repository,
  });

  final AdminProgram program;
  final List<AdminProgramTest> tests;
  final AdminProgramRepository repository;

  @override
  State<AdminProgramAttemptPreviewPage> createState() =>
      _AdminProgramAttemptPreviewPageState();
}

class _AdminProgramAttemptPreviewPageState
    extends State<AdminProgramAttemptPreviewPage> {
  final _form = GlobalKey<FormState>();
  final _marks = <String, TextEditingController>{};
  final _attemptCounts = <String, int>{};
  final _nullAttempts = <String, bool>{};
  String _category = 'men';
  AdminContextualResult? _result;
  AdminProgramScoringRule? _loadedRule;
  DateTime? _birthDate;
  DateTime _assessedOn = DateTime.now();
  DateTime? _referenceOn;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.repository.getScoringRule(widget.program.id).then((rule) {
      if (mounted) {
        setState(() {
          _loadedRule = rule;
          _referenceOn = rule?.ageReferenceOn == null
              ? null
              : DateTime.parse(rule!.ageReferenceOn!);
        });
      }
    });
  }

  int? get _age {
    if (_birthDate == null || _loadedRule == null) return null;
    if (_loadedRule?.ageReference == 'reference_date' && _referenceOn == null) {
      return null;
    }
    if (_loadedRule?.ageReference == 'calendar_year') {
      return _assessedOn.year - _birthDate!.year;
    }
    final on = _loadedRule?.ageReference == 'reference_date'
        ? _referenceOn!
        : _assessedOn;
    var years = on.year - _birthDate!.year;
    if (on.month < _birthDate!.month ||
        (on.month == _birthDate!.month && on.day < _birthDate!.day)) {
      years--;
    }
    return years;
  }

  List<AdminProgramTest> get _applicable => widget.tests
      .where(
        (test) =>
            (test.category == 'both' || test.category == _category) &&
            _age != null &&
            _age! >= test.minAge &&
            _age! <= test.maxAge,
      )
      .toList();

  String _date(DateTime? date) => date == null
      ? 'Seleccionar fecha'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _pickDate(String field) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: field == 'birth'
          ? (_birthDate ?? DateTime(2000))
          : field == 'reference'
          ? (_referenceOn ?? _assessedOn)
          : _assessedOn,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (field == 'birth') _birthDate = picked;
      if (field == 'reference') _referenceOn = picked;
      if (field == 'assessment') _assessedOn = picked;
      _result = null;
    });
  }

  @override
  void dispose() {
    for (final controller in _marks.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _attemptKey(AdminProgramTest test, int index) =>
      index == 0 ? test.id : '${test.id}:$index';

  TextEditingController _controller(AdminProgramTest test, int index) =>
      _marks.putIfAbsent(_attemptKey(test, index), TextEditingController.new);

  bool _canAddAttempt(AdminProgramTest test) {
    final count = _attemptCounts[test.id] ?? 1;
    if (count >= test.maxAttempts) return false;
    return test.retryPolicy == 'always' ||
        test.retryPolicy == 'invalid_only' &&
            (_nullAttempts[_attemptKey(test, count - 1)] ?? false);
  }

  Widget _attemptField(AdminProgramTest test, int index) {
    final key = _attemptKey(test, index);
    final isNull = _nullAttempts[key] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (test.maxAttempts > 1) Text('Intento ${index + 1}'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Intento nulo'),
          value: isNull,
          onChanged: (value) => setState(() {
            _nullAttempts[key] = value;
            final count = _attemptCounts[test.id] ?? 1;
            if (!value &&
                test.retryPolicy == 'invalid_only' &&
                index < count - 1) {
              _attemptCounts[test.id] = index + 1;
            }
            _result = null;
          }),
        ),
        if (!isNull)
          TextFormField(
            controller: _controller(test, index),
            decoration: InputDecoration(
              labelText:
                  'Marca (${test.unit == 'seconds'
                      ? 'segundos'
                      : test.unit == 'meters'
                      ? 'metros'
                      : 'repeticiones'})',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final mark = double.tryParse(
                (value ?? '').trim().replaceAll(',', '.'),
              );
              return mark == null ||
                      !mark.isFinite ||
                      mark < 0 ||
                      (test.unit != 'repetitions' && mark == 0)
                  ? 'Introduce una marca válida.'
                  : null;
            },
          ),
      ],
    );
  }

  Future<void> _score() async {
    if (!_form.currentState!.validate()) return;
    if (_birthDate == null || _age == null || _age! < 0 || _age! > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha de nacimiento válida.'),
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final preview = await widget.repository.previewContextualAttempt(
        widget.program.id,
        _category,
        _birthDate!,
        _assessedOn,
        _referenceOn,
        [
          for (final test in _applicable)
            AdminAttemptMark(
              testId: test.id,
              attempts: [
                for (
                  var index = 0;
                  index < (_attemptCounts[test.id] ?? 1);
                  index++
                )
                  AdminExerciseAttempt(
                    valid: !(_nullAttempts[_attemptKey(test, index)] ?? false),
                    mark: _nullAttempts[_attemptKey(test, index)] == true
                        ? null
                        : double.parse(
                            _controller(
                              test,
                              index,
                            ).text.trim().replaceAll(',', '.'),
                          ),
                  ),
              ],
            ),
        ],
      );
      if (!mounted) return;
      setState(() => _result = preview);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo evaluar. Comprueba fechas, mínimos y tramos para esta edad.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Simular calificación')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.program.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Vista de comprobación para administración. No guarda marcas ni crea una evaluación del deportista.',
            ),
            const SizedBox(height: 24),
            Text(
              _loadedRule == null
                  ? 'Cargando regla de evaluación…'
                  : '${_loadedRule!.stageLabel} · ${_loadedRule!.scoringMode == 'pass_fail' ? 'Apto / no apto' : 'Puntos'}',
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'men', label: Text('Baremo H')),
                ButtonSegment(value: 'women', label: Text('Baremo M')),
              ],
              selected: {_category},
              onSelectionChanged: (value) => setState(() {
                _category = value.first;
                _result = null;
              }),
            ),
            const SizedBox(height: 8),
            const Text(
              'La columna del baremo se elige expresamente; no se deduce de la identidad del perfil.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate('birth'),
                  icon: const Icon(Icons.cake_outlined),
                  label: Text('Nacimiento: ${_date(_birthDate)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate('assessment'),
                  icon: const Icon(Icons.event),
                  label: Text('Prueba: ${_date(_assessedOn)}'),
                ),
                if (_loadedRule?.ageReference == 'reference_date')
                  Text('Fecha oficial para la edad: ${_date(_referenceOn)}'),
              ],
            ),
            if (_age != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Edad aplicable: $_age años'),
              ),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                children: [
                  for (final test in _applicable)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ejercicio ${test.displayOrder} · ${test.name}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${categoryLabel(test.category)} · resolución ${formatMark(test.markStep)}',
                            ),
                            const SizedBox(height: 12),
                            for (
                              var index = 0;
                              index < (_attemptCounts[test.id] ?? 1);
                              index++
                            )
                              _attemptField(test, index),
                            if (_canAddAttempt(test))
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _attemptCounts[test.id] =
                                      (_attemptCounts[test.id] ?? 1) + 1;
                                  _result = null;
                                }),
                                icon: const Icon(Icons.add),
                                label: const Text('Añadir intento'),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading || _applicable.isEmpty ? null : _score,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Evaluar marcas'),
            ),
            if (_applicable.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _age == null
                    ? 'Selecciona nacimiento y fecha de referencia para ver las pruebas.'
                    : 'No hay ejercicios para esta columna y edad.',
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_result!.passed ? 'Apto' : 'No apto'}${_result!.total == null ? '' : ' · ${formatMark(_result!.total)} puntos'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Edad del baremo: ${_result!.age} años'),
                      const Divider(),
                      for (final detail in _result!.details)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(detail.name),
                          subtitle: Text(
                            '${detail.mark == null ? 'Intento nulo' : 'Marca: ${formatMark(detail.mark)}'} · ${detail.minimumMark == null ? 'Sin marca mínima calculada' : 'Mínimo: ${formatMark(detail.minimumMark)}'}',
                          ),
                          trailing: Text(
                            '${detail.passed ? 'Apto' : 'No apto'}${detail.points == null ? '' : ' · ${formatMark(detail.points)} puntos'}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
