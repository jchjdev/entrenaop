import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_state.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';

class WorkoutSchedulePage extends StatelessWidget {
  const WorkoutSchedulePage({super.key, this.focusedWorkoutId});

  final String? focusedWorkoutId;

  @override
  Widget build(BuildContext context) {
    return SectionRefreshBoundary(
      location: '/plan/week',
      onVisible: () => context.read<WorkoutScheduleCubit>().load(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Mi semana'),
        ),
        floatingActionButton:
            BlocBuilder<WorkoutScheduleCubit, WorkoutScheduleState>(
              buildWhen: (previous, current) =>
                  previous.publicTemplates != current.publicTemplates ||
                  previous.personalTemplates != current.personalTemplates ||
                  previous.programs != current.programs ||
                  previous.selectedDay != current.selectedDay,
              builder: (context, state) => state.currentProgram != null
                  ? FloatingActionButton.small(
                      onPressed: () => _showTemplatePicker(context, state),
                      tooltip: 'Añadir un entrenamiento extra',
                      child: const Icon(Icons.add_rounded),
                    )
                  : FloatingActionButton.extended(
                      onPressed: () => _showTemplatePicker(context, state),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Entrenamiento extra'),
                    ),
            ),
        body: BlocConsumer<WorkoutScheduleCubit, WorkoutScheduleState>(
          listenWhen: (previous, current) =>
              previous.errorMessage != current.errorMessage &&
              current.errorMessage != null,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          },
          builder: (context, state) {
            if (state.status == WorkoutScheduleStatus.initial ||
                (state.status == WorkoutScheduleStatus.loading &&
                    !state.hasLoaded)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == WorkoutScheduleStatus.failure &&
                !state.hasLoaded) {
              return _Failure(
                onRetry: context.read<WorkoutScheduleCubit>().load,
              );
            }
            return _ScheduleContent(
              state: state,
              focusedWorkoutId: focusedWorkoutId,
            );
          },
        ),
      ),
    );
  }
}

Future<void> _showTemplatePicker(
  BuildContext context,
  WorkoutScheduleState state,
) async {
  final selected = await showModalBottomSheet<WorkoutTemplateSummary>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _TemplatePicker(
      date: state.selectedDay,
      personal: state.personalTemplates,
      public: state.publicTemplates,
    ),
  );
  if (selected == null || !context.mounted) return;
  final success = await context.read<WorkoutScheduleCubit>().schedule(selected);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        success
            ? '“${selected.name}” añadida a ${_longDate(state.selectedDay)}.'
            : 'No hemos podido añadir la sesión.',
      ),
    ),
  );
}

class _ScheduleContent extends StatefulWidget {
  const _ScheduleContent({required this.state, this.focusedWorkoutId});

  final WorkoutScheduleState state;
  final String? focusedWorkoutId;

  @override
  State<_ScheduleContent> createState() => _ScheduleContentState();
}

class _ScheduleContentState extends State<_ScheduleContent> {
  final _focusedKey = GlobalKey();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusSession();
  }

  @override
  void didUpdateWidget(covariant _ScheduleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedWorkoutId != widget.focusedWorkoutId) _focused = false;
    _focusSession();
  }

  void _focusSession() {
    if (_focused || widget.focusedWorkoutId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focused) return;
      final target = _focusedKey.currentContext;
      if (target == null) return;
      _focused = true;
      Scrollable.ensureVisible(target, alignment: .1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return RefreshIndicator(
      onRefresh: context.read<WorkoutScheduleCubit>().load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WeekHeader(state: state),
                  const SizedBox(height: 14),
                  if (state.currentProgram case final program?)
                    _ProgramProgressCard(
                      program: program,
                      displayedWeek: state.weekStart,
                    ),
                  _DaySelector(state: state),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _longDate(state.selectedDay),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              state.selectedItems.isEmpty
                                  ? 'Sin sesión pautada'
                                  : '${state.selectedItems.length} ${state.selectedItems.length == 1 ? 'sesión' : 'sesiones'}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      if (state.status == WorkoutScheduleStatus.loading)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (state.selectedItems.isEmpty)
                    _EmptyDay(
                      hasProgram: state.currentProgram != null,
                      hasSavedPreparations: state.programs.isNotEmpty,
                      onAdd: () => _showTemplatePicker(context, state),
                      onPrepare: () => context.push('/plan/goal'),
                    )
                  else
                    ...state.selectedItems.map(
                      (item) => Padding(
                        key: item.id == widget.focusedWorkoutId
                            ? _focusedKey
                            : null,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ScheduledWorkoutCard(
                          item: item,
                          busy: state.busyItemId == item.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramProgressCard extends StatelessWidget {
  const _ProgramProgressCard({
    required this.program,
    required this.displayedWeek,
  });
  final AdaptiveProgramProgress program;
  final DateTime displayedWeek;

  @override
  Widget build(BuildContext context) {
    final week = program.currentWeek;
    final future = week != null && displayedWeek.isAfter(week);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(program.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(program.message),
            if (future &&
                program.isStarted &&
                !program.isPaused &&
                program.status != 'complete')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Esta semana futura aún no tiene sesiones. Se preparará con tu evolución; no tienes que crearla.',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!program.isPaused && week != null && displayedWeek != week)
                  TextButton.icon(
                    onPressed: () => context
                        .read<WorkoutScheduleCubit>()
                        .changeWeek(week.difference(displayedWeek).inDays ~/ 7),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Ir a mis entrenamientos'),
                  ),
                TextButton(
                  onPressed: () =>
                      context.push('/plan/goal/${program.goalId}/training'),
                  child: Text(
                    program.isPaused
                        ? 'Retomar mi programa'
                        : program.needsReview
                        ? 'Revisar lo pendiente'
                        : program.isStarted
                        ? 'Ver mi programa'
                        : 'Empezar mi programa',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.state});

  final WorkoutScheduleState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Semana anterior',
          onPressed: () => context.read<WorkoutScheduleCubit>().changeWeek(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                'SEMANA',
                style: TextStyle(
                  color: Color(0xFFFF8A50),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_shortDate(state.weekStart)} – ${_shortDate(state.weekEnd)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Semana siguiente',
          onPressed: () => context.read<WorkoutScheduleCubit>().changeWeek(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.state});

  final WorkoutScheduleState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        final dayWidth = ((constraints.maxWidth - 6 * spacing) / 7).clamp(
          36.0,
          74.0,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(7, (index) {
              final day = state.weekStart.add(Duration(days: index));
              final selected = _sameDate(day, state.selectedDay);
              final count = state.items
                  .where((item) => _sameDate(item.scheduledDate, day))
                  .length;
              return Padding(
                padding: EdgeInsets.only(right: index == 6 ? 0 : spacing),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () =>
                      context.read<WorkoutScheduleCubit>().selectDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: dayWidth,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : context.visuals.surface,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : context.visuals.outline,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdays[index],
                          style: TextStyle(
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : context.visuals.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: count == 0
                                ? Colors.transparent
                                : selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _ScheduledWorkoutCard extends StatelessWidget {
  const _ScheduledWorkoutCard({required this.item, required this.busy});

  final ScheduledWorkout item;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final canModify =
        item.status == ScheduledWorkoutStatus.planned &&
        item.preparationGoalId == null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _SourceBadge(source: item.source),
                  const Spacer(),
                  if (busy)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (canModify)
                    PopupMenuButton<_ScheduleAction>(
                      enabled: !busy,
                      tooltip: 'Opciones',
                      onSelected: (action) => switch (action) {
                        _ScheduleAction.reschedule => _reschedule(context),
                        _ScheduleAction.cancel => _cancel(context),
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _ScheduleAction.reschedule,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.event_repeat_rounded),
                            title: Text('Reprogramar'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ScheduleAction.cancel,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.event_busy_outlined),
                            title: Text('Retirar de la semana'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.templateName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (item.preparationGoalId != null) ...[
                const SizedBox(height: 6),
                const Text(
                  'Sesión oficial pautada por EntrenaOP',
                  style: TextStyle(
                    color: Color(0xFFFFA477),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _Meta(
                    icon: Icons.schedule_rounded,
                    text: item.scheduledTime == null
                        ? 'Sin hora'
                        : item.scheduledTime!.substring(0, 5),
                  ),
                  if (item.estimatedDurationMinutes case final minutes?)
                    _Meta(icon: Icons.timelapse_rounded, text: '$minutes min'),
                  _Meta(
                    icon: Icons.history_rounded,
                    text: 'v${item.templateVersion}',
                  ),
                  _Meta(
                    icon: _statusIcon(item.status),
                    text: _statusLabel(item.status),
                  ),
                ],
              ),
              if (item.status == ScheduledWorkoutStatus.planned ||
                  item.status == ScheduledWorkoutStatus.inProgress) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : () => _open(context),
                  icon: Icon(
                    item.status == ScheduledWorkoutStatus.inProgress
                        ? Icons.play_circle_outline_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    item.status == ScheduledWorkoutStatus.inProgress
                        ? 'Continuar sesión'
                        : 'Comenzar sesión',
                  ),
                ),
              ],
              if ((item.status == ScheduledWorkoutStatus.completed ||
                      item.status == ScheduledWorkoutStatus.abandoned) &&
                  item.executionId != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _open(context),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Ver resultado'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    if ((item.status == ScheduledWorkoutStatus.completed ||
            item.status == ScheduledWorkoutStatus.abandoned) &&
        item.executionId != null) {
      await context.push('/assessment/history/workouts/${item.executionId}');
      if (context.mounted) await context.read<WorkoutScheduleCubit>().load();
      return;
    }
    if (item.status == ScheduledWorkoutStatus.planned ||
        item.status == ScheduledWorkoutStatus.inProgress) {
      await _start(context);
    }
  }

  Future<void> _start(BuildContext context) async {
    final executionId = await context.read<WorkoutScheduleCubit>().start(
      item.id,
    );
    if (executionId != null && context.mounted) {
      await context.push('/plan/week/active/$executionId');
      if (context.mounted) await context.read<WorkoutScheduleCubit>().load();
    }
  }

  Future<void> _reschedule(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: item.scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Reprogramar sesión',
    );
    if (selected == null || !context.mounted) return;
    await context.read<WorkoutScheduleCubit>().reschedule(item.id, selected);
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirar sesión'),
        content: const Text(
          'La sesión desaparecerá de la semana, pero su plantilla y su historial no se borrarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<WorkoutScheduleCubit>().cancel(item.id);
    }
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.date,
    required this.personal,
    required this.public,
  });

  final DateTime date;
  final List<WorkoutTemplateSummary> personal;
  final List<WorkoutTemplateSummary> public;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Añadir sesión',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _longDate(date),
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if (personal.isNotEmpty) ...[
                    const _PickerSectionTitle('Mis sesiones'),
                    ...personal.map(
                      (template) => _TemplateTile(template: template),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const _PickerSectionTitle('Biblioteca'),
                  if (public.isEmpty)
                    const ListTile(title: Text('No hay sesiones disponibles.'))
                  else
                    ...public.map(
                      (template) => _TemplateTile(template: template),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final WorkoutTemplateSummary template;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.fitness_center_rounded,
          color: Color(0xFFFF8A50),
        ),
        title: Text(template.name),
        subtitle: Text(
          template.estimatedDurationMinutes == null
              ? 'Versión ${template.version}'
              : '${template.estimatedDurationMinutes} min · versión ${template.version}',
        ),
        trailing: const Icon(Icons.add_circle_outline_rounded),
        onTap: () => context.pop(template),
      ),
    );
  }
}

class _PickerSectionTitle extends StatelessWidget {
  const _PickerSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final ScheduledWorkoutSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x26FF8A50),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        switch (source) {
          ScheduledWorkoutSource.library => 'BIBLIOTECA',
          ScheduledWorkoutSource.user => 'PERSONAL',
          ScheduledWorkoutSource.preparation => 'PREPARACIÓN',
          ScheduledWorkoutSource.algorithm => 'ADAPTATIVA',
          ScheduledWorkoutSource.coach => 'ENTRENADOR',
        },
        style: const TextStyle(
          color: Color(0xFFFFB08A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({
    required this.onAdd,
    required this.onPrepare,
    required this.hasProgram,
    required this.hasSavedPreparations,
  });

  final VoidCallback onAdd;
  final VoidCallback onPrepare;
  final bool hasProgram;
  final bool hasSavedPreparations;

  @override
  Widget build(BuildContext context) {
    if (hasProgram) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay entrenamiento pautado para este día. Sigue las sesiones de tu programa y respeta los días de descanso.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.event_available_rounded, size: 42),
            const SizedBox(height: 10),
            const Text(
              'No hay sesiones programadas',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              hasSavedPreparations
                  ? 'No tienes un programa en curso. Puedes activar o retomar una preparación desde Mi plan.'
                  : 'Empieza una preparación para recibir tus entrenamientos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onPrepare,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                hasSavedPreparations
                    ? 'Ver mis preparaciones'
                    : 'Elegir mi preparación',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Entrenamiento extra'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    );
  }
}

enum _ScheduleAction { reschedule, cancel }

const _weekdays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _shortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1].substring(0, 3)}';

String _longDate(DateTime date) =>
    '${_weekdayNames[date.weekday - 1]}, ${date.day} de ${_months[date.month - 1]}';

const _weekdayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _statusLabel(ScheduledWorkoutStatus status) => switch (status) {
  ScheduledWorkoutStatus.planned => 'Pendiente',
  ScheduledWorkoutStatus.inProgress => 'En curso',
  ScheduledWorkoutStatus.completed => 'Completada',
  ScheduledWorkoutStatus.abandoned => 'Abandonada',
  ScheduledWorkoutStatus.skipped => 'Omitida',
};

IconData _statusIcon(ScheduledWorkoutStatus status) => switch (status) {
  ScheduledWorkoutStatus.planned => Icons.pending_outlined,
  ScheduledWorkoutStatus.inProgress => Icons.play_circle_outline_rounded,
  ScheduledWorkoutStatus.completed => Icons.check_circle_outline_rounded,
  ScheduledWorkoutStatus.abandoned => Icons.cancel_outlined,
  ScheduledWorkoutStatus.skipped => Icons.skip_next_rounded,
};
