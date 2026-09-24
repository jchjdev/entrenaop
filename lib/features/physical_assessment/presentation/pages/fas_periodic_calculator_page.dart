import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/mark_input_parser.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/domain/age_on_date.dart';
import 'package:entrenaop/features/profile/presentation/choose_birth_date.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FasPeriodicCalculatorPage extends StatefulWidget {
  const FasPeriodicCalculatorPage({
    super.key,
    required this.birthDateRepository,
    this.reference,
    this.today,
  });

  final ProfileBirthDateRepository birthDateRepository;
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
  Map<String, PeriodicScoreResult>? _results;
  bool _savingBirthDate = false;

  DateTime get _calculationDate => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
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
        _results = null;
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

  void _calculate(FasPeriodic2027Reference reference, int age) {
    if (!_formKey.currentState!.validate()) return;
    final results = <String, PeriodicScoreResult>{};
    for (final test in _calculatorTests) {
      if (test.id == 'agility_speed_circuit' && age >= 45) continue;
      final mark = _parseMark(test.id, _controllers[test.id]!.text)!;
      results[test.id] = reference.scoreFor(
        testId: test.id,
        category: _category,
        age: age,
        mark: mark,
      )!;
    }
    setState(() => _results = results);
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
                      'Calcula tus puntos sin guardar nada',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Introduce tus marcas y verás la puntuación de cada prueba. El cálculo es gratuito, no crea un intento ni modifica tu historial.',
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
                        final age = ageOnDate(birthDate, _calculationDate);
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
          title: '$age años · tramo calculado para hoy',
          subtitle: 'Nacimiento: ${DateFormat('dd/MM/yyyy').format(birthDate)}',
          icon: Icons.edit_outlined,
          onTap: _savingBirthDate ? null : () => _editBirthDate(birthDate),
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
          onSelectionChanged: (values) => setState(() {
            _category = values.first;
            _results = null;
          }),
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
                    child: TextFormField(
                      controller: _controllers[test.id],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: test.label,
                        hintText: test.hint,
                        helperText: test.helper,
                      ),
                      validator: (value) =>
                          _parseMark(test.id, value ?? '') == null
                          ? test.error
                          : null,
                      onChanged: (_) {
                        if (_results != null) setState(() => _results = null);
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _calculate(reference, age),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Calcular puntos'),
                ),
              ),
            ],
          ),
        ),
        if (_results case final results?) ...[
          const SizedBox(height: 24),
          _Results(results: results),
        ],
      ],
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
              'La Orden DEF/15/2026 no define una suma o media total para esta calificación; por eso no mostramos una puntuación total.',
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
    helper: 'Minutos:segundos',
    error: 'Usa minutos:segundos, por ejemplo 11:46.',
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
