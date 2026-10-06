import 'package:entrenaop/features/profile/presentation/choose_birth_date.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProgramAssessmentPage extends StatefulWidget {
  const ProgramAssessmentPage({
    super.key,
    required this.goalId,
    required this.loadGoal,
    required this.repository,
    required this.loadBirthDate,
    required this.saveBirthDate,
  });

  final String goalId;
  final Future<PreparationGoal?> Function(String goalId) loadGoal;
  final ProgramAssessmentRepository repository;
  final Future<DateTime?> Function() loadBirthDate;
  final Future<void> Function(DateTime) saveBirthDate;

  @override
  State<ProgramAssessmentPage> createState() => _ProgramAssessmentPageState();
}

class _ProgramAssessmentPageState extends State<ProgramAssessmentPage> {
  final _form = GlobalKey<FormState>();
  final _marks = <String, TextEditingController>{};
  final _attemptCounts = <String, int>{};
  final _nullAttempts = <String, bool>{};
  ProgramAssessmentRule? _rule;
  ProgramAssessmentContext? _context;
  ProgramAssessmentResult? _result;
  List<ProgramAssessmentAttempt> _history = const [];
  DateTime? _birthDate;
  DateTime _assessedOn = DateTime.now();
  String _category = 'men';
  bool _loading = true;
  bool _busy = false;
  bool _saved = false;
  String? _error;
  String? _programId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _marks.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final goal = await widget.loadGoal(widget.goalId);
      if (goal == null || goal.id != widget.goalId) {
        throw StateError('La preparación activa no está disponible.');
      }
      final rule = await widget.repository.rule(goal.programId);
      final birthDate = await widget.loadBirthDate();
      final history = await widget.repository.history(widget.goalId);
      if (!mounted) return;
      setState(() {
        _rule = rule;
        _programId = goal.programId;
        _birthDate = birthDate;
        _history = history;
        _loading = false;
      });
      await _loadContext();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo abrir la evaluación.';
        });
      }
    }
  }

  Future<void> _loadContext() async {
    if (_birthDate == null || _rule == null) return;
    setState(() {
      _busy = true;
      _context = null;
      _result = null;
      _saved = false;
      _error = null;
    });
    try {
      final context = await widget.repository.contextFor(
        _programId!,
        _category,
        _birthDate!,
        _assessedOn,
        _rule!.referenceOn,
      );
      if (mounted) setState(() => _context = context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No hay pruebas aplicables en esa fecha. Revisa la vigencia del baremo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseBirthDate() async {
    final chosen = await chooseBirthDate(context, current: _birthDate);
    if (chosen == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.saveBirthDate(chosen);
      final saved = await widget.loadBirthDate();
      if (!mounted) return;
      setState(() => _birthDate = saved);
      await _loadContext();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar la fecha de nacimiento en tu perfil.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseAssessmentDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _assessedOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Fecha en que hiciste las pruebas',
    );
    if (chosen == null || !mounted) return;
    setState(() => _assessedOn = chosen);
    await _loadContext();
  }

  String _attemptKey(ProgramAssessmentTest test, int index) =>
      index == 0 ? test.id : '${test.id}:$index';

  TextEditingController _controller(ProgramAssessmentTest test, int index) =>
      _marks.putIfAbsent(_attemptKey(test, index), TextEditingController.new);

  List<AssessmentMarkInput> _enteredMarks() => [
    for (final test in _context!.tests)
      AssessmentMarkInput(
        testId: test.id,
        attempts: [
          for (var index = 0; index < (_attemptCounts[test.id] ?? 1); index++)
            AssessmentExerciseAttempt(
              valid: !(_nullAttempts[_attemptKey(test, index)] ?? false),
              mark: _nullAttempts[_attemptKey(test, index)] == true
                  ? null
                  : double.parse(
                      _controller(test, index).text.trim().replaceAll(',', '.'),
                    ),
            ),
        ],
      ),
  ];

  bool _canAddAttempt(ProgramAssessmentTest test) {
    final count = _attemptCounts[test.id] ?? 1;
    if (count >= test.maxAttempts) return false;
    if (test.retryPolicy == 'always') return true;
    return test.retryPolicy == 'invalid_only' &&
        (_nullAttempts[_attemptKey(test, count - 1)] ?? false);
  }

  String _historyAttempts(
    ProgramAssessmentAttempt record,
    ProgramAssessmentDetail detail,
  ) {
    final item = record.marks
        .where((mark) => mark.testId == detail.testId)
        .firstOrNull;
    if (item == null) return '';
    return item.attempts
        .asMap()
        .entries
        .map((entry) {
          final attempt = entry.value;
          return '${entry.key + 1}. ${attempt.valid && attempt.mark != null ? _mark(attempt.mark!) : 'nulo'}';
        })
        .join(' · ');
  }

  Widget _attemptField(ProgramAssessmentTest test, int index) {
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
            if (value == false &&
                test.retryPolicy == 'invalid_only' &&
                index < count - 1) {
              _attemptCounts[test.id] = index + 1;
            }
            _result = null;
            _saved = false;
          }),
        ),
        if (!isNull)
          TextFormField(
            controller: _controller(test, index),
            decoration: InputDecoration(
              labelText: 'Marca',
              suffixText: _unit(test.unit),
              helperText:
                  'Precisión: ${_mark(test.markStep)} ${_unit(test.unit)}',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {
              _result = null;
              _saved = false;
            }),
            validator: (raw) {
              final value = double.tryParse(
                (raw ?? '').trim().replaceAll(',', '.'),
              );
              if (value == null ||
                  !value.isFinite ||
                  value < 0 ||
                  (test.unit != 'repetitions' && value == 0)) {
                return 'Introduce una marca válida.';
              }
              final steps = value / test.markStep;
              if ((steps - steps.round()).abs() > 0.000001) {
                return 'Usa la precisión indicada.';
              }
              return null;
            },
          ),
      ],
    );
  }

  Future<void> _preview() async {
    if (_context == null || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _result = null;
      _saved = false;
      _error = null;
    });
    try {
      final result = await widget.repository.preview(
        _programId!,
        _category,
        _birthDate!,
        _assessedOn,
        _rule!.referenceOn,
        _enteredMarks(),
      );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron valorar esas marcas. Revisa las unidades y el baremo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_result == null || _saved || _context == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        widget.goalId,
        _category,
        _birthDate!,
        _assessedOn,
        _enteredMarks(),
      );
      final history = await widget.repository.history(widget.goalId);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _history = history;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcas guardadas en esta preparación.')),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron guardar. Comprueba tu perfil y vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Evaluación del programa')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_rule != null) ...[
                    Text(
                      _rule!.stage,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Baremo ${_rule!.version} · ${_rule!.mode == 'pass_fail' ? 'Apto / no apto' : 'Puntuación'}',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Introduce las marcas que hiciste. Esta pantalla no mide la prueba mientras entrenas.',
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                    ),
                  if (_birthDate == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Para aplicar el tramo de edad necesitamos tu fecha de nacimiento.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _busy ? null : _chooseBirthDate,
                              child: const Text('Guardar fecha en el perfil'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'men', label: Text('Baremo H')),
                        ButtonSegment(value: 'women', label: Text('Baremo M')),
                      ],
                      selected: {_category},
                      onSelectionChanged: _busy
                          ? null
                          : (value) {
                              setState(() => _category = value.first);
                              _loadContext();
                            },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Selecciona la columna que establece tu convocatoria.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _chooseAssessmentDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        'Fecha de las pruebas: ${DateFormat('dd/MM/yyyy').format(_assessedOn)}',
                      ),
                    ),
                    if (_rule?.referenceOn != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Edad según fecha oficial: ${DateFormat('dd/MM/yyyy').format(_rule!.referenceOn!)}',
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_busy) const LinearProgressIndicator(),
                    if (_context != null) ...[
                      Text(
                        'Edad del baremo: ${_context!.age} años',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      if (_context!.tests.isEmpty)
                        const Text('No hay pruebas para esta columna y edad.')
                      else
                        Form(
                          key: _form,
                          child: Column(
                            children: [
                              for (final test in _context!.tests)
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          '${test.order}. ${test.name}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(test.protocol),
                                        const SizedBox(height: 10),
                                        for (
                                          var index = 0;
                                          index <
                                              (_attemptCounts[test.id] ?? 1);
                                          index++
                                        )
                                          _attemptField(test, index),
                                        if (_canAddAttempt(test))
                                          TextButton.icon(
                                            onPressed: () => setState(() {
                                              _attemptCounts[test.id] =
                                                  (_attemptCounts[test.id] ??
                                                      1) +
                                                  1;
                                              _result = null;
                                              _saved = false;
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
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy || _context!.tests.isEmpty
                            ? null
                            : _preview,
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Ver resultado'),
                      ),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _result!.passed
                                    ? 'Apto estimado'
                                    : 'No apto estimado',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              if (_result!.total != null)
                                Text('${_mark(_result!.total!)} puntos'),
                              const SizedBox(height: 10),
                              for (final detail in _result!.details)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(detail.name),
                                  subtitle: Text(
                                    '${detail.mark == null ? 'Intento nulo' : 'Marca ${_mark(detail.mark!)}'} · ${detail.minimumMark == null ? 'sin marca mínima' : 'mínimo ${_mark(detail.minimumMark!)}'}',
                                  ),
                                  trailing: Text(
                                    '${detail.passed ? 'Apto' : 'No apto'}${detail.points == null ? '' : '\n${_mark(detail.points!)} puntos'}',
                                  ),
                                ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: _busy || _saved ? null : _save,
                                child: Text(
                                  _saved
                                      ? 'Guardado en esta preparación'
                                      : 'Guardar estas marcas',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Evaluaciones anteriores',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final attempt in _history)
                      Card(
                        child: ExpansionTile(
                          title: Text(
                            '${DateFormat('dd/MM/yyyy').format(attempt.assessedOn)} · ${attempt.result.passed ? 'Apto' : 'No apto'}',
                          ),
                          subtitle: Text(
                            'Baremo ${attempt.result.version} · ${attempt.category == 'men' ? 'H' : 'M'}',
                          ),
                          children: [
                            for (final detail in attempt.result.details)
                              ListTile(
                                title: Text(detail.name),
                                subtitle: Text(
                                  _historyAttempts(attempt, detail).isEmpty
                                      ? (detail.mark == null
                                            ? 'Intento nulo'
                                            : 'Marca ${_mark(detail.mark!)}')
                                      : 'Intentos: ${_historyAttempts(attempt, detail)}',
                                ),
                                trailing: Text(
                                  detail.points == null
                                      ? (detail.passed ? 'Apto' : 'No apto')
                                      : '${_mark(detail.points!)} puntos',
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
      ),
    ),
  );
}

String _unit(String unit) => switch (unit) {
  'seconds' => 's',
  'meters' => 'm',
  _ => 'reps',
};

String _mark(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');
