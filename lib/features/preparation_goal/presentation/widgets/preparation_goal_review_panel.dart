import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_core/performance_time.dart';

/// Presenta la evidencia que usó el servidor. No estima marcas desde series ni
/// decide cuándo realizar controles.
class PreparationGoalReviewPanel extends StatelessWidget {
  const PreparationGoalReviewPanel({required this.reviews, super.key});

  final List<Map<String, dynamic>> reviews;

  String _value(num value, String measurement) {
    if (measurement == 'DURATION') return '${formatPerformanceTime(value)} min';
    final unit = switch (measurement) {
      'TIME_FOR_COURSE' => ' s',
      'REPS' || 'REPS_IN_TIME' || 'LOAD_REPS' => ' repeticiones',
      'MAX_LOAD' => ' kg',
      'DISTANCE' || 'HEIGHT' => ' m',
      'POWER' => ' W',
      _ => '',
    };
    return '${NumberFormat('0.##', 'es').format(value)}$unit';
  }

  String _date(Object? value) {
    final observed = value is String ? DateTime.tryParse(value) : null;
    return observed == null
        ? ''
        : ' · ${DateFormat('dd/MM/yyyy').format(observed)}';
  }

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        title: const Text('Objetivos y controles'),
        subtitle: const Text('Datos usados al preparar esta semana'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final review in reviews)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    review['name'] as String? ?? 'Objetivo de la preparación',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (review['target'] case final num target)
                    Text(
                      'Tu objetivo: ${_value(target, review['measurement'] as String)}',
                    ),
                  if (review['last_protocol_mark'] case final num mark)
                    Text(
                      'Última marca del protocolo: ${_value(mark, review['measurement'] as String)}'
                      '${_date(review['observed_on'])}',
                    )
                  else
                    const Text('Sin una marca compatible del protocolo.'),
                  if (review['review_reason'] case final String reason)
                    Text(reason),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
