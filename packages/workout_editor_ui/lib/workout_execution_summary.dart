import 'package:flutter/material.dart';
import 'package:workout_core/workout_result_review.dart';

class WorkoutExecutionSummary extends StatelessWidget {
  const WorkoutExecutionSummary({super.key, required this.review});
  final ReviewSession review;

  @override
  Widget build(BuildContext context) {
    final summary = ReviewExecutionSummary(review);
    if (summary.total == 0 &&
        summary.amrapResults == 0 &&
        summary.amrapWithoutResult == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No hay registros suficientes para resumir esta ejecución.',
          ),
        ),
      );
    }
    final metrics = <String>[
      if (summary.total > 0)
        '${summary.completed}/${summary.total} series o tramos completados',
      if (summary.matching > 0)
        '${summary.matching} con medidas dentro de la pauta',
      if (summary.different > 0) '${summary.different} con diferencias medidas',
      if (summary.missing > 0) '${summary.missing} sin medidas suficientes',
      if (summary.uncertain > 0)
        '${summary.uncertain} con condiciones a revisar',
      if (summary.withoutReference > 0)
        '${summary.withoutReference} sin referencia comparable',
      if (summary.skipped > 0) '${summary.skipped} omitidos',
      if (summary.pending > 0) '${summary.pending} sin completar',
      if (summary.amrapResults > 0)
        '${summary.amrapResults} bloques AMRAP con rondas registradas',
      if (summary.amrapWithoutResult > 0)
        '${summary.amrapWithoutResult} bloques AMRAP sin resultado agregado',
    ];
    return Card(
      key: const ValueKey('workout-execution-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen de la ejecución',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final text in metrics)
                  Chip(label: Text(text, softWrap: true, maxLines: 4)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Las diferencias no son una nota deportiva. Los datos incompletos se muestran aparte; los AMRAP se revisan por rondas.',
            ),
          ],
        ),
      ),
    );
  }
}
