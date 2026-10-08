import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/preparation_measurement_history.dart';
import 'package:entrenaop/features/physical_assessment/presentation/widgets/measurement_comparison_card.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart';
import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Solo hechos guardados: consultar aquí no calcula ni activa programas.
class PreparationMarksData {
  const PreparationMarksData({
    required this.goal,
    this.troop = const [],
    this.fas = const [],
    this.program = const [],
    this.running = const [],
    this.fasReference,
  });
  final PreparationGoal goal;
  final List<PhysicalAssessmentHistoryEntry> troop;
  final List<FasPeriodicAssessmentEntry> fas;
  final List<ProgramAssessmentAttempt> program;
  final List<RunningTestResult> running;
  final FasPeriodic2027Reference? fasReference;
  bool get isEmpty =>
      troop.isEmpty && fas.isEmpty && program.isEmpty && running.isEmpty;
}

class PreparationMarksPage extends StatefulWidget {
  const PreparationMarksPage({
    required this.goalId,
    required this.load,
    super.key,
  });
  final String goalId;
  final Future<PreparationMarksData> Function(String goalId) load;
  @override
  State<PreparationMarksPage> createState() => _PreparationMarksPageState();
}

class _PreparationMarksPageState extends State<PreparationMarksPage> {
  late Future<PreparationMarksData> _future = _load();
  PreparationMarksData? _cached;
  int _revision = 0;

  Future<PreparationMarksData> _load() async {
    final revision = ++_revision;
    final data = await widget.load(widget.goalId);
    if (data.goal.id != widget.goalId) {
      throw StateError('Preparación incorrecta.');
    }
    if (mounted && revision == _revision) {
      _cached = data;
    }
    return data;
  }

  @override
  void didUpdateWidget(covariant PreparationMarksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalId != widget.goalId) {
      _cached = null;
      _future = _load();
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      /* El error se muestra con reintento en la vista. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Marcas y resultados')),
    body: FutureBuilder<PreparationMarksData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data?.goal.id == widget.goalId
            ? snapshot.data
            : _cached;
        final loading = snapshot.connectionState != ConnectionState.done;
        if (data == null && loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron cargar las marcas.'),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar cargar marcas'),
                ),
              ],
            ),
          );
        }
        final goal = data.goal;
        final form = switch (goal.programId) {
          PreparationProgramIds.armedForcesTroopEntry => 'troop-assessment',
          PreparationProgramIds.fasPeriodicAssessment => 'periodic-assessment',
          _ => 'program-assessment',
        };
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: PageStorageKey('marks-${widget.goalId}'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loading) const LinearProgressIndicator(),
                      if (snapshot.hasError) ...[
                        const Text(
                          'No se pudieron actualizar las marcas. Sigues viendo la última consulta.',
                        ),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Reintentar actualizar'),
                        ),
                      ],
                      EntrenaCard(
                        coverImage: preparationCoverProvider(
                          goal.program.cover?.headerUrl,
                        ),
                        focalX: goal.program.cover?.headerFocalX ?? .5,
                        focalY: goal.program.cover?.headerFocalY ?? .5,
                        child: Text(
                          goal.program.name,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Consulta tus evaluaciones y controles guardados. Compara mediciones compatibles o registra nuevas marcas.',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_chart_outlined),
                        label: const Text('Registrar nuevas marcas'),
                        onPressed: () async {
                          await context.push('/plan/goal/${goal.id}/$form');
                          if (mounted) {
                            await _refresh();
                          }
                        },
                      ),
                      if (!data.isEmpty) ...[
                        MeasurementComparisonCard(
                          key: ValueKey('comparison-${goal.id}'),
                          series: preparationMeasurementHistory(
                            troop: data.troop,
                            fas: data.fas,
                            running: data.running,
                            fasReference: data.fasReference,
                          ),
                        ),
                        if (data.program.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Estas evaluaciones conservan marcas y puntos, pero no la unidad y el protocolo necesarios para compararlas.',
                            ),
                          ),
                        if (data.fas.any(
                          (e) =>
                              e.scoringVersion !=
                              FasPeriodic2027Reference.version,
                        ))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Hay resultados de otra versión del baremo. Se conservan en el historial, por separado de la comparación.',
                            ),
                          ),
                        if (data.running.any(
                          (r) => r.protocolVersion != 'run_2000m_v1',
                        ))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Hay controles con otro protocolo. Puedes consultar sus datos en el historial; esta comparación admite controles de 2 km.',
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      if (data.isEmpty)
                        const Text(
                          'Todavía no hay marcas guardadas en esta preparación.',
                        ),
                      for (final entry in data.troop) ...[
                        Tooltip(
                          message: 'Versión: ${entry.report.catalogVersion}',
                          child: Text(switch (entry.report.milestone) {
                            AssessmentMilestone.entry => 'Baremo de ingreso',
                            AssessmentMilestone.endOfGeneralMilitaryTraining =>
                              'Baremo de formación militar general',
                            AssessmentMilestone.endOfTraining =>
                              'Baremo de fin de formación',
                          }),
                        ),
                        AssessmentHistoryCard(
                          entry,
                          key: ValueKey('troop-${entry.id}'),
                        ),
                      ],
                      for (final entry in data.fas) ...[
                        Tooltip(
                          message: 'Versión: ${entry.scoringVersion}',
                          child: Text(
                            entry.scoringVersion ==
                                    FasPeriodic2027Reference.version
                                ? 'Baremo FAS 2027'
                                : 'Baremo guardado · Otra versión',
                          ),
                        ),
                        if (entry.isPreEffectiveReference)
                          const Text(
                            'Test de referencia anterior a la vigencia del baremo.',
                          ),
                        if (data.fasReference != null)
                          FasAssessmentHistoryCard(
                            key: ValueKey('fas-${entry.id}'),
                            entry: entry,
                            reference: data.fasReference!,
                          ),
                      ],
                      for (final attempt in data.program)
                        _ProgramResultCard(
                          key: ValueKey('program-${attempt.id}'),
                          attempt: attempt,
                        ),
                      if (data.running.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Controles de carrera',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final result in data.running)
                          EntrenaCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy')
                                      .format(result.completedAt),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${result.durationSeconds ~/ 60}:${(result.durationSeconds % 60).toString().padLeft(2, '0')} · RPE ${result.rpe}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Tooltip(
                                  message:
                                      'Protocolo: ${result.protocolVersion}',
                                  child: Text(
                                    result.protocolVersion == 'run_2000m_v1'
                                        ? 'Control de 2 km'
                                        : 'Control de carrera',
                                  ),
                                ),
                                if (result.averageHrBpm != null)
                                  Text('FC media: ${result.averageHrBpm} lpm'),
                                if (result.maxHrBpm != null)
                                  Text('FC máxima: ${result.maxHrBpm} lpm'),
                                if (result.splitsSeconds?.isNotEmpty ?? false)
                                  Text(
                                    'Parciales (s): ${result.splitsSeconds!.join(' · ')}',
                                  ),
                                if (result.notes?.isNotEmpty ?? false)
                                  Text(result.notes!),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ProgramResultCard extends StatelessWidget {
  const _ProgramResultCard({required this.attempt, super.key});
  final ProgramAssessmentAttempt attempt;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: PageStorageKey('program-assessment-${attempt.id}'),
      title: Text(
        '${DateFormat('dd/MM/yyyy').format(attempt.assessedOn)} · ${attempt.result.passed ? 'Apto' : 'No apto'}',
      ),
      subtitle: Text(
        'Baremo ${attempt.result.version} · ${attempt.category == 'men' ? 'H' : 'M'}',
      ),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        if (attempt.result.total case final total?)
          Text('${_number(total)} puntos totales'),
        for (final detail in attempt.result.details)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  detail.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  detail.mark == null
                      ? 'Intento nulo'
                      : 'Marca ${_number(detail.mark!)}',
                ),
                Text(
                  detail.points == null
                      ? (detail.passed ? 'Apto' : 'No apto')
                      : '${_number(detail.points!)} puntos',
                ),
                if (attempt.marks
                        .where((m) => m.testId == detail.testId)
                        .firstOrNull
                    case final mark?)
                  Text(
                    'Intentos: ${mark.attempts.map((a) => a.valid && a.mark != null ? _number(a.mark!) : 'Nulo').join(' · ')}',
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

String _number(num value) =>
    (value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toString())
        .replaceAll('.', ',');
