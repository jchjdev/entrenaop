import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_state.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/mark_input_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class InitialAssessmentPage extends StatefulWidget {
  const InitialAssessmentPage({super.key});

  @override
  State<InitialAssessmentPage> createState() => _InitialAssessmentPageState();
}

class _InitialAssessmentPageState extends State<InitialAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _pushUpsController = TextEditingController();
  final _plankController = TextEditingController();
  final _runController = TextEditingController();
  final _agilityController = TextEditingController();

  @override
  void dispose() {
    _pushUpsController.dispose();
    _plankController.dispose();
    _runController.dispose();
    _agilityController.dispose();
    super.dispose();
  }

  void _evaluate() {
    if (!_formKey.currentState!.validate()) return;

    context.read<PhysicalAssessmentCubit>().evaluate([
      RecordedMark(
        testId: ArmedForces2026TroopCatalog.upperBodyStrength.id,
        unit: MarkUnit.repetitions,
        value: parseRepetitions(_pushUpsController.text)!,
      ),
      RecordedMark(
        testId: ArmedForces2026TroopCatalog.abdominalPlank.id,
        unit: MarkUnit.milliseconds,
        value: parseSecondsToMilliseconds(_plankController.text)!,
      ),
      RecordedMark(
        testId: ArmedForces2026TroopCatalog.run2000m.id,
        unit: MarkUnit.milliseconds,
        value: parseClockToMilliseconds(_runController.text)!,
      ),
      RecordedMark(
        testId: ArmedForces2026TroopCatalog.agilityCircuit.id,
        unit: MarkUnit.milliseconds,
        value: parseSecondsToMilliseconds(_agilityController.text)!,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PhysicalAssessmentCubit, PhysicalAssessmentState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == PhysicalAssessmentStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evaluación guardada en tu historial.'),
            ),
          );
        } else if (state.status == PhysicalAssessmentStatus.failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final report = state.report;
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text(
              report == null ? 'Evaluación inicial' : 'Tu punto de partida',
            ),
          ),
          body: SafeArea(
            child: report == null
                ? _AssessmentForm(
                    formKey: _formKey,
                    state: state,
                    pushUpsController: _pushUpsController,
                    plankController: _plankController,
                    runController: _runController,
                    agilityController: _agilityController,
                    onEvaluate: _evaluate,
                  )
                : _AssessmentReportView(report: report, status: state.status),
          ),
        );
      },
    );
  }
}

class _AssessmentForm extends StatelessWidget {
  const _AssessmentForm({
    required this.formKey,
    required this.state,
    required this.pushUpsController,
    required this.plankController,
    required this.runController,
    required this.agilityController,
    required this.onEvaluate,
  });

  final GlobalKey<FormState> formKey;
  final PhysicalAssessmentState state;
  final TextEditingController pushUpsController;
  final TextEditingController plankController;
  final TextEditingController runController;
  final TextEditingController agilityController;
  final VoidCallback onEvaluate;

  @override
  Widget build(BuildContext context) {
    final standards = ArmedForces2026TroopCatalog.standards
        .where(
          (standard) =>
              standard.category == state.category &&
              standard.milestone == AssessmentMilestone.entry,
        )
        .toList(growable: false);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ingreso · Tropa y marinería',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Introduce tus marcas actuales. Las compararemos con los mínimos oficiales vigentes.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Baremo oficial',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<AssessmentCategory>(
                  segments: const [
                    ButtonSegment(
                      value: AssessmentCategory.men,
                      label: Text('Baremo H'),
                      icon: Icon(Icons.person_outline),
                    ),
                    ButtonSegment(
                      value: AssessmentCategory.women,
                      label: Text('Baremo M'),
                      icon: Icon(Icons.person_outline),
                    ),
                  ],
                  selected: {state.category},
                  onSelectionChanged: (selection) => context
                      .read<PhysicalAssessmentCubit>()
                      .selectCategory(selection.single),
                ),
                const SizedBox(height: 8),
                const Text(
                  'H/M son las columnas del baremo oficial; no definen la identidad personal.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
                _MarkFieldCard(
                  number: 1,
                  title: 'Flexo-extensiones de brazos',
                  subtitle: 'Máximo realizado en 2 minutos',
                  minimum: _minimumFor(
                    standards,
                    ArmedForces2026TroopCatalog.upperBodyStrength.id,
                  ),
                  controller: pushUpsController,
                  label: 'Repeticiones',
                  hint: 'Ej. 12',
                  suffix: 'rep',
                  keyboardType: TextInputType.number,
                  validator: (value) => parseRepetitions(value ?? '') == null
                      ? 'Introduce un número entero igual o mayor que 0.'
                      : null,
                ),
                _MarkFieldCard(
                  number: 2,
                  title: 'Plancha isométrica',
                  subtitle: 'Tiempo mantenido con técnica válida',
                  minimum: _minimumFor(
                    standards,
                    ArmedForces2026TroopCatalog.abdominalPlank.id,
                  ),
                  controller: plankController,
                  label: 'Tiempo',
                  hint: 'Ej. 45',
                  suffix: 'seg',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) =>
                      parseSecondsToMilliseconds(value ?? '') == null
                      ? 'Introduce los segundos; por ejemplo, 45.'
                      : null,
                ),
                _MarkFieldCard(
                  number: 3,
                  title: 'Carrera de 2.000 metros',
                  subtitle: 'Tiempo total en minutos y segundos',
                  minimum: _minimumFor(
                    standards,
                    ArmedForces2026TroopCatalog.run2000m.id,
                  ),
                  controller: runController,
                  label: 'Tiempo',
                  hint: 'Ej. 11:30',
                  suffix: 'mm:ss',
                  keyboardType: TextInputType.datetime,
                  validator: (value) =>
                      parseClockToMilliseconds(value ?? '') == null
                      ? 'Usa el formato minutos:segundos; por ejemplo, 11:30.'
                      : null,
                ),
                _MarkFieldCard(
                  number: 4,
                  title: 'Circuito de agilidad-velocidad',
                  subtitle: 'Se admite coma o punto decimal',
                  minimum: _minimumFor(
                    standards,
                    ArmedForces2026TroopCatalog.agilityCircuit.id,
                  ),
                  controller: agilityController,
                  label: 'Tiempo',
                  hint: 'Ej. 15,2',
                  suffix: 'seg',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) =>
                      parseSecondsToMilliseconds(value ?? '') == null
                      ? 'Introduce un tiempo válido; por ejemplo, 15,2.'
                      : null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: onEvaluate,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                    ),
                    icon: const Icon(Icons.assessment_outlined),
                    label: const Text('Evaluar mis marcas'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _minimumFor(List<AssessmentStandard> standards, String testId) {
    final standard = standards.singleWhere(
      (candidate) => candidate.test.id == testId,
    );
    return 'Mínimo: ${formatAssessmentValue(standard.threshold, standard.test)}';
  }
}

class _MarkFieldCard extends StatelessWidget {
  const _MarkFieldCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.minimum,
    required this.controller,
    required this.label,
    required this.hint,
    required this.suffix,
    required this.keyboardType,
    required this.validator,
  });

  final int number;
  final String title;
  final String subtitle;
  final String minimum;
  final TextEditingController controller;
  final String label;
  final String hint;
  final String suffix;
  final TextInputType keyboardType;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  child: Text('$number'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    minimum,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                suffixText: suffix,
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentReportView extends StatelessWidget {
  const _AssessmentReportView({required this.report, required this.status});

  final AssessmentReport report;
  final PhysicalAssessmentStatus status;

  @override
  Widget build(BuildContext context) {
    final passed = report.passedOverall;
    final accent = passed ? const Color(0xFF4CAF50) : const Color(0xFFFF9800);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      passed
                          ? Icons.verified_rounded
                          : Icons.trending_up_rounded,
                      color: accent,
                      size: 54,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      passed
                          ? 'Superas los cuatro mínimos'
                          : 'Ya tenemos tu punto de partida',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${report.passedTests} de ${report.results.length} pruebas superadas',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...report.results.map(_ResultCard.new),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    status == PhysicalAssessmentStatus.saving ||
                        status == PhysicalAssessmentStatus.saved
                    ? null
                    : () => context.read<PhysicalAssessmentCubit>().save(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                ),
                icon: status == PhysicalAssessmentStatus.saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        status == PhysicalAssessmentStatus.saved
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_upload_outlined,
                      ),
                label: Text(switch (status) {
                  PhysicalAssessmentStatus.saving => 'Guardando...',
                  PhysicalAssessmentStatus.saved => 'Guardada en mi historial',
                  PhysicalAssessmentStatus.failure => 'Reintentar guardado',
                  _ => 'Guardar en mi historial',
                }),
              ),
              const SizedBox(height: 10),
              if (status == PhysicalAssessmentStatus.saved) ...[
                OutlinedButton.icon(
                  onPressed: () => context.push('/assessment/history'),
                  icon: const Icon(Icons.timeline_rounded),
                  label: const Text('Ver mi evolución'),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                onPressed: () =>
                    context.read<PhysicalAssessmentCubit>().editAgain(),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modificar marcas'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver al inicio'),
              ),
              const SizedBox(height: 18),
              Text(
                'Baremo ${report.catalogVersion}. El servidor conserva las marcas originales y valida de nuevo el catálogo antes de guardarlas.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.result);

  final AssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.passed
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF9800);
    final test = result.standard.test;
    final favorableDifference = switch (test.betterDirection) {
      BetterDirection.higher => result.mark.value - result.standard.threshold,
      BetterDirection.lower => result.standard.threshold - result.mark.value,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF171717),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(
          result.passed ? Icons.check_circle_rounded : Icons.adjust_rounded,
          color: color,
        ),
        title: Text(
          test.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            'Tu marca: ${formatAssessmentValue(result.mark.value, test)} · '
            'Mínimo: ${formatAssessmentValue(result.standard.threshold, test)} · '
            '${result.passed ? 'Margen' : 'Diferencia'}: '
            '${favorableDifference >= 0 ? '+' : '-'}${formatAssessmentDifference(favorableDifference.abs(), test.unit)}',
            style: const TextStyle(color: Colors.white60),
          ),
        ),
        trailing: Text(
          result.passed ? 'APTA' : 'A MEJORAR',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
