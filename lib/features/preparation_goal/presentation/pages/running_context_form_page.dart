import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dart:convert';

class RunningContextFormPage extends StatefulWidget {
  const RunningContextFormPage({
    required this.goalId,
    required this.goals,
    required this.loadContext,
    required this.saveContext,
    this.loadPreferences,
    this.loadSharedAvailability,
    super.key,
  });

  final Future<Map<int, int>> Function()? loadSharedAvailability;
  final String goalId;
  final PreparationGoalRepository goals;
  final Future<RunningInitialContext?> Function({
    required String goalId,
    required String programId,
  })
  loadContext;
  final Future<void> Function(RunningInitialContext) saveContext;
  final Future<TrainingPreferences?> Function()? loadPreferences;

  @override
  State<RunningContextFormPage> createState() => _RunningContextFormPageState();
}

class _RunningContextFormPageState extends State<RunningContextFormPage> {
  static const _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  final _available = <int>{};
  final _target = TextEditingController();
  final _margin = TextEditingController();
  String _goalMode = 'improve';
  final _strength = <int>{};
  final _minutesByDay = [
    for (var i = 0; i < 7; i++) TextEditingController(text: '45'),
  ];
  final _daysByWeek = [for (var i = 0; i < 4; i++) TextEditingController()];
  final _minutesByWeek = [for (var i = 0; i < 4; i++) TextEditingController()];
  PreparationGoal? _goal;
  bool _loading = true;
  bool _saving = false;
  bool _oldHistory = false;
  bool? _pain;
  bool? _review;
  int? _comfortableMinutes;
  bool _noRecentRunning = false;
  int? _normalSessionMinutes = 45;
  int _qualityWeeksLastFour = 0;
  String? _error;
  String? _savedStamp;
  String get _stamp => jsonEncode([
    _available.toList()..sort(),
    _strength.toList()..sort(),
    _target.text,
    _margin.text,
    _goalMode,
    [
      for (final c in [..._minutesByDay, ..._daysByWeek, ..._minutesByWeek])
        c.text,
    ],
    _pain,
    _review,
    _comfortableMinutes,
    _noRecentRunning,
    _normalSessionMinutes,
    _qualityWeeksLastFour,
  ]);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _target,
      _margin,
      ..._minutesByDay,
      ..._daysByWeek,
      ..._minutesByWeek,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime get _lastCompletedWeekStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastSunday = today.subtract(Duration(days: today.weekday));
    return lastSunday.subtract(const Duration(days: 6));
  }

  Future<void> _load() async {
    try {
      final goal = (await widget.goals.getActiveGoals())
          .where((item) => item.id == widget.goalId)
          .firstOrNull;
      if (goal == null) throw StateError('La preparación activa no existe.');
      final existing = await widget.loadContext(
        goalId: widget.goalId,
        programId: goal.programId,
      );
      TrainingPreferences? preferences;
      try {
        preferences = await widget.loadPreferences?.call();
      } catch (_) {
        // Las preferencias precargan la duración; un fallo no bloquea la captura.
      }
      final shared = await widget.loadSharedAvailability?.call();
      if (!mounted) return;
      setState(() {
        _goal = goal;
        if (existing != null) {
          _available.addAll(existing.availableMinutesByWeekday.keys);
          _strength.addAll(existing.reservedStrengthWeekdays);
          for (final entry in existing.availableMinutesByWeekday.entries) {
            _minutesByDay[entry.key - 1].text = '${entry.value}';
          }
          if (existing.recentRunningWeeks.isNotEmpty &&
              _sameDay(
                existing.recentRunningWeeks.first.weekStart,
                _lastCompletedWeekStart,
              )) {
            for (
              var i = 0;
              i < existing.recentRunningWeeks.length && i < 4;
              i++
            ) {
              _daysByWeek[i].text =
                  '${existing.recentRunningWeeks[i].runningDays}';
              _minutesByWeek[i].text =
                  '${existing.recentRunningWeeks[i].runningMinutes}';
            }
            _noRecentRunning =
                existing.recentRunningWeeks.length == 4 &&
                existing.recentRunningWeeks.every(
                  (week) => week.runningDays == 0 && week.runningMinutes == 0,
                );
          } else {
            _oldHistory = true;
          }
          _pain = existing.health?.reportsPain;
          _review = existing.health?.requiresProfessionalReview;
          _comfortableMinutes = existing.comfortableContinuousMinutes;
          _qualityWeeksLastFour = existing.qualityWeeksLastFour;
          if (existing.targetTwoKilometreSeconds case final seconds?) {
            _goalMode = 'time';
            _target.text =
                '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
          }
          if (existing.officialMarginSeconds case final seconds?) {
            _goalMode = 'official_margin';
            _margin.text = '$seconds';
          }
          final distinctDurations = existing.availableMinutesByWeekday.values
              .toSet();
          _normalSessionMinutes = distinctDurations.length == 1
              ? distinctDurations.first
              : null;
        } else if (preferences != null) {
          _normalSessionMinutes = preferences.sessionDurationMinutes;
          for (final controller in _minutesByDay) {
            controller.text = '${preferences.sessionDurationMinutes}';
          }
        }
        if (shared != null && shared.values.any((minutes) => minutes > 0)) {
          _available
            ..clear()
            ..addAll(
              shared.entries.where((e) => e.value >= 20).map((e) => e.key),
            );
          _strength.clear();
          for (final e in shared.entries) {
            _minutesByDay[e.key - 1].text = '${e.value}';
          }
        }
        _loading = false;
        _savedStamp = _stamp;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los datos.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_goal == null || _saving) return;
    int? targetSeconds;
    final target = _target.text.trim();
    if (_goalMode == 'time') {
      final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(target);
      if (match != null) {
        targetSeconds =
            int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
      }
      if (targetSeconds == null ||
          targetSeconds < 240 ||
          targetSeconds > 1800) {
        setState(
          () => _error =
              'Escribe la meta como minutos:segundos, entre 4:00 y 30:00.',
        );
        return;
      }
    }
    final margin = _goalMode == 'official_margin'
        ? int.tryParse(_margin.text.trim())
        : null;
    if (_goalMode == 'official_margin' &&
        (margin == null || margin < 0 || margin > 120)) {
      setState(() => _error = 'Indica tu margen entre 0 y 120 segundos.');
      return;
    }
    final availability = <int, int>{};
    for (final day in _available) {
      final minutes = int.tryParse(_minutesByDay[day - 1].text.trim());
      if (minutes == null ||
          minutes < (widget.loadSharedAvailability == null ? 30 : 20) ||
          minutes > 240) {
        setState(
          () =>
              _error = 'Indica entre 30 y 240 minutos en cada día disponible.',
        );
        return;
      }
      availability[day] = minutes;
    }
    if (availability.isEmpty ||
        _pain == null ||
        _review == null ||
        _comfortableMinutes == null) {
      setState(
        () => _error = 'Elige al menos un día, tu carrera cómoda actual y responde las preguntas de salud.',
      );
      return;
    }
    final weeks = <RecentRunningWeek>[];
    for (var i = 0; i < 4; i++) {
      final days = _noRecentRunning
          ? 0
          : int.tryParse(_daysByWeek[i].text.trim());
      final minutes = _noRecentRunning
          ? 0
          : int.tryParse(_minutesByWeek[i].text.trim());
      if (days == null ||
          minutes == null ||
          days < 0 ||
          days > 7 ||
          minutes < 0 ||
          minutes > 1200 ||
          (days == 0) != (minutes == 0)) {
        setState(
          () => _error =
              'Completa las cuatro semanas: días 0–7 y minutos coherentes.',
        );
        return;
      }
      weeks.add(
        RecentRunningWeek(
          weekStart: _lastCompletedWeekStart.subtract(Duration(days: i * 7)),
          runningDays: days,
          runningMinutes: minutes,
        ),
      );
    }
    if (_qualityWeeksLastFour >
        weeks.where((week) => week.runningDays > 0).length) {
      setState(
        () => _error = 'Las semanas con series no pueden superar las semanas en las que corriste.',
      );
      return;
    }
    final now = DateTime.now();
    final draft = RunningInitialContext(
      goalId: widget.goalId,
      programId: _goal!.programId,
      collectedAt: now,
      availableMinutesByWeekday: availability,
      reservedStrengthWeekdays: _strength,
      recentRunningWeeks: weeks,
      health: RunningHealthCheck(
        observedAt: now,
        reportsPain: _pain!,
        requiresProfessionalReview: _review!,
      ),
      reference: null,
      comfortableContinuousMinutes: _comfortableMinutes,
      targetTwoKilometreSeconds: targetSeconds,
      officialMarginSeconds: margin,
      qualityWeeksLastFour: _qualityWeeksLastFour,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.saveContext(draft);
      _savedStamp = _stamp;
      if (mounted) {
        setState(() => _saving = false);
        context.pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Revisa los datos e inténtalo otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => !_loading && _savedStamp != _stamp,
    isBusy: () => _saving,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tu punto de partida')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _goal == null
        ? Center(child: Text(_error ?? 'Preparación no disponible.'))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.loadSharedAvailability != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Usamos los días y minutos de tu programa. El coordinador repartirá el tiempo entre carrera y los demás movimientos.',
                  ),
                ),
              if (widget.loadSharedAvailability == null) ...[
                Text(
                  'Disponibilidad',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Elige los días en los que podrías entrenar y cuánto tiempo tienes en cada uno. Esto es disponibilidad, no lo que corriste antes ni una orden de entrenar todos esos días.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        key: Key('available-day-$day'),
                        label: Text(_dayNames[day - 1]),
                        selected: _available.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _available.add(day);
                          } else {
                            _available.remove(day);
                            _strength.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '45 min recomendados: dan margen para una sesión completa. Elige el tiempo que tengas disponible.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes in [30, 45, 60, 75, 90])
                      ChoiceChip(
                        label: Text(
                          minutes == 45
                              ? '45 min · recomendado'
                              : '$minutes min',
                        ),
                        selected: _normalSessionMinutes == minutes,
                        onSelected: (_) => setState(() {
                          _normalSessionMinutes = minutes;
                          for (final controller in _minutesByDay) {
                            controller.text = '$minutes';
                          }
                        }),
                      ),
                  ],
                ),
                if (_available.isNotEmpty)
                  ExpansionTile(
                    title: const Text(
                      'Ajustar días concretos o reservar fuerza',
                    ),
                    children: [
                      for (final day in _available.toList()..sort())
                        _dayDetails(day),
                    ],
                  ),
                const SizedBox(height: 20),
              ],
              ...[
                DropdownButtonFormField<String>(
                  initialValue: _goalMode,
                  decoration: const InputDecoration(
                    labelText: 'Qué quieres conseguir',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'improve',
                      child: Text('Mejorar sin una marca concreta'),
                    ),
                    DropdownMenuItem(
                      value: 'time',
                      child: Text('Alcanzar una marca de 2 km'),
                    ),
                    DropdownMenuItem(
                      value: 'official_margin',
                      child: Text('Umbral del catálogo con margen'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _goalMode = value!),
                ),
                if (_goalMode == 'time')
                  TextField(
                    controller: _target,
                    decoration: const InputDecoration(
                      labelText: 'Meta de 2 km',
                      hintText: 'Por ejemplo, 7:45',
                      helperText: 'La meta no fija tus ritmos actuales.',
                    ),
                  ),
                if (_goalMode == 'official_margin') ...[
                  const Text(
                    'Usaremos el umbral del 2 km de tu evaluación elegida, con su categoría y edad. La propuesta mostrará la fuente y el tiempo resultante. El mínimo de una prueba no garantiza superar toda la evaluación.',
                  ),
                  TextField(
                    controller: _margin,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Segundos por debajo del umbral',
                      helperText: 'Elige un margen de 0 a 120 s. Verás el tiempo resultante antes de publicar.',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
              Text(
                'Carrera cómoda hoy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                '¿Cuánto tiempo crees que podrías correr seguido a un ritmo que te permita conversar? '
                'No es una prueba máxima ni se deduce de tu marca de 2 km.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in [0, 15, 30, 45, 60, 90])
                    ChoiceChip(
                      key: Key('comfortable-minutes-$minutes'),
                      label: Text(
                        minutes == 0
                            ? 'Aún no'
                            : minutes == 90
                            ? '90 min o más'
                            : '$minutes min',
                      ),
                      selected: _comfortableMinutes == minutes,
                      onSelected: (_) =>
                          setState(() => _comfortableMinutes = minutes),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Últimas cuatro semanas completas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'En cada semana indica los días en que corriste y los minutos TOTALES de carrera sumando todos esos días. Esto describe lo que hiciste, no el tiempo que estás dispuesto a entrenar ahora. El plan te recomendará una primera dosis para revisarla antes de añadirla a la agenda.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('No he corrido en estas cuatro semanas'),
                value: _noRecentRunning,
                onChanged: (value) => setState(() {
                  _noRecentRunning = value;
                  if (value) {
                    _qualityWeeksLastFour = 0;
                    for (var i = 0; i < 4; i++) {
                      _daysByWeek[i].text = '0';
                      _minutesByWeek[i].text = '0';
                    }
                  }
                }),
              ),
              if (_oldHistory)
                const Text(
                  'Tus semanas anteriores ya no son las últimas cuatro; actualízalas.',
                ),
              const SizedBox(height: 8),
              if (!_noRecentRunning)
                for (var i = 0; i < 4; i++) _weekRow(i),
              if (!_noRecentRunning) ...[
                const SizedBox(height: 12),
                const Text(
                  '¿En cuántas de esas semanas terminaste una sesión de series o cambios de ritmo sin molestias? Es un recuerdo aproximado, no una sesión registrada.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var weeks = 0; weeks <= 4; weeks++)
                      ChoiceChip(
                        key: Key('quality-weeks-$weeks'),
                        label: Text('$weeks'),
                        selected: _qualityWeeksLastFour == weeks,
                        onSelected: (_) =>
                            setState(() => _qualityWeeksLastFour = weeks),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Estado actual',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Estas respuestas se fechan al guardar.'),
              _choice(
                title: '¿Tienes dolor o molestias al entrenar?',
                value: _pain,
                onChanged: (value) => setState(() => _pain = value),
              ),
              _choice(
                title: '¿Hay una lesión o limitación que requiere revisión antes de entrenar?',
                value: _review,
                onChanged: (value) => setState(() => _review = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar datos'),
              ),
              const SizedBox(height: 20),
            ],
          ),
  );

  Widget _dayDetails(int day) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        SizedBox(width: 85, child: Text(_dayNames[day - 1])),
        Expanded(
          child: TextField(
            controller: _minutesByDay[day - 1],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutos disponibles'),
            onChanged: (_) => setState(() => _normalSessionMinutes = null),
          ),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Fuerza'),
          selected: _strength.contains(day),
          onSelected: (selected) => setState(() {
            if (selected) {
              _strength.add(day);
            } else {
              _strength.remove(day);
            }
          }),
        ),
      ],
    ),
  );

  Widget _weekRow(int index) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(
            index == 0 ? 'Semana pasada' : 'Hace ${index + 1} semanas',
          ),
        ),
        Expanded(
          child: TextField(
            key: Key('recent-days-$index'),
            controller: _daysByWeek[index],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Días'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: Key('recent-minutes-$index'),
            controller: _minutesByWeek[index],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutos totales'),
          ),
        ),
      ],
    ),
  );

  Widget _choice({
    required String title,
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('No'),
                selected: value == false,
                onSelected: (_) => onChanged(false),
              ),
              ChoiceChip(
                label: const Text('Sí'),
                selected: value == true,
                onSelected: (_) => onChanged(true),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
