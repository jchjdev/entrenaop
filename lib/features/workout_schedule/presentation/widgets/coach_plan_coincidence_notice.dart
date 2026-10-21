import 'package:flutter/material.dart';

import '../../domain/entities/scheduled_workout.dart';
import '../../domain/services/coach_plan_coincidence.dart';

class CoachPlanCoincidenceNotice extends StatelessWidget {
  const CoachPlanCoincidenceNotice({
    super.key,
    required this.workouts,
    required this.day,
  });

  final Iterable<ScheduledWorkout> workouts;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    if (!hasCoachPlanCoincidence(workouts, day)) {
      return const SizedBox.shrink();
    }
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dos planificaciones el mismo día',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tienes entrenamientos de tu preparador y de tu plan automático en esta fecha. Revísalos con tu preparador antes de realizarlos. Ambos se mantienen en tu agenda.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
