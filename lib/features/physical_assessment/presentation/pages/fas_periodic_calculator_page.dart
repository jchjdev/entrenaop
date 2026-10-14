import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/mark_input_parser.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/seconds_input_formatter.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/domain/age_on_date.dart';
import 'package:entrenaop/features/profile/presentation/choose_birth_date.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late Future<FasPeriodic2027Reference> _reference;
  Future<DateTime?>? _birthDate;
  AssessmentCategory _category = AssessmentCategory.men;
  final Map<String, PeriodicScoreResult> _results = {};
  bool _savingBirthDate = false;
  bool _savingAssessment = false;
  late DateTime _assessmentDate;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    // El teclado decimal de iOS no tiene «Hecho» y puede sobrevivir al pop.
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  DateTime get _calculationDate => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _assessmentDate = _calculationDate;
    _reference = _loadReference();
  }

  // Acotar solo lecturas permite reintentar sin duplicar un test guardado.
  Future<FasPeriodic2027Reference> _loadReference() =>
      (widget.reference == null
              ? FasPeriodic2027Reference.load()
              : Future.value(widget.reference!))
          .timeout(const Duration(seconds: 15));

  Future<DateTime?> _loadBirthDate() =>
      widget.birthDateRepository.get().timeout(const Duration(seconds: 15));

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _editBirthDate(DateTime? current) async {
    _dismissKeyboard();
    final chosen = await chooseBirthDate(context, current: current);
    if (chosen == null || !mounted) return;
    setState(() => _savingBirthDate = true);
    try {
      await widget.birthDateRepository.save(chosen);
      if (!mounted) return;
      setState(() {
        _birthDate = _loadBirthDate();
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
    _dismissKeyboard();
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
    _dismissKeyboard();
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
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _dismissKeyboard();
    },
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calculadora FAS 2027')),
    body: FutureBuilder<FasPeriodic2027Reference>(
      future: _reference,
      builder: (context, referenceSnapshot) {
        if (referenceSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar el baremo.'),
                TextButton(
                  onPressed: () =>
                      setState(() => _reference = _loadReference()),
                  child: const Text('Reintentar cargar el baremo'),
                ),
              ],
            ),
          );
        }
        if (!referenceSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reference = referenceSnapshot.data!;
        // Empezar esta lectura cuando su FutureBuilder ya se va a montar evita
        // perder errores rápidos mientras todavía se carga el baremo.
        _birthDate ??= _loadBirthDate();
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      key: const ValueKey('fas-official-criteria'),
                      child: ExpansionTile(
                        title: const Text('Fuente y criterio oficial'),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Text(
                            'Orden DEF/15/2026 · anexo II · catálogo ${FasPeriodic2027Reference.version} · verificado ${reference.verifiedOn}.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'La suma es orientativa. La aptitud general exige alcanzar al menos 20 puntos en cada prueba aplicable. La tabla II.3 contiene una secuencia no ordenada que se conserva literalmente hasta que exista una corrección oficial.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<DateTime?>(
                      future: _birthDate,
                      builder: (context, birthSnapshot) {
                        if (birthSnapshot.hasError) {
                          return _BirthDateCard(
                            title: 'No se pudo cargar tu fecha de nacimiento',
                            subtitle: 'Comprueba la conexión y toca para reintentar. Las marcas que hayas escrito se conservan.',
                            icon: Icons.refresh,
                            onTap: () => setState(() {
                              _birthDate = _loadBirthDate();
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
                            subtitle: 'La necesitamos para elegir el tramo de edad correcto.',
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
    final expectedTests = age < 45 ? 4 : 3;
    final isComplete = _results.length == expectedTests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AssessmentContext(
          age: age,
          birthDate: birthDate,
          assessmentDate: _assessmentDate,
          onEditBirthDate: _savingBirthDate
              ? null
              : () => _editBirthDate(birthDate),
          onEditAssessmentDate: () =>
              _chooseAssessmentDate(reference, birthDate),
        ),
        const SizedBox(height: 10),
        SegmentedButton<AssessmentCategory>(
          direction: MediaQuery.textScalerOf(context).scale(1) > 1.2
              ? Axis.vertical
              : Axis.horizontal,
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
        const SizedBox(height: 10),
        _Results(results: _results, expectedTests: expectedTests),
        const SizedBox(height: 10),
        Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tests = [
                for (final test in _calculatorTests)
                  if (test.id != 'agility_speed_circuit' || age < 45) test,
              ];
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final clock = TextPainter(
                text: TextSpan(
                  text: '00:00.000',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.merge(_markTextStyle),
                ),
                textScaler: MediaQuery.textScalerOf(context),
                textDirection: Directionality.of(context),
              )..layout();
              // Reservar la marca completa, el cursor y ambos márgenes.
              final minimumCardWidth = clock.width + 48;
              clock.dispose();
              final useTwoColumns =
                  constraints.maxWidth >= 330 &&
                  (constraints.maxWidth - 10) / 2 >= minimumCardWidth &&
                  textScale <= 1.2;
              final cardWidth = useTwoColumns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                key: const ValueKey('fas-tests-grid'),
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final test in tests)
                    SizedBox(
                      width: cardWidth,
                      child: _MarkControl(
                        test: test,
                        controller: _controllers[test.id]!,
                        range: reference.markRangeFor(
                          testId: test.id,
                          age: age,
                        ),
                        passMark: reference
                            .passMarkFor(
                              testId: test.id,
                              category: _category,
                              age: age,
                            )
                            ?.threshold,
                        result: _results[test.id],
                        onChanged: () => _recalculate(reference, age),
                        onDismissKeyboard: _dismissKeyboard,
                        onSliderChanged: (mark) {
                          _dismissKeyboard();
                          _controllers[test.id]!.text = _formatMarkForInput(
                            test.id,
                            mark,
                          );
                          _recalculate(reference, age);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (age >= 45) ...[
          const SizedBox(height: 8),
          const Text(
            'Agilidad no exigible desde el día en que se cumplen 45 años.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _dismissKeyboard();
                  context.push('/assessment/fas-history');
                },
                child: const Text('Historial'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: !isComplete || _savingAssessment
                    ? null
                    : () => _saveAssessment(age),
                child: _savingAssessment
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar test'),
              ),
            ),
          ],
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
    required this.onDismissKeyboard,
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
  final VoidCallback onDismissKeyboard;
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    test.shortLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  result == null ? '— pt' : '${result!.points} pt',
                  style: TextStyle(
                    color: result == null
                        ? Colors.white54
                        : const Color(0xFFFF8A50),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('fas-mark-${test.id}'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: switch (test.id) {
                'upper_body_push_ups_2_min' => null,
                'agility_speed_circuit' => [const SecondsInputFormatter()],
                _ => [const DurationInputFormatter()],
              },
              style: _markTextStyle,
              decoration: InputDecoration(
                labelText: _inputLabel(test.id),
                hintText: test.hint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              validator: (value) =>
                  _parseMark(test.id, value ?? '') == null ? test.error : null,
              onChanged: (_) => onChanged(),
              onTapOutside: (_) => onDismissKeyboard(),
            ),
            const SizedBox(height: 4),
            Text(
              _inputUnit(test.id),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (limits != null) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: sliderValue,
                  min: limits.minimum.toDouble(),
                  max: limits.maximum.toDouble(),
                  divisions: divisions,
                  onChanged: (value) =>
                      onSliderChanged((value / step).round() * step),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatRangeLabel(test.id, limits.minimum),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    _formatRangeLabel(test.id, limits.maximum),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssessmentContext extends StatelessWidget {
  const _AssessmentContext({
    required this.age,
    required this.birthDate,
    required this.assessmentDate,
    required this.onEditBirthDate,
    required this.onEditAssessmentDate,
  });

  final int age;
  final DateTime birthDate;
  final DateTime assessmentDate;
  final VoidCallback? onEditBirthDate;
  final VoidCallback onEditAssessmentDate;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('fas-assessment-context'),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEditBirthDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$age años',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Nacimiento ${DateFormat('dd/MM/yyyy').format(birthDate)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            child: TextButton(
              onPressed: onEditAssessmentDate,
              child: Text(
                'Test ${DateFormat('dd/MM/yyyy').format(assessmentDate)}',
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
  const _Results({required this.results, required this.expectedTests});

  final Map<String, PeriodicScoreResult> results;
  final int expectedTests;

  @override
  Widget build(BuildContext context) {
    final complete = results.length == expectedTests;
    final meetsAll =
        complete && results.values.every((result) => result.meetsMinimum);
    final total = results.values.fold<int>(
      0,
      (sum, result) => sum + result.points,
    );
    return Card(
      key: const ValueKey('fas-score-summary'),
      margin: EdgeInsets.zero,
      color: const Color(0xFFE65100).withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    results.isEmpty ? '—' : '$total puntos',
                    style: const TextStyle(
                      color: Color(0xFFFF8A50),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text(
                results.isEmpty
                    ? 'Introduce una marca o mueve un control'
                    : !complete
                    ? '${results.length}/$expectedTests pruebas con marca'
                    : meetsAll
                    ? '$expectedTests/$expectedTests mínimos alcanzados'
                    : 'Hay pruebas bajo 20 puntos',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: complete
                      ? (meetsAll ? Colors.greenAccent : Colors.orangeAccent)
                      : Colors.white70,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _markTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  height: 1,
);

int? _parseMark(String testId, String value) => switch (testId) {
  'upper_body_push_ups_2_min' => parseRepetitions(value),
  'abdominal_plank' => parseWholeSecondsDuration(value),
  'run_2000_m' => parseClockToMilliseconds(value),
  'agility_speed_circuit' => parseSecondsToMilliseconds(value),
  _ => null,
};

String _inputLabel(String testId) => switch (testId) {
  'upper_body_push_ups_2_min' => 'Repeticiones',
  'abdominal_plank' => 'Duración',
  'run_2000_m' => 'Tiempo',
  'agility_speed_circuit' => 'Tiempo',
  _ => 'Marca',
};

String _inputUnit(String testId) => switch (testId) {
  'upper_body_push_ups_2_min' => 'rep',
  'abdominal_plank' => 'min:seg',
  'run_2000_m' => 'min:seg',
  'agility_speed_circuit' => 'segundos',
  _ => '',
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

String _formatRangeLabel(String testId, int mark) => switch (testId) {
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
  return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
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
    hint: '00:00',
    helper: 'Teclea 120 para 01:20; los dos puntos se añaden solos',
    error: 'Usa minutos:segundos, por ejemplo 01:20.',
  ),
  (
    id: 'run_2000_m',
    label: 'Carrera 2.000 m',
    shortLabel: 'Carrera 2.000 m',
    hint: '00:00',
    helper: 'Teclea 1146 y se convertirá en 11:46',
    error: 'Introduce los minutos y segundos, por ejemplo 1146.',
  ),
  (
    id: 'agility_speed_circuit',
    label: 'Circuito de agilidad-velocidad',
    shortLabel: 'Agilidad-velocidad',
    hint: '00,00',
    helper: 'Segundos decimales; las centésimas se eliminan según el anexo I',
    error: 'Introduce segundos decimales, por ejemplo 15,27.',
  ),
];
