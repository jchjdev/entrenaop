import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_state.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PhysicalAssessmentHistoryPage extends StatelessWidget {
  const PhysicalAssessmentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Evaluación física · Tropa'),
      ),
      body:
          BlocBuilder<
            PhysicalAssessmentHistoryCubit,
            PhysicalAssessmentHistoryState
          >(
            builder: (context, state) => switch (state.status) {
              PhysicalAssessmentHistoryStatus.initial ||
              PhysicalAssessmentHistoryStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              PhysicalAssessmentHistoryStatus.failure => _HistoryError(
                message: state.errorMessage!,
                onRetry: () =>
                    context.read<PhysicalAssessmentHistoryCubit>().load(),
              ),
              PhysicalAssessmentHistoryStatus.loaded =>
                state.entries.isEmpty
                    ? const _EmptyHistory()
                    : _LoadedHistory(state: state),
            },
          ),
    );
  }
}

class _LoadedHistory extends StatelessWidget {
  const _LoadedHistory({required this.state});

  final PhysicalAssessmentHistoryState state;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<PhysicalAssessmentHistoryCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Marcas de las pruebas físicas de Tropa y Marinería. No son un test general para todos tus programas.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () async {
                      await context.push('/assessment/initial');
                      if (context.mounted) {
                        await context
                            .read<PhysicalAssessmentHistoryCubit>()
                            .load();
                      }
                    },
                    icon: const Icon(Icons.add_chart_rounded),
                    label: const Text('Repetir evaluación'),
                  ),
                  const SizedBox(height: 12),
                  _ProgressOverview(
                    assessmentCount: state.entries.length,
                    progress: state.progress,
                  ),
                  if (state.entries.first.recommendation
                      case final recommendation?) ...[
                    const SizedBox(height: 14),
                    _RecommendationCard(
                      recommendation: recommendation,
                      report: state.entries.first.report,
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Evaluaciones guardadas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...state.entries.map(_AssessmentHistoryCard.new),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.report,
  });

  final AssessmentFocusRecommendation recommendation;
  final AssessmentReport report;

  @override
  Widget build(BuildContext context) {
    final focus = report.results.singleWhere(
      (result) => result.mark.testId == recommendation.focusTestId,
    );
    final percentage = (recommendation.relativeMarginBps.abs() / 100)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    final below = recommendation.reason == AssessmentFocusReason.belowMinimum;

    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flag_outlined, color: Color(0xFFFF8A50)),
                SizedBox(width: 10),
                Text(
                  'Foco recomendado',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              focus.standard.test.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              below
                  ? 'Es la prueba con mayor distancia relativa al mínimo: $percentage % por debajo. El primer objetivo será alcanzar el baremo sin descuidar las demás.'
                  : 'Es la prueba con menor margen de seguridad: $percentage %. El siguiente objetivo será ampliar ese colchón sin perder el resto de marcas.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Criterio ${recommendation.algorithmVersion}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({
    required this.assessmentCount,
    required this.progress,
  });

  final int assessmentCount;
  final List<AssessmentProgress> progress;

  @override
  Widget build(BuildContext context) {
    final improved = progress.where((item) => item.improved).length;
    final unchanged = progress.where((item) => item.unchanged).length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF29150D), Color(0xFF151515)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE65100).withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_rounded,
            color: Color(0xFFFF8A50),
            size: 34,
          ),
          const SizedBox(height: 14),
          Text(
            assessmentCount == 1
                ? 'Ya tienes tu primera referencia'
                : '$assessmentCount evaluaciones registradas',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress.isEmpty
                ? 'La siguiente evaluación permitirá medir tu evolución prueba a prueba.'
                : '$improved mejoras y $unchanged marcas mantenidas respecto a la evaluación anterior.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          if (progress.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: progress.map(_ProgressChip.new).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip(this.progress);

  final AssessmentProgress progress;

  @override
  Widget build(BuildContext context) {
    final positive = progress.favorableDifference > 0;
    final negative = progress.favorableDifference < 0;
    final color = positive
        ? const Color(0xFF66BB6A)
        : negative
        ? const Color(0xFFFFA726)
        : Colors.white60;
    final sign = positive
        ? '+'
        : negative
        ? '-'
        : '±';

    return Chip(
      avatar: Icon(
        positive
            ? Icons.trending_up_rounded
            : negative
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded,
        color: color,
        size: 18,
      ),
      label: Text(
        '${progress.test.name}: $sign${formatAssessmentDifference(progress.favorableDifference.abs(), progress.test.unit)}',
      ),
      side: BorderSide(color: color.withValues(alpha: .4)),
      backgroundColor: color.withValues(alpha: .1),
    );
  }
}

class _AssessmentHistoryCard extends StatelessWidget {
  const _AssessmentHistoryCard(this.entry);

  final PhysicalAssessmentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final report = entry.report;
    final passed = report.passedOverall;
    final accent = passed ? const Color(0xFF66BB6A) : const Color(0xFFFFA726);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: const Color(0xFF171717),
      child: ExpansionTile(
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white54,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: .16),
          foregroundColor: accent,
          child: Text('${report.passedTests}/${report.results.length}'),
        ),
        title: Text(
          formatAssessmentDate(entry.completedAt),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Ingreso · Baremo ${report.category == AssessmentCategory.men ? 'H' : 'M'} · ${passed ? 'APTA' : 'EN PROGRESO'}',
          style: TextStyle(color: accent),
        ),
        children: report.results
            .map(
              (result) => ListTile(
                dense: true,
                title: Text(
                  result.standard.test.name,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Text(
                  formatAssessmentValue(
                    result.mark.value,
                    result.standard.test,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timeline_rounded,
                color: Colors.white38,
                size: 56,
              ),
              const SizedBox(height: 18),
              const Text(
                'Todavía no hay evaluaciones',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Registra las marcas de Tropa y Marinería para empezar a medir tu evolución en estas pruebas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => context.push('/assessment/initial'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Hacer mi primera evaluación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
