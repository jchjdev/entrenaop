import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/plan_preview/domain/plan_preview.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_scope.dart';
import 'package:flutter/material.dart';

class PlanPreviewSelector extends StatelessWidget {
  const PlanPreviewSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final state = PlanPreviewScope.stateOf(context);
    if (state == null || !state.available) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: EntrenaCard(
        tone: EntrenaCardTone.quiet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pruebas Free / Pro',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Solo desarrollo. Cambia la vista de esta cuenta sin modificar sus datos ni su suscripción.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final tier in PlanPreviewTier.values)
                  ChoiceChip(
                    label: Text(tier == PlanPreviewTier.free ? 'Free' : 'Pro'),
                    selected: state.tier == tier,
                    onSelected: state.saving
                        ? null
                        : (_) =>
                              PlanPreviewScope.controllerOf(context)!
                                  .select(tier),
                  ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 10),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
