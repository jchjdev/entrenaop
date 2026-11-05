import 'package:entrenaop/features/physical_assessment/data/repositories/builtin_assessment_reference_repository.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

class FasPeriodicCalculatorPage extends StatefulWidget {
  const FasPeriodicCalculatorPage({
    super.key,
    required this.birthDateRepository,
    required this.repository,
    this.reference,
    this.references,
    this.today,
  });

  final ProfileBirthDateRepository birthDateRepository;
  final FasPeriodicAssessmentRepository repository;
  final FasPeriodic2027Reference? reference;
  final BuiltinAssessmentReferenceRepository? references;
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
  DateTime? _profileBirthDate;
  final _ageController = TextEditingController(text: '25');
  int _age = 25;
  bool _ageEdited = false;
  AssessmentCategory _category = AssessmentCategory.men;
  final Map<String, PeriodicScoreResult> _results = {};
  bool _savingAssessment = false;
  bool _writingAssessment = false;
  bool _referenceChanged = false;
  bool _updatingReference = false;
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
    _loadProfileAge();
  }

  bool get _validAgeInput {
    final age = int.tryParse(_ageController.text);
    return age != null && age >= 17 && age <= 120;
  }

  Future<void> _loadProfileAge() async {
    try {
      final birthDate = await _loadBirthDate();
      if (!mounted) return;
      _profileBirthDate = birthDate;
      if (!_ageEdited && birthDate != null) {
        final age = ageOnDate(birthDate, _assessmentDate);
        if (age >= 17 && age <= 120) {
          _age = age;
          _ageController.text = '$age';
          final reference = await _reference;
          if (mounted) _recalculate(reference, _age);
        }
      }
    } catch (_) {
      // El perfil es opcional para simular; se comprueba otra vez al guardar.
    }
  }

  void _setAge(
    int age,
    FasPeriodic2027Reference reference, {
    bool edited = true,
  }) {
    _age = age;
    _ageEdited = edited;
    _ageController.text = '$age';
    _recalculate(reference, age);
  }

  // Acotar solo lecturas permite reintentar sin duplicar un test guardado.
  Future<FasPeriodic2027Reference> _loadReference() async {
    if (widget.reference != null) return widget.reference!;
    final repository = widget.references;
    if (repository == null) return FasPeriodic2027Reference.load();
    return (await repository.load(programId: 'fas_periodic_assessment'))
        .asFas();
  }

  void _updateReference() {
    if (_updatingReference) return;
    _dismissKeyboard();
    setState(() {
      _updatingReference = true;
      _reference = _reloadReference();
      // Un rechazo inmediato puede llegar antes de montar el nuevo FutureBuilder.
      // El builder seguirá mostrando ese error con su acción de reintento.
      _reference.ignore();
    });
  }

  Future<FasPeriodic2027Reference> _reloadReference() async {
    try {
      final reference = await _loadReference();
      if (!mounted) return reference;
      _recalculate(reference, _age);
      setState(() {
        _referenceChanged = false;
      });
      return reference;
    } finally {
      if (mounted) setState(() => _updatingReference = false);
    }
  }

  Future<DateTime?> _loadBirthDate() =>
      widget.birthDateRepository.get().timeout(const Duration(seconds: 15));

  @override
  void dispose() {
    _ageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _applies(FasPeriodic2027Reference reference, String testId, int age) =>
      reference.passMarkFor(testId: testId, category: _category, age: age) !=
      null;

  void _recalculate(FasPeriodic2027Reference reference, int age) {
    final results = <String, PeriodicScoreResult>{};
    for (final test in _calculatorTests) {
      if (!_applies(reference, test.id, age)) continue;
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

  Future<void> _chooseAssessmentDate(FasPeriodic2027Reference reference) async {
    _dismissKeyboard();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _assessmentDate,
      firstDate: DateTime(2026, 1, 21),
      lastDate: _calculationDate,
    );
    if (chosen == null || !mounted) return;
    _assessmentDate = chosen;
    final birthDate = _profileBirthDate;
    final profileAge = birthDate == null ? null : ageOnDate(birthDate, chosen);
    if (!_ageEdited &&
        profileAge != null &&
        profileAge >= 17 &&
        profileAge <= 120) {
      _setAge(profileAge, reference, edited: false);
    } else {
      _recalculate(reference, _age);
    }
  }

  Future<void> _saveAssessment(FasPeriodic2027Reference reference) async {
    if (_savingAssessment ||
        _referenceChanged ||
        _updatingReference ||
        !_validAgeInput) {
      return;
    }
    _dismissKeyboard();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingAssessment = true);
    try {
      var birthDate = await _loadBirthDate();
      if (!mounted) return;
      if (birthDate == null) {
        final completeProfile = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Guardar en tu historial'),
            content: const Text(
              'Para registrar un test propio necesitamos tu fecha de nacimiento. Puedes seguir calculando sin completarla.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir calculando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Completar perfil'),
              ),
            ],
          ),
        );
        if (completeProfile != true || !mounted) return;
        final chosen = await chooseBirthDate(context);
        if (chosen == null || !mounted) return;
        await widget.birthDateRepository.save(chosen);
        birthDate = await _loadBirthDate();
        if (!mounted || birthDate == null) return;
      }
      _profileBirthDate = birthDate;
      final age = ageOnDate(birthDate, _assessmentDate);
      if (age < 17 || age > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu edad en la fecha del test queda fuera del baremo (17–120 años).',
            ),
          ),
        );
        return;
      }
      if (age != _age) {
        final recalculate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Estás simulando otra edad'),
            content: Text(
              'En la fecha del test tienes $age años según tu perfil. Para guardarlo en tu historial, recalcula primero con esa edad y revisa el resultado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir simulando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Usar mi edad'),
              ),
            ],
          ),
        );
        if (recalculate == true && mounted) {
          _setAge(age, reference, edited: false);
        }
        return;
      }
      setState(() => _writingAssessment = true);
      final marks = {
        for (final test in _calculatorTests)
          if (_applies(reference, test.id, age))
            test.id: _parseMark(test.id, _controllers[test.id]!.text)!,
      };
      if (reference.revisionId != null) {
        if (widget.references == null) {
          throw StateError('Falta el guardado versionado.');
        }
        await widget.references!.record(
          revisionId: reference.revisionId!,
          category: _category.name,
          age: age,
          completedAt: _assessmentDate,
          marks: marks,
        );
      } else {
        await widget.repository.save(
          category: _category.name,
          age: age,
          completedAt: _assessmentDate,
          marks: marks,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test guardado en tu historial personal.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final changed =
          error is PostgrestException &&
          error.details == 'builtin_reference_changed';
      if (changed) setState(() => _referenceChanged = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? 'El baremo ha cambiado. Actualízalo antes de guardar; tus marcas se conservan.'
                : 'No se pudo guardar el test.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingAssessment = false;
          _writingAssessment = false;
        });
      }
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
                  onPressed: _updatingReference ? null : _updateReference,
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
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            if (_updatingReference) const LinearProgressIndicator(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      key: const ValueKey('fas-official-criteria'),
                      child: ExpansionTile(
                        key: const PageStorageKey('fas-calculator-source'),
                        title: const Text('Fuente y criterio oficial'),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Text(
                            reference.revisionId == null
                                ? 'Orden DEF/15/2026 · anexo II · catálogo ${reference.scoringVersion} · verificado ${reference.verifiedOn}.'
                                : 'Catálogo ${reference.scoringVersion} · vigencia ${reference.referenceEffectiveFrom} · fuente ${reference.referenceSourceUrl}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reference.revisionId == null
                                ? 'La suma es orientativa. La aptitud general exige alcanzar al menos 20 puntos en cada prueba aplicable. La tabla II.3 contiene una secuencia no ordenada que se conserva literalmente hasta que exista una corrección oficial.'
                                : 'La suma es orientativa. La aptitud general exige alcanzar al menos 20 puntos en cada prueba aplicable. Se utiliza la revisión indicada, conservando su tabla y su criterio de redondeo.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    AbsorbPointer(
                      absorbing: _savingAssessment || _updatingReference,
                      child: _calculator(reference: reference, age: _age),
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
    required int age,
  }) {
    final expectedTests = _calculatorTests
        .where((test) => _applies(reference, test.id, age))
        .length;
    final isComplete = _results.length == expectedTests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AssessmentContext(
          age: age,
          ageController: _ageController,
          validAge: _validAgeInput,
          onAgeChanged: (value) {
            _ageEdited = true;
            final parsed = int.tryParse(value);
            if (parsed != null && parsed >= 17 && parsed <= 120) {
              _age = parsed;
              _recalculate(reference, parsed);
            } else {
              setState(() {});
            }
          },
          onSliderChanged: (value) {
            _dismissKeyboard();
            _setAge(value.round(), reference);
          },
          onDismissKeyboard: _dismissKeyboard,
          assessmentDate: _assessmentDate,
          onEditAssessmentDate: () => _chooseAssessmentDate(reference),
        ),
        const SizedBox(height: 10),
        SegmentedButton<AssessmentCategory>(
          direction: MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6
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
                  if (_applies(reference, test.id, age)) test,
              ];
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final useTwoColumns =
                  constraints.maxWidth >= 330 && textScale < 1.6;
              final cardWidth = useTwoColumns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return GridView.builder(
                key: const ValueKey('fas-tests-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tests.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: useTwoColumns ? 2 : 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: useTwoColumns
                      ? (constraints.maxWidth < 500
                            ? cardWidth / 0.82
                            : cardWidth / 1.55)
                      : 220 * textScale,
                ),
                itemBuilder: (context, index) {
                  final test = tests[index];
                  return _MarkControl(
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
                    onDismissKeyboard: _dismissKeyboard,
                    onSliderChanged: (mark) {
                      _dismissKeyboard();
                      _controllers[test.id]!.text = _formatMarkForInput(
                        test.id,
                        mark,
                      );
                      _recalculate(reference, age);
                    },
                  );
                },
              );
            },
          ),
        ),
        if (!_applies(reference, 'agility_speed_circuit', age)) ...[
          const SizedBox(height: 8),
          const Text(
            'Agilidad no exigible desde el día en que se cumplen 45 años.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        if (_referenceChanged) ...[
          const Text(
            'Hay una versión nueva del baremo. Puedes actualizarla conservando tus marcas.',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _updatingReference ? null : _updateReference,
            icon: const Icon(Icons.refresh),
            label: Text(
              _updatingReference ? 'Actualizando baremo…' : 'Actualizar baremo',
            ),
          ),
          const SizedBox(height: 10),
        ],
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
                onPressed:
                    !isComplete ||
                        _savingAssessment ||
                        _referenceChanged ||
                        _updatingReference ||
                        !_validAgeInput
                    ? null
                    : () => _saveAssessment(reference),
                child: _writingAssessment
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
            Expanded(child: Center(child: _buildMarkField(context))),
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

  Widget _buildMarkField(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScaler = MediaQuery.textScalerOf(context);
      final baseStyle = Theme.of(context).textTheme.titleMedium!
          .merge(_markTextStyle);
      final unitStyle = baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      );
      double measure(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textScaler: textScaler,
          textDirection: Directionality.of(context),
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      // Mantener valor y unidad dentro del campo, reservando padding y cursor.
      final available =
          (constraints.maxWidth - measure(_inputUnit(test.id), unitStyle) - 28)
              .clamp(1.0, double.infinity);
      final width = measure(
        controller.text.isEmpty ? test.hint : controller.text,
        baseStyle,
      );
      final fontSize =
          _markTextStyle.fontSize! * (available / width).clamp(0.0, 1.0);
      return TextFormField(
        key: ValueKey('fas-mark-${test.id}'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: switch (test.id) {
          'upper_body_push_ups_2_min' => null,
          'agility_speed_circuit' => [const SecondsInputFormatter()],
          _ => [const DurationInputFormatter()],
        },
        style: baseStyle.copyWith(fontSize: fontSize),
        decoration: InputDecoration(
          labelText: _inputLabel(test.id),
          hintText: test.hint,
          suffixText: _inputUnit(test.id),
          suffixStyle: unitStyle,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          errorMaxLines: 2,
          errorStyle: const TextStyle(fontSize: 11),
        ),
        validator: (value) =>
            _parseMark(test.id, value ?? '') == null ? test.error : null,
        onChanged: (_) => onChanged(),
        onTapOutside: (_) => onDismissKeyboard(),
      );
    },
  );
}

class _AssessmentContext extends StatelessWidget {
  const _AssessmentContext({
    required this.age,
    required this.ageController,
    required this.validAge,
    required this.onAgeChanged,
    required this.onSliderChanged,
    required this.onDismissKeyboard,
    required this.assessmentDate,
    required this.onEditAssessmentDate,
  });

  final int age;
  final TextEditingController ageController;
  final bool validAge;
  final ValueChanged<String> onAgeChanged;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onDismissKeyboard;
  final DateTime assessmentDate;
  final VoidCallback onEditAssessmentDate;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('fas-assessment-context'),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('fas-calculation-age'),
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Edad del cálculo',
                    suffixText: 'años',
                    errorText: validAge ? null : 'Entre 17 y 120 años',
                    errorMaxLines: 2,
                  ),
                  onChanged: onAgeChanged,
                  onTapOutside: (_) => onDismissKeyboard(),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: TextButton(
                  onPressed: onEditAssessmentDate,
                  child: Text(
                    'Test ${DateFormat('dd-MM-yyyy').format(assessmentDate)}',
                  ),
                ),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('fas-age-slider'),
            value: age.toDouble(),
            min: 17,
            max: 120,
            divisions: 103,
            label: '$age años',
            semanticFormatterCallback: (value) => '${value.round()} años',
            onChanged: onSliderChanged,
          ),
        ],
      ),
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
  fontSize: 20,
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
  'agility_speed_circuit' => 's',
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
