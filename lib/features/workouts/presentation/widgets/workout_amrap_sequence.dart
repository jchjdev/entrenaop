import 'package:flutter/material.dart';

import '../../domain/entities/workout_execution.dart';
import 'workout_execution_labels.dart';

/// La misma identidad visual para consultar el circuito y elegir su parcial.
class WorkoutAmrapExerciseTile extends StatelessWidget {
  const WorkoutAmrapExerciseTile({
    super.key,
    required this.set,
    required this.onTap,
    this.imageUrl,
    this.selected,
  });
  final WorkoutExecutionSet set;
  final String? imageUrl;
  final VoidCallback onTap;
  final bool? selected;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: const Color(0xFF20252B),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: imageUrl?.trim().isNotEmpty == true
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _placeholder,
                          )
                        : _placeholder,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    set.exerciseName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${set.targetReps} repeticiones'
                    '${set.targetLoadKg == null ? '' : ' · ${workoutNumber(set.targetLoadKg!)} kg'}'
                    '${set.targetRir == null ? '' : ' · RIR ${workoutNumber(set.targetRir!)}'}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected == null
                  ? Icons.info_outline_rounded
                  : selected!
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected == true
                  ? const Color(0xFFFFA06F)
                  : Colors.white60,
            ),
          ],
        ),
      ),
    ),
  );

  static const _placeholder = Center(child: Icon(Icons.fitness_center_rounded));
}
