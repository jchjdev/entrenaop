import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WorkoutClosureLayout extends StatelessWidget {
  const WorkoutClosureLayout({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: child,
      ),
    ),
  );
}

class WorkoutClosureActions extends StatelessWidget {
  const WorkoutClosureActions({
    required this.executionId,
    required this.pendingSyncCount,
    super.key,
  });
  final String executionId;
  final int pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    final canReturn = context.canPop();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: () => canReturn ? context.pop() : context.go('/plan/week'),
          child: Text(canReturn ? 'Volver' : 'Ir a Mi semana'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: pendingSyncCount > 0
              ? null
              : () => context.go(
                  '/assessment/history/workouts/${Uri.encodeComponent(executionId)}',
                ),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(
            pendingSyncCount > 0
                ? 'Resultado pendiente de sincronizar'
                : 'Ver resultado',
          ),
        ),
      ],
    );
  }
}
