import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/coach_workspace_repository.dart';
import 'coach_pages.dart';
import 'coach_planning_pages.dart';
import 'coach_workspace_scope.dart';

class CoachAssignmentActions extends StatelessWidget {
  const CoachAssignmentActions({
    super.key,
    required this.assignment,
    required this.refresh,
    this.compact = false,
  });
  final CoachAssignment assignment;
  final VoidCallback refresh;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (CoachWorkspaceScope.of(context).planning == null) {
      return const SizedBox.shrink();
    }
    Future<void> open(String path) async {
      final changed = await context.push<bool>(path);
      if (changed == true && context.mounted) refresh();
    }

    final canChange =
        assignment.status == 'planned' && assignment.executionId == null;
    if (compact) {
      if (!canChange && assignment.templateId == null) {
        return const SizedBox.shrink();
      }
      return PopupMenuButton<String>(
        tooltip: 'Opciones de la sesión',
        onSelected: open,
        itemBuilder: (_) => [
          if (assignment.templateId != null)
            PopupMenuItem(
              value: coachPlanningRoute(
                'assign',
                client: assignment.clientId,
                session: assignment.templateId,
              ),
              child: const Text('Volver a pautar'),
            ),
          if (canChange) ...[
            PopupMenuItem(
              value: '/coach/move/${assignment.id}',
              child: const Text('Mover fecha'),
            ),
            PopupMenuItem(
              value: '/coach/withdraw/${assignment.id}',
              child: const Text('Retirar sesión'),
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (assignment.templateId != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.repeat),
            label: const Text('Volver a pautar'),
            onPressed: () => open(
              coachPlanningRoute(
                'assign',
                client: assignment.clientId,
                session: assignment.templateId,
              ),
            ),
          ),
        if (canChange) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Mover fecha'),
            onPressed: () => open('/coach/move/${assignment.id}'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Retirar sesión'),
            onPressed: () => open('/coach/withdraw/${assignment.id}'),
          ),
        ],
      ],
    );
  }
}

class CoachScheduleActionPage extends StatelessWidget {
  const CoachScheduleActionPage({
    super.key,
    required this.id,
    this.withdraw = false,
  });
  final String id;
  final bool withdraw;
  @override
  Widget build(BuildContext context) => CoachLoad(
    load: () =>
        CoachWorkspaceScope.of(context).controller.repository.assignment(id),
    builder: (_, a, refresh) => _ScheduleActionForm(
      key: ValueKey((a.id, a.planningRevision, a.status)),
      assignment: a,
      withdraw: withdraw,
    ),
  );
}

class _ScheduleActionForm extends StatefulWidget {
  const _ScheduleActionForm({
    super.key,
    required this.assignment,
    required this.withdraw,
  });
  final CoachAssignment assignment;
  final bool withdraw;
  @override
  State<_ScheduleActionForm> createState() => _ScheduleActionFormState();
}

class _ScheduleActionFormState extends State<_ScheduleActionForm>
    with CoachWriteState<_ScheduleActionForm> {
  late DateTime _day = widget.assignment.date;
  @override
  Widget build(BuildContext context) {
    final a = widget.assignment, scope = CoachWorkspaceScope.of(context);
    final allowed = a.status == 'planned' && a.executionId == null;
    return form(
      widget.withdraw ? 'Retirar sesión' : 'Mover sesión',
      [
        Text(a.clientName, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(a.name),
        const SizedBox(height: 16),
        if (widget.withdraw)
          const Text(
            'La sesión quedará retirada y conservará su historial. La plantilla de tu biblioteca se mantiene.',
          )
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(coachDate(_day)),
            onPressed: frozen
                ? null
                : () async {
                    final d = await coachPickDay(context, _day);
                    if (d != null && mounted) {
                      setState(() {
                        _day = d;
                        dirty = true;
                      });
                    }
                  },
          ),
        if (!allowed)
          const Text(
            'Esta sesión ya no está pendiente o tiene una ejecución. Actualiza la agenda.',
          ),
      ],
      label: widget.withdraw ? 'Confirmar retirada' : 'Confirmar nueva fecha',
      save: !allowed
          ? null
          : () => write((id) async {
              if (!widget.withdraw) {
                await scope.planning!.move(id, a, _day);
                return;
              }
              try {
                await scope.planning!.withdraw(a.id);
              } catch (e) {
                final current = await scope.controller.repository.assignment(
                  a.id,
                );
                if (current.status != 'cancelled') rethrow;
              }
            }),
    );
  }
}
