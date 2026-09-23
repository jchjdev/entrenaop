import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/mark_input_parser.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/domain/age_on_date.dart';
import 'package:entrenaop/features/profile/presentation/choose_birth_date.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FasPeriodicAssessmentPage extends StatefulWidget {
  const FasPeriodicAssessmentPage({
    super.key,
    required this.goalId,
    required this.repository,
    required this.birthDateRepository,
    this.reference,
  });

  final String goalId;
  final FasPeriodicAssessmentRepository repository;
  final ProfileBirthDateRepository birthDateRepository;
  final FasPeriodic2027Reference? reference;

  @override
  State<FasPeriodicAssessmentPage> createState() =>
      _FasPeriodicAssessmentPageState();
}

class _FasPeriodicAssessmentPageState extends State<FasPeriodicAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final test in _tests) test.id: TextEditingController(),
  };
  late final Future<FasPeriodic2027Reference> _reference;
  late Future<List<FasPeriodicAssessmentEntry>> _history;
  late Future<DateTime?> _birthDate;
  AssessmentCategory _category = AssessmentCategory.men;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reference = widget.reference == null
        ? FasPeriodic2027Reference.load()
        : Future.value(widget.reference);
    _history = widget.repository.history(widget.goalId);
    _birthDate = widget.birthDateRepository.get();
  }

  Future<void> _editBirthDate(DateTime? current) async {
    final chosen = await chooseBirthDate(context, current: current);
    if (chosen == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.birthDateRepository.save(chosen);
      if (!mounted) return;
      setState(() => _birthDate = widget.birthDateRepository.get());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la fecha de nacimiento.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(FasPeriodic2027Reference reference, int age) async {
    if (!_formKey.currentState!.validate()) return;
    final marks = <String, int>{};
    for (final test in _tests) {
      if (reference.passMarkFor(
            testId: test.id,
            category: _category,
            age: age,
          ) ==
          null) {
        continue;
      }
      final text = _fields[test.id]!.text;
      marks[test.id] = switch (test.id) {
        'upper_body_push_ups_2_min' => parseRepetitions(text)!,
        'run_2000_m' => parseClockToMilliseconds(text)!,
        _ => parseSecondsToMilliseconds(text)!,
      };
    }
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        goalId: widget.goalId,
        category: _category.name,
        age: age,
        marks: marks,
      );
      if (!mounted) return;
      setState(() {
        _history = widget.repository.history(widget.goalId);
        for (final controller in _fields.values) {
          controller.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcas guardadas en esta preparación.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hemos podido guardar las marcas. Revisa la conexión y vuelve a intentarlo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(title: const Text('Evaluación periódica FAS · 2027')),
    body: FutureBuilder<FasPeriodic2027Reference>(
      future: _reference,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudo cargar el baremo.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reference = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tus pruebas periódicas',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Orden DEF/15/2026, anexo II. Estas marcas son los mínimos que alcanzan al menos 20 puntos por prueba; no calculamos aquí la puntuación exacta ni certificamos aptitud oficial.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    if (DateTime.now().isBefore(DateTime(2027))) ...[
                      const SizedBox(height: 12),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Referencia de entrenamiento: el nuevo baremo periódico entra en vigor el 01/01/2027.',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FutureBuilder<DateTime?>(
                      future: _birthDate,
                      builder: (context, birthSnapshot) {
                        if (birthSnapshot.hasError) {
                          return Card(
                            child: ListTile(
                              title: const Text(
                                'No se pudo cargar tu fecha de nacimiento.',
                              ),
                              trailing: const Icon(Icons.refresh),
                              onTap: () => setState(
                                () => _birthDate = widget.birthDateRepository
                                    .get(),
                              ),
                            ),
                          );
                        }
                        if (birthSnapshot.connectionState !=
                            ConnectionState.done) {
                          return const LinearProgressIndicator();
                        }
                        final birthDate = birthSnapshot.data;
                        if (birthDate == null) {
                          return Card(
                            child: ListTile(
                              title: const Text(
                                'Indica tu fecha de nacimiento',
                              ),
                              subtitle: const Text(
                                'La edad determina qué marcas se aplican y si corresponde el circuito de agilidad.',
                              ),
                              trailing: const Icon(
                                Icons.calendar_month_outlined,
                              ),
                              onTap: _saving
                                  ? null
                                  : () => _editBirthDate(null),
                            ),
                          );
                        }
                        final age = ageOnDate(birthDate, DateTime.now());
                        if (age < 17 || age > 120) {
                          return Card(
                            child: ListTile(
                              title: const Text(
                                'Revisa tu fecha de nacimiento',
                              ),
                              subtitle: const Text(
                                'El baremo comienza a los 17 años.',
                              ),
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: _saving
                                  ? null
                                  : () => _editBirthDate(birthDate),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: ListTile(
                                title: Text(
                                  '$age años · baremo según tu edad actual',
                                ),
                                subtitle: Text(
                                  'Nacimiento: ${DateFormat('dd/MM/yyyy').format(birthDate)}',
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: _saving
                                    ? null
                                    : () => _editBirthDate(birthDate),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SegmentedButton<AssessmentCategory>(
                                    segments: const [
                                      ButtonSegment(
                                        value: AssessmentCategory.men,
                                        label: Text('Baremo H'),
                                      ),
                                      ButtonSegment(
                                        value: AssessmentCategory.women,
                                        label: Text('Baremo M'),
                                      ),
                                    ],
                                    selected: {_category},
                                    onSelectionChanged: (values) => setState(
                                      () => _category = values.first,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final test in _tests)
                                    if (reference.passMarkFor(
                                          testId: test.id,
                                          category: _category,
                                          age: age,
                                        ) !=
                                        null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 14),
                                        child: TextFormField(
                                          controller: _fields[test.id],
                                          decoration: InputDecoration(
                                            labelText: test.label,
                                            helperText:
                                                'Mínimo: ${_display(reference.passMarkFor(testId: test.id, category: _category, age: age)!.threshold, test.id)}',
                                          ),
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            final parsed = switch (test.id) {
                                              'upper_body_push_ups_2_min' =>
                                                parseRepetitions(value ?? ''),
                                              'run_2000_m' =>
                                                parseClockToMilliseconds(
                                                  value ?? '',
                                                ),
                                              _ => parseSecondsToMilliseconds(
                                                value ?? '',
                                              ),
                                            };
                                            return parsed == null
                                                ? 'Introduce una marca válida.'
                                                : null;
                                          },
                                        ),
                                      ),
                                  if (age >= 45)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 14),
                                      child: Text(
                                        'El circuito de agilidad no es obligatorio desde los 45 años.',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  FilledButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _save(reference, age),
                                    child: Text(
                                      _saving
                                          ? 'Guardando…'
                                          : 'Guardar resultado del test',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Intentos anteriores',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<FasPeriodicAssessmentEntry>>(
                      future: _history,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('No se pudo cargar el historial.');
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.data!.isEmpty) {
                          return const Text('Aún no hay intentos guardados.');
                        }
                        return Column(
                          children: [
                            for (final entry in snapshot.data!)
                              Card(
                                child: ExpansionTile(
                                  title: Text(
                                    DateFormat(
                                      'dd/MM/yyyy · HH:mm',
                                    ).format(entry.completedAt),
                                  ),
                                  subtitle: Text(
                                    '${entry.age} años · baremo ${entry.category == 'men' ? 'H' : 'M'} · ${entry.meetsAllMinimums ? 'Mínimos alcanzados' : 'Por debajo de algún mínimo'}${entry.isPreEffectiveReference ? ' · referencia previa a 2027' : ''}',
                                  ),
                                  children: [
                                    for (final mark in entry.marks)
                                      ListTile(
                                        title: Text(mark.testName),
                                        subtitle: Text(
                                          'Realizado: ${_display(mark.value, mark.testId)} · mínimo: ${_display(mark.threshold, mark.testId)}',
                                        ),
                                        trailing: Icon(
                                          mark.meetsMinimum
                                              ? Icons.check_circle
                                              : Icons.info_outline,
                                          color: mark.meetsMinimum
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
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
}

String _display(int value, String testId) {
  if (testId == 'upper_body_push_ups_2_min') return '$value rep.';
  final seconds = value ~/ 1000;
  if (testId == 'run_2000_m') {
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  final tenths = (value % 1000) ~/ 100;
  return tenths == 0 ? '$seconds s' : '$seconds,$tenths s';
}

const _tests = [
  (
    id: 'upper_body_push_ups_2_min',
    label: 'Flexo-extensiones en 2 min',
    hint: 'Repeticiones',
  ),
  (id: 'abdominal_plank', label: 'Plancha', hint: 'Segundos'),
  (id: 'run_2000_m', label: 'Carrera 2.000 m', hint: 'Tiempo m:ss'),
  (
    id: 'agility_speed_circuit',
    label: 'Circuito de agilidad',
    hint: 'Segundos con décimas',
  ),
];
