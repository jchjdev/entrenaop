import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/mark_input_parser.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/domain/age_on_date.dart';
import 'package:entrenaop/features/profile/presentation/choose_birth_date.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FasPeriodicCalculatorPage extends StatefulWidget {
  const FasPeriodicCalculatorPage({
    super.key,
    required this.birthDateRepository,
    required this.repository,
    this.reference,
    this.today,
  });

  final ProfileBirthDateRepository birthDateRepository;
  final FasPeriodicAssessmentRepository repository;
  final FasPeriodic2027Reference? reference;
  final DateTime? today;

  @override
  State<FasPeriodicCalculatorPage> createState() =>
      _FasPeriodicCalculatorPageState();
}

class _FasPeriodicCalculatorPageState extends State<FasPeriodicCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final test in _calculatorTests) test.id: TextEditingController(),
  };
  late final Future<FasPeriodic2027Reference> _reference;
  late Future<DateTime?> _birthDate;
  AssessmentCategory _category = AssessmentCategory.men;
  final Map<String, PeriodicScoreResult> _results = {};
  bool _savingBirthDate = false;
  bool _savingAssessment = false;
  late DateTime _assessmentDate;

  DateTime get _calculationDate => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _assessmentDate = _calculationDate;
    _reference = widget.reference == null
        ? FasPeriodic2027Reference.load()
        : Future.value(widget.reference);
    _birthDate = widget.birthDateRepository.get();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _editBirthDate(DateTime? current) async {
    final chosen = await chooseBirthDate(context, current: current);
    if (chosen == null || !mounted) return;
    setState(() => _savingBirthDate = true);
    try {
      await widget.birthDateRepository.save(chosen);
      if (!mounted) return;
      setState(() {
        _birthDate = widget.birthDateRepository.get();
        _results.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la fecha de nacimiento.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingBirthDate = false);
    }
  }

  void _recalculate(FasPeriodic2027Reference reference, int age) {
    final results = <String, PeriodicScoreResult>{};
    for (final test in _calculatorTests) {
      if (test.id == 'agility_speed_circuit' && age >= 45) continue;
      final mark = _parseMark(test.id, _controllers[test.id]!.text);
      if (mark == null) continue;
      results[test.id] = reference.scoreFor(
        testId: test.id,
        category: _category,
        age: age,
        mark: mark,
      )!;
    }
    setState(() {
      _results
        ..clear()
        ..addAll(results);
    });
  }

  Future<void> _chooseAssessmentDate(
    FasPeriodic2027Reference reference,
    DateTime birthDate,
  ) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _assessmentDate,
      firstDate: DateTime(2026, 1, 21),
      lastDate: _calculationDate,
    );
    if (chosen == null || !mounted) return;
    _assessmentDate = chosen;
    _recalculate(reference, ageOnDate(birthDate, chosen));
  }

  Future<void> _saveAssessment(int age) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingAssessment = true);
    try {
      await widget.repository.save(
        category: _category.name,
        age: age,
        completedAt: _assessmentDate,
        marks: {
          for (final test in _calculatorTests)
            if (test.id != 'agility_speed_circuit' || age < 45)
              test.id: _parseMark(test.id, _controllers[test.id]!.text)!,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test guardado en tu historial personal.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el test.')),
      );
    } finally {
      if (mounted) setState(() => _savingAssessment = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(title: const Text('Calculadora FAS 2027')),
    body: FutureBuilder<FasPeriodic2027Reference>(
      future: _reference,
      builder: (context, referenceSnapshot) {
        if (referenceSnapshot.hasError) {
          return const Center(child: Text('No se pudo cargar el baremo.'));
        }
        if (!referenceSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reference = referenceSnapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Prueba marcas. Guarda solo cuando tú quieras.',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Escribe una marca o mueve el control: los puntos cambian al instante. Nada entra en tu historial hasta que pulses Guardar test.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    if (_calculationDate.isBefore(DateTime(2027))) ...[
                      const SizedBox(height: 12),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Referencia futura: este baremo de evaluación periódica entra en vigor el 01/01/2027.',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FutureBuilder<DateTime?>(
                      future: _birthDate,
                      builder: (context, birthSnapshot) {
                        if (birthSnapshot.hasError) {
                          return _BirthDateCard(
                            title: 'No se pudo cargar tu fecha de nacimiento',
                            subtitle: 'Toca para volver a intentarlo.',
                            icon: Icons.refresh,
                            onTap: () => setState(() {
                              _birthDate = widget.birthDateRepository.get();
                            }),
                          );
                        }
                        if (birthSnapshot.connectionState !=
                            ConnectionState.done) {
                          return const LinearProgressIndicator();
                        }
                        final birthDate = birthSnapshot.data;
                        if (birthDate == null) {
                          return _BirthDateCard(
                            title: 'Completa tu fecha de nacimiento',
                            subtitle:
                                'La necesitamos para elegir el tramo de edad correcto.',
                            icon: Icons.calendar_month_outlined,
                            onTap: _savingBirthDate
                                ? null
                                : () => _editBirthDate(null),
                          );
                        }
                        final age = ageOnDate(birthDate, _assessmentDate);
                        if (age < 17 || age > 120) {
                          return _BirthDateCard(
                            title: 'Revisa tu fecha de nacimiento',
                            subtitle: 'El baremo comienza a los 17 años.',
                            icon: Icons.edit_outlined,
                            onTap: _savingBirthDate
                                ? null
                                : () => _editBirthDate(birthDate),
                          );
                        }
                        return _calculator(
                          reference: reference,
                          birthDate: birthDate,
                          age: age,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Fuente: Orden DEF/15/2026 · anexo II · catálogo ${FasPeriodic2027Reference.version} · verificado ${reference.verifiedOn}.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Nota de fuente: la tabla II.3 publicada contiene una secuencia no ordenada en sus últimos tiempos de carrera. Se conserva literalmente hasta que exista una corrección oficial.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _calculator({
    required FasPeriodic2027Reference reference,
    required DateTime birthDate,
    required int age,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BirthDateCard(
          title:
              '$age años · test del ${DateFormat('dd/MM/yyyy').format(_assessmentDate)}',
          subtitle: 'Nacimiento: ${DateFormat('dd/MM/yyyy').format(birthDate)}',
          icon: Icons.edit_outlined,
          onTap: _savingBirthDate ? null : () => _editBirthDate(birthDate),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _chooseAssessmentDate(reference, birthDate),
          icon: const Icon(Icons.event_outlined),
          label: const Text('Cambiar fecha del test'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Categoría del baremo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<AssessmentCategory>(
          segments: const [
            ButtonSegment(
              value: AssessmentCategory.men,
              label: Text('H · hombres'),
            ),
            ButtonSegment(
              value: AssessmentCategory.women,
              label: Text('M · mujeres'),
            ),
          ],
          selected: {_category},
          onSelectionChanged: (values) {
            _category = values.first;
            _recalculate(reference, age);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'H/M son las columnas que utiliza literalmente el anexo II.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            children: [
              for (final test in _calculatorTests)
                if (test.id != 'agility_speed_circuit' || age < 45)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _MarkControl(
                      test: test,
                      controller: _controllers[test.id]!,
                      range: reference.markRangeFor(testId: test.id, age: age),
                      passMark: reference
                          .passMarkFor(
                            testId: test.id,
                            category: _category,
                            age: age,
                          )
                          ?.threshold,
                      result: _results[test.id],
                      onChanged: () => _recalculate(reference, age),
                      onSliderChanged: (mark) {
                        _controllers[test.id]!.text = _formatMarkForInput(
                          test.id,
                          mark,
                        );
                        _recalculate(reference, age);
                      },
                    ),
                  ),
              if (age >= 45)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Agilidad no exigible desde el día en que se cumplen 45 años.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_results.length == (age < 45 ? 4 : 3)) ...[
          const SizedBox(height: 24),
          _Results(results: _results),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _savingAssessment ? null : () => _saveAssessment(age),
            icon: _savingAssessment
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined),
            label: const Text('Guardar test realizado'),
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => context.push('/assessment/fas-history'),
          icon: const Icon(Icons.timeline_outlined),
          label: const Text('Ver mi historial de tests FAS'),
        ),
      ],
    );
  }
}

class _MarkControl extends StatelessWidget {
  const _MarkControl({
    required this.test,
    required this.controller,
    required this.range,
    required this.passMark,
    required this.result,
    required this.onChanged,
    required this.onSliderChanged,
  });

  final ({
    String id,
    String label,
    String shortLabel,
    String hint,
    String helper,
    String error,
  })
  test;
  final TextEditingController controller;
  final PeriodicMarkRange? range;
  final int? passMark;
  final PeriodicScoreResult? result;
  final VoidCallback onChanged;
  final ValueChanged<int> onSliderChanged;

  @override
  Widget build(BuildContext context) {
    final limits = range;
    final parsed = _parseMark(test.id, controller.text);
    final fallback = passMark ?? limits?.minimum ?? 0;
    final sliderValue = limits == null
        ? 0.0
        : (parsed ?? fallback).clamp(limits.minimum, limits.maximum).toDouble();
    final step = _sliderStep(test.id);
    final divisions = limits == null
        ? null
        : ((limits.maximum - limits.minimum) / step).round();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: test.id == 'run_2000_m'
                        ? const [DurationInputFormatter()]
                        : null,
                    decoration: InputDecoration(
                      labelText: test.label,
                      hintText: test.hint,
                      helperText: test.helper,
                    ),
                    validator: (value) =>
                        _parseMark(test.id, value ?? '') == null
                        ? test.error
                        : null,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 88,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        Text(
                          result == null ? '—' : '${result!.points}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'puntos',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (limits != null)
              Slider(
                value: sliderValue,
                min: limits.minimum.toDouble(),
                max: limits.maximum.toDouble(),
                divisions: divisions,
                onChanged: (value) =>
                    onSliderChanged((value / step).round() * step),
              ),
          ],
        ),
      ),
    );
  }
}

class _BirthDateCard extends StatelessWidget {
  const _BirthDateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(icon),
      onTap: onTap,
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final Map<String, PeriodicScoreResult> results;

  @override
  Widget build(BuildContext context) {
    final meetsAll = results.values.every((result) => result.meetsMinimum);
    final total = results.values.fold<int>(
      0,
      (sum, result) => sum + result.points,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              meetsAll
                  ? 'Alcanza el mínimo general de 20 puntos por prueba'
                  : 'Hay alguna prueba por debajo de 20 puntos',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Resultado orientativo: no sustituye la evaluación ni la calificación oficial.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE65100)),
              ),
              child: Column(
                children: [
                  const Text(
                    'SUMA ORIENTATIVA',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$total puntos',
                    style: const TextStyle(
                      color: Color(0xFFFF8A50),
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    'de ${results.length * 100} posibles en las pruebas aplicables',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(height: 28),
            for (final test in _calculatorTests)
              if (results[test.id] case final result?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(test.shortLabel),
                  subtitle: Text(
                    result.meetsMinimum
                        ? 'Mínimo general alcanzado'
                        : 'Por debajo del mínimo general',
                  ),
                  trailing: Text(
                    '${result.points} puntos',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: result.meetsMinimum
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            const Text(
              'Esta suma facilita la consulta, pero la Orden DEF/15/2026 no la define como calificación oficial: la aptitud general exige alcanzar al menos 20 puntos en cada prueba aplicable.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

int? _parseMark(String testId, String value) => switch (testId) {
  'upper_body_push_ups_2_min' => parseRepetitions(value),
  'abdominal_plank' => parseWholeSecondsDuration(value),
  'run_2000_m' => parseClockToMilliseconds(value),
  'agility_speed_circuit' => parseSecondsToMilliseconds(value),
  _ => null,
};

int _sliderStep(String testId) => switch (testId) {
  'upper_body_push_ups_2_min' => 1,
  'agility_speed_circuit' => 100,
  _ => 1000,
};

String _formatMarkForInput(String testId, int mark) => switch (testId) {
  'upper_body_push_ups_2_min' => '$mark',
  'abdominal_plank' => _formatClock(mark),
  'run_2000_m' => _formatClock(mark),
  'agility_speed_circuit' =>
    (mark / 1000).toStringAsFixed(1).replaceAll('.', ','),
  _ => '$mark',
};

String _formatClock(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

const _calculatorTests = [
  (
    id: 'upper_body_push_ups_2_min',
    label: 'Flexo-extensiones en 2 min',
    shortLabel: 'Flexo-extensiones',
    hint: 'Ej.: 24',
    helper: 'Repeticiones correctas',
    error: 'Introduce un número entero de repeticiones.',
  ),
  (
    id: 'abdominal_plank',
    label: 'Plancha isométrica',
    shortLabel: 'Plancha isométrica',
    hint: 'Ej.: 1:20 o 80',
    helper: 'Minutos:segundos o segundos completos',
    error: 'Usa m:ss o segundos completos, por ejemplo 1:20.',
  ),
  (
    id: 'run_2000_m',
    label: 'Carrera 2.000 m',
    shortLabel: 'Carrera 2.000 m',
    hint: 'Ej.: 11:46',
    helper: 'Teclea 1146 y se convertirá en 11:46',
    error: 'Introduce los minutos y segundos, por ejemplo 1146.',
  ),
  (
    id: 'agility_speed_circuit',
    label: 'Circuito de agilidad-velocidad',
    shortLabel: 'Agilidad-velocidad',
    hint: 'Ej.: 15,27',
    helper: 'Segundos; las centésimas se eliminan según el anexo I',
    error: 'Introduce segundos, por ejemplo 15,27.',
  ),
];
