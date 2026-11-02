import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';

/// Un hueco en la agenda no acredita descanso ni un cambio de estado del plan.
class EmptyWorkoutDayCard extends StatelessWidget {
  const EmptyWorkoutDayCard({
    required this.day,
    required this.description,
    required this.action,
    super.key,
  });

  final DateTime day;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.event_note_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          DateUtils.isSameDay(day, DateTime.now())
              ? 'Hoy no tienes sesiones pautadas'
              : 'No hay sesiones pautadas para este día',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(description, style: TextStyle(color: context.visuals.textMuted)),
        const SizedBox(height: 18),
        action,
      ],
    ),
  );
}
