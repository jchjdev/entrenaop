import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';

import '../widgets/program_phase_section.dart';

import 'dart:convert';

import 'package:entrenaop/features/training_plan/presentation/widgets/training_context_fields.dart';

import 'package:flutter/material.dart';
import 'package:entrenaop/core/config/app_config.dart';
import 'package:workout_core/performance_time.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/training_scope.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/performance_reference_dialog.dart';

class PreparationTrainingPage extends StatefulWidget {
  const PreparationTrainingPage({
    required this.goalId,
    required this.repository,
    this.initialWeek,
    this.runningStepBuilder,
    super.key,
  });
  final Widget Function(BuildContext, VoidCallback, VoidCallback)?
  runningStepBuilder;
  final String goalId;
  final PreparationTrainingRepository repository;
  final DateTime? initialWeek;
  @override
  State<PreparationTrainingPage> createState() =>
      _PreparationTrainingPageState();
}

class _PreparationTrainingPageState extends State<PreparationTrainingPage> {
  PreparationTrainingData? _data;
  final _availability = <String, int>{};
  final _equipment = <String>{};
  String? _savedContextStamp, _savedProgramStamp;
  String get _contextStamp => jsonEncode([
    (_availability.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => [e.key, e.value])
        .toList(),
    _equipment.toList()..sort(),
    _pain,
    _confirmed,
  ]);
  String get _programStamp => jsonEncode([
    _scope.value,
    _targetDate?.toIso8601String(),
    (_targets.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => [e.key, e.value])
        .toList(),
  ]);
  Map<String, dynamic>? _plan;
  bool _busy = false, _pain = false, _confirmed = false;
  int _step = 0;
  bool _editing = false;
  bool _reviewOnly = false;
  bool get _started => _data?.programState['auto_advance'] == true;
  bool get _paused => _data?.programState['status'] == 'paused';
  bool get _hasRunning => _data!.availableRunning && _scope.includesRunning;
  bool get _hasPerformance =>
      _data!.availablePerformance && _scope.includesPerformance;
  bool get _scopeChanged =>
      _started &&
      _scope != TrainingScope.parse(_data!.programState['training_scope']);
  TrainingScope _scope = TrainingScope.full;
  DateTime? _targetDate;
  final _targets = <String, dynamic>{};
  List<String> get _steps => [
    'Tu programa',
    'Disponibilidad',
    if (_data != null && _hasRunning) 'Carrera',
    if (_data != null && _hasPerformance) 'Movimientos',
    'Propuesta',
  ];
  int get _movementStep => _steps.indexOf('Movimientos');
  int get _lastInputStep => _hasPerformance
      ? _movementStep
      : _hasRunning
      ? _steps.indexOf('Carrera')
      : 1;
  int get _previewStep => _steps.length - 1;
  void _goStep(int step) => setState(() => _step = step);
  int _issueStep(Map<String, dynamic> issue) {
    final status = issue['status'] as String? ?? '';
    if (status == 'needs_target_date') return 0;
    // La falta de hueco para una dosis requiere revisar el tiempo común,
    // no volver a registrar una capacidad que ya está confirmada.
    if (const [
          'needs_context',
          'needs_running_frequency',
          'needs_running_time',
          'reduced_running_coverage',
        ].contains(status) ||
        (issue['reference_id'] != null && issue.containsKey('scheduled'))) {
      return 1;
    }
    if (status.contains('running') && _data!.hasRunning) {
      return _steps.indexOf('Carrera');
    }
    return _lastInputStep;
  }

  void _openIssue(Map<String, dynamic> issue) {
    if (issue['status'] == 'session_in_progress') {
      context.go('/plan/week');
      return;
    }
    setState(() {
      _editing = _started || _paused;
      _step = _issueStep(issue);
    });
  }

  String? _error;
  String? _notice;
  late DateTime _week;
  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final requested = widget.initialWeek;
    _week = requested == null
        ? today.add(Duration(days: n.weekday == 1 ? 0 : 8 - n.weekday))
        : DateUtils.dateOnly(requested)
              .subtract(Duration(days: requested.weekday - 1));
    _load();
  }

  Future<void> _load({bool initialize = true}) async {
    try {
      if (initialize) await widget.repository.advance(widget.goalId);
      final d = await widget.repository.load(widget.goalId);
      if (!mounted) return;
      setState(() {
        _data = d;
        if (initialize) {
          _scope = d.trainingScope;
          _targetDate = d.targetDate;
          _targets
            ..clear()
            ..addAll(
              Map<String, dynamic>.from(
                d.programState['objective_targets'] as Map? ?? {},
              ),
            );
          if (d.programState['auto_advance'] == true &&
              d.publishedWeeks.isNotEmpty &&
              (widget.initialWeek == null ||
                  d.programState['auto_advance'] == true)) {
            _week = d.publishedWeeks.first;
          }
          final availability =
              d.context?['availability'] as Map? ??
              d.runningContext?['available_minutes_by_weekday'] as Map? ??
              {};
          _availability
            ..clear()
            ..addAll(
              availability.map(
                (k, v) => MapEntry(k.toString(), (v as num).toInt()),
              ),
            );
          _equipment
            ..clear()
            ..addAll((d.context?['equipment'] as List? ?? []).cast<String>());
          _pain = d.context?['reports_pain'] as bool? ?? false;
          _confirmed = d.context?['capacity_confirmed'] as bool? ?? false;
          _savedContextStamp = _contextStamp;
          _savedProgramStamp = _programStamp;
        }
      });
      if (initialize &&
          d.programState['auto_advance'] == true &&
          d.publishedWeeks.contains(_week)) {
        // El panel muestra la pauta activa aunque haya otra selección guardada
        // como borrador. Cambiarla requiere revisar y aceptar su propuesta.
        final published = await widget.repository.calculate(
          widget.goalId,
          _week,
        );
        if (mounted) setState(() => _plan = published);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveContext() async => _run(() async {
    if (!_availability.values.any((v) => v > 0)) {
      throw StateError('Selecciona al menos un día disponible.');
    }
    await widget.repository.saveContext(
      _availability,
      _equipment,
      reportsPain: _pain,
      capacityConfirmed: _confirmed,
    );
    _savedContextStamp = _contextStamp;
    await _load(initialize: false);
    if (_reviewOnly) {
      await _finishReview();
      return;
    }
    if (mounted) {
      setState(() {
        _plan = null;
        _step = 2;
      });
    }
  });
  Future<void> _saveProgram() async {
    if (_targetDate == null) throw StateError('Indica la fecha de tu prueba.');
    for (final entry in _targets.entries) {
      final value = (entry.value as Map)['value'] as num?;
      final mode = (entry.value as Map)['measurement'];
      if (value == null ||
          !value.isFinite ||
          value <= 0 ||
          value > 100000 ||
          (const ['REPS', 'REPS_IN_TIME'].contains(mode) &&
              value != value.truncate())) {
        final name =
            _data!.objectives
                .where((o) => o['objective_key'] == entry.key)
                .firstOrNull?['name'] ??
            'este movimiento';
        throw StateError(
          'Revisa la marca objetivo de $name. También puedes dejarla vacía.',
        );
      }
    }
    await widget.repository.saveProgram(
      widget.goalId,
      _targetDate!,
      _targets,
      scope: _scope,
    );
    _savedProgramStamp = _programStamp;
  }

  Future<void> _reference({
    Map<String, dynamic>? objective,
    Map<String, dynamic>? existing,
    String? initialWorkCode,
    String? initialMeasurement,
  }) async {
    final input = await showDialog<PerformanceReferenceInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PerformanceReferenceDialog(
        data: _data!,
        objective: objective,
        existing: existing,
        initialWorkCode: initialWorkCode,
        initialMeasurement: initialMeasurement,
        onSave: (input) => widget.repository.saveReference(
          widget.goalId,
          input.reference,
          testId: input.testId,
        ),
      ),
    );
    if (input == null || !mounted) return;
    await _run(() async {
      _equipment.addAll(input.equipment);
      _savedContextStamp = _contextStamp;
      await _load(initialize: false);
      if (_reviewOnly) {
        await _finishReview();
        return;
      }
      if (mounted) {
        setState(() {
          if (!_started) _plan = null;
          if (_started) _notice = 'Referencia guardada. Se usará en la siguiente adaptación; los entrenamientos guardados se conservan.';
        });
      }
    });
  }

  Future<void> _calculate({bool revise = false}) async => _run(() async {
    final p = await widget.repository.calculate(
      widget.goalId,
      _week,
      revise: revise,
      activation: !revise && (!_started || _scopeChanged),
    );
    if (mounted) {
      setState(() {
        _plan = p;
        _step = _previewStep;
      });
    }
  });
  Future<void> _publish() async => _run(() async {
    final p = _plan!['revision'] != null
        ? await widget.repository.publish(widget.goalId, _week, _plan!)
        : await widget.repository.activate(widget.goalId, _week, _plan!);
    await _load(initialize: false);
    if (mounted) {
      setState(() {
        _plan = p;
        _editing = false;
        _notice = p['revision'] != null
            ? 'Las sesiones pendientes ya usan tus datos actuales. El programa continúa automáticamente.'
            : null;
      });
    }
  });

  Future<void> _reviewPending() async => _run(() async {
    final week = DateTime.parse(_data!.updateOptions['week_start'] as String);
    final proposal = await widget.repository.calculate(
      widget.goalId,
      week,
      revise: true,
    );
    if (!mounted) return;
    setState(() {
      _week = week;
      _plan = proposal;
      _editing = true;
      _reviewOnly = false;
      _step = _previewStep;
      _notice = null;
    });
  });

  static String _scopeLabel(TrainingScope scope) => switch (scope) {
    TrainingScope.full => 'Preparación completa',
    TrainingScope.running => 'Solo carrera',
    TrainingScope.performance => 'Fuerza y otras pruebas',
  };

  void _beginResume({bool review = false}) {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _editing = true;
      _reviewOnly = false;
      _plan = null;
      _notice = 'Conservamos tu progreso. Revisa tu situación actual; los próximos entrenamientos se adaptarán al calendario de ahora.';
      _week = today.add(
        Duration(days: today.weekday == 1 ? 0 : 8 - today.weekday),
      );
      _step = review ? 1 : 0;
    });
  }

  Future<void> _pause() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pausar mi programa'),
        content: const Text(
          'Conservaremos tu progreso, marcas y resultados. Retiraremos de la agenda las sesiones automáticas que no has empezado. Podrás retomar el programa cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pausar programa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.repository.pause(widget.goalId);
      _plan = null;
      await _load();
    });
  }

  Future<void> _resetTrial() async {
    final confirmation = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TrialResetDialog(),
    );
    if (confirmation == null || !mounted) return;
    await _run(() async {
      await widget.repository.resetTrial(widget.goalId, confirmation);
      if (!mounted) return;
      final today = DateUtils.dateOnly(DateTime.now());
      setState(() {
        _data = null;
        _week = today.add(
          Duration(days: today.weekday == 1 ? 0 : 8 - today.weekday),
        );
        _plan = null;
        _editing = false;
        _reviewOnly = false;
        _step = _previewStep;
        _notice = 'Ensayos reiniciados. Revisa tus primeros entrenamientos con los datos actuales.';
      });
      await _load();
      if (_data == null || _error != null) return;
      final proposal = await widget.repository.calculate(
        widget.goalId,
        _week,
        activation: true,
      );
      if (mounted) {
        setState(() {
          _plan = proposal;
          _step = _previewStep;
        });
      }
    });
  }

  String _name(String code) =>
      _data!.catalog.where((p) => p.code == code).firstOrNull?.name ??
      'Movimiento';
  static String _message(Object e) =>
      e is StateError ? e.message.toString() : e.toString();
  static List<Map<String, dynamic>> _rows(Object? v) => (v as List? ?? [])
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  Future<void> _finishReview() async {
    await _load();
    if (mounted) {
      setState(() {
        _reviewOnly = false;
        _editing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () =>
        _data != null &&
        (_savedContextStamp != _contextStamp ||
            _savedProgramStamp != _programStamp),
    isBusy: () => _busy,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mi programa'),
          if (_data?.programName != null)
            Text(
              _data!.programName!,
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    ),
    body: _data == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(_error!),
          )
        : (_started ||
                  _paused ||
                  _data!.programState['status'] == 'complete') &&
              !_editing
        ? _dashboard()
        : Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: i <= _step ? 1 : 0,
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Paso ${_step + 1} de ${_steps.length} · ${_steps[_step]}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child:
                    _step == _steps.indexOf('Carrera') &&
                        widget.runningStepBuilder != null
                    ? widget.runningStepBuilder!(context, () async {
                        if (_reviewOnly) {
                          await _finishReview();
                          return;
                        }
                        await _load(initialize: false);
                        _plan = null;
                        if (mounted) {
                          _goStep(
                            _hasPerformance ? _movementStep : _previewStep,
                          );
                        }
                      }, () => _goStep(1))
                    : SingleChildScrollView(
                        key: ValueKey('program-step-$_step'),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_notice != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(_notice!),
                                  ),
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                if (_step == 0)
                                  _program()
                                else if (_step == 1)
                                  _context()
                                else if (_step == _movementStep)
                                  _movements()
                                else if (_step == _previewStep)
                                  _plan == null ? _summary() : _preview()
                                else
                                  _runningFallback(),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
  );
  Widget _program() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Preparar mi programa',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Primero definimos tu objetivo y tu punto de partida. Después adaptaremos las sesiones con lo que realmente vayas haciendo.',
      ),
      const SizedBox(height: 20),
      if (_data!.availableRunning && _data!.availablePerformance) ...[
        Text(
          '¿Qué quieres que prepare EntrenaOP?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final scope in TrainingScope.values)
          Card(
            child: ListTile(
              title: Text(_scopeLabel(scope)),
              subtitle: Text(switch (scope) {
                TrainingScope.full =>
                  'Carrera y las demás pruebas de tu preparación.',
                TrainingScope.running =>
                  'La app pautará carrera. Las demás pruebas quedan fuera.',
                TrainingScope.performance =>
                  'La app pautará fuerza y otras pruebas. Carrera queda fuera.',
              }),
              leading: Icon(
                _scope == scope
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              selected: _scope == scope,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _scope = scope;
                      _plan = null;
                    }),
            ),
          ),
        const SizedBox(height: 16),
      ],
      OutlinedButton.icon(
        icon: const Icon(Icons.event),
        label: Text(
          _targetDate == null
              ? 'Elegir fecha de la prueba'
              : 'Prueba: ${DateFormat('dd/MM/yyyy').format(_targetDate!)}',
        ),
        onPressed: _busy
            ? null
            : () async {
                final now = DateUtils.dateOnly(DateTime.now());
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      _targetDate != null &&
                          !_targetDate!.isBefore(now) &&
                          !_targetDate!.isAfter(
                            DateTime(now.year + 10, now.month, now.day),
                          )
                      ? _targetDate
                      : now.add(const Duration(days: 90)),
                  firstDate: now,
                  lastDate: DateTime(now.year + 10, now.month, now.day),
                );
                if (date != null && mounted) setState(() => _targetDate = date);
              },
      ),
      const SizedBox(height: 16),
      Text(
        _hasPerformance
            ? 'Las marcas que quieres conseguir se pueden indicar por movimiento. La meta orienta el programa; nunca sustituye a tu capacidad medida ni obliga a entrenar por encima de ella.'
            : 'En carrera revisaremos tu marca actual y el objetivo que quieres alcanzar. La meta orienta la preparación; las sesiones parten de tu capacidad actual.',
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy
            ? null
            : () => _run(() async {
                if (_targetDate == null) {
                  throw StateError('Indica cuándo tienes la prueba.');
                }
                await _saveProgram();
                await _load(initialize: false);
                if (mounted) _goStep(1);
              }),
        child: const Text('Continuar con mi disponibilidad'),
      ),
    ],
  );

  Widget _runningFallback() => Column(
    children: [
      const Text(
        'Carrera: revisa tu marca, tu objetivo y el entrenamiento reciente.',
      ),
      FilledButton(
        onPressed: () async {
          await context.push(
            '/plan/goal/${widget.goalId}/running-intake?dataOnly=true',
          );
          await _load(initialize: false);
          if (mounted) {
            _goStep(_hasPerformance ? _movementStep : _previewStep);
          }
        },
        child: const Text('Revisar datos de carrera'),
      ),
    ],
  );

  Widget _summary() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _paused
            ? 'Retomar mi programa con mis datos actuales'
            : _started
            ? 'Guardar los cambios de mi programa'
            : 'Tu programa, listo para revisar',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      if (_targetDate != null)
        Text('Prueba: ${DateFormat('dd/MM/yyyy').format(_targetDate!)}'),
      Text(
        '${_availability.values.where((m) => m > 0).length} días disponibles · ${_scopeLabel(_scope)}',
      ),
      const SizedBox(height: 16),
      Text(
        _paused || _scopeChanged
            ? 'Revisaremos una propuesta con tus datos actuales y el calendario de ahora. Conservaremos lo que ya has realizado y sustituiremos las sesiones automáticas sin empezar cuando la aceptes.'
            : _started
            ? _data!.updateOptions['can_replace_pending'] == true
                  ? 'Revisaremos una propuesta con tus datos actuales para esta semana aún no empezada. Solo sustituiremos las sesiones pendientes cuando la aceptes.'
                  : 'Los nuevos datos se usarán en la siguiente adaptación. Las sesiones iniciadas o realizadas se conservan; no hay que reiniciar un programa real para cambiar sus datos.'
            : 'Revisa tus primeros entrenamientos y empieza el programa. Después, EntrenaOP preparará las siguientes semanas con los resultados de tus sesiones.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Si faltan datos o hay una dificultad que impide continuar, verás qué revisar. No tendrás que hacer un test cada semana.',
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                if (_targetDate == null) {
                  throw StateError('Indica la fecha de tu prueba.');
                }
                await _saveProgram();
                if (_started && !_scopeChanged) {
                  await _load(initialize: false);
                  if (_data!.updateOptions['can_replace_pending'] == true) {
                    final week = DateTime.parse(
                      _data!.updateOptions['week_start'] as String,
                    );
                    final proposal = await widget.repository.calculate(
                      widget.goalId,
                      week,
                      revise: true,
                    );
                    if (mounted) {
                      setState(() {
                        _week = week;
                        _plan = proposal;
                        _step = _previewStep;
                        _notice = null;
                      });
                    }
                    return;
                  }
                  final previousWeek = _data!.publishedWeeks.firstOrNull;
                  await widget.repository.advance(widget.goalId);
                  await _load();
                  if (mounted) {
                    setState(() {
                      _editing = false;
                      _notice =
                          _data!.publishedWeeks.firstOrNull != previousWeek
                          ? 'Los datos guardados ya se han usado para preparar tus siguientes entrenamientos.'
                          : 'Datos guardados. Se aplicarán en la siguiente adaptación automática. ${_data!.updateOptions['reason'] ?? ''}';
                    });
                  }
                  return;
                }
                if (_scopeChanged) {
                  final today = DateUtils.dateOnly(DateTime.now());
                  _week = today.add(
                    Duration(days: today.weekday == 1 ? 0 : 8 - today.weekday),
                  );
                }
                final proposal = await widget.repository.calculate(
                  widget.goalId,
                  _week,
                  activation: true,
                );
                if (mounted) setState(() => _plan = proposal);
              }),
        icon: const Icon(Icons.auto_awesome_outlined),
        label: Text(
          _paused
              ? 'Revisar mis próximos entrenamientos'
              : _started
              ? 'Guardar cambios'
              : 'Ver mis primeros entrenamientos',
        ),
      ),
      TextButton(
        onPressed: _busy ? null : () => _goStep(_lastInputStep),
        child: const Text('Atrás'),
      ),
    ],
  );

  Widget _movementCard(
    Map<String, dynamic>? objective,
    Map<String, dynamic>? row,
  ) {
    final ref = Map<String, dynamic>.from(row?['reference'] as Map? ?? {});
    final code =
        (ref['task'] as Map?)?['exercise_code'] as String? ??
        objective?['profile_code'] as String? ??
        '';
    final key = objective?['objective_key'] as String?;
    final measurement = objective?['measurement'] as String? ?? '';
    final timed = const [
      'DURATION',
      'TIME_FOR_DISTANCE',
      'TIME_FOR_COURSE',
    ].contains(measurement);
    final targetValue = (_targets[key] as Map?)?['value'] as num?;
    final count = (ref['targets'] as List? ?? []).length;
    final ambiguous =
        row != null &&
        (ref['reference_kind'] == null ||
            ref['reference_kind'] == 'legacy_work');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              objective?['name'] as String? ?? _name(code),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (row != null) Text(_name(code)),
            Text(
              row == null
                  ? 'Falta tu punto de partida'
                  : ambiguous
                  ? 'Revisa qué representa esta referencia antigua'
                  : 'Referencia: ${ref['observed_on']} · $count ${count == 1 ? 'serie' : 'series'}',
            ),
            if (key != null && measurement != 'PASS_FAIL') ...[
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('target-$key'),
                initialValue: targetValue == null
                    ? ''
                    : timed
                    ? formatPerformanceTime(targetValue)
                    : targetValue.toString(),
                keyboardType: timed
                    ? TextInputType.datetime
                    : const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Marca que quieres conseguir (opcional)',
                  suffixText: timed ? 'min:s' : _unit(measurement),
                  hintText: timed ? 'Por ejemplo, 1:30' : null,
                  helperText: 'Deja vacío para mejorar sin fijar una marca.',
                ),
                onChanged: (text) {
                  _plan = null;
                  final value = timed
                      ? parsePerformanceTime(text)
                      : num.tryParse(text.trim().replaceAll(',', '.'));
                  if (text.trim().isEmpty) {
                    _targets.remove(key);
                  } else {
                    _targets[key] = {
                      'measurement': measurement,
                      'value': value,
                    };
                  }
                },
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _reference(objective: objective, existing: row),
              icon: Icon(row == null ? Icons.add : Icons.edit_outlined),
              label: Text(
                row == null
                    ? 'Registrar mi referencia'
                    : 'Revisar mi referencia',
              ),
            ),
            if (row != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await widget.repository.deactivateReference(
                          row['id'] as String,
                        );
                        await _load(initialize: false);
                        if (mounted) setState(() => _plan = null);
                      }),
                child: const Text('Dejar de utilizar esta referencia'),
              ),
            if (objective != null)
              for (final alternative in _data!.references.where(
                (r) => r['objective_key'] == key && r['id'] != row?['id'],
              ))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(),
                    Text(
                      _name(
                        ((alternative['reference'] as Map)['task']
                                as Map)['exercise_code']
                            as String,
                      ),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _reference(
                                  objective: objective,
                                  existing: alternative,
                                ),
                          child: const Text('Revisar esta variante'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await widget.repository.deactivateReference(
                                    alternative['id'] as String,
                                  );
                                  await _load(initialize: false);
                                  if (mounted) setState(() => _plan = null);
                                }),
                          child: const Text('Dejar de utilizar esta variante'),
                        ),
                      ],
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _context() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Tiempo para la sesión completa',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      TrainingContextFields(
        availability: _availability,
        equipment: _equipment,
        equipmentOptions: {
          for (final exercise in _data!.catalog) ...exercise.requiredEquipment,
          for (final exercise in _data!.catalog) ...exercise.optionalEquipment,
        },
        reportsPain: _pain,
        confirmed: _confirmed,
        enabled: !_busy,
        onAvailability: (day, minutes) =>
            setState(() => _availability[day] = minutes),
        onEquipment: (code, selected) => setState(() {
          selected ? _equipment.add(code) : _equipment.remove(code);
        }),
        onPain: (value) => setState(() => _pain = value),
        onConfirmed: (value) => setState(() => _confirmed = value),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busy ? null : _saveContext,
        child: Text(
          _hasRunning
              ? 'Continuar con carrera'
              : _hasPerformance
              ? 'Continuar con los movimientos'
              : 'Continuar con el programa',
        ),
      ),
    ],
  );
  Widget _movements() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Lo que necesitas preparar',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Cada movimiento conserva su propia referencia. La app selecciona trabajo específico y apoyos compatibles con tu material; dos personas pueden necesitar dosis y variantes distintas.',
      ),
      const SizedBox(height: 16),
      for (final objective in _data!.objectives)
        _movementCard(
          objective,
          _data!.references
              .where((r) => r['objective_key'] == objective['objective_key'])
              .firstOrNull,
        ),
      for (final row in _data!.references.where(
        (r) => !_data!.objectives.any(
          (o) => o['objective_key'] == r['objective_key'],
        ),
      ))
        _movementCard(null, row),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _reference(),
        icon: const Icon(Icons.add),
        label: const Text('Añadir objetivo de mejora'),
      ),
      const SizedBox(height: 12),
      const SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _goStep(_movementStep - 1),
            child: const Text('Atrás'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _goStep(_previewStep),
            child: const Text('Revisar mi programa'),
          ),
        ],
      ),
    ],
  );
  Widget _dashboard() {
    final state = _data!.programState;
    final activeScope = TrainingScope.parse(
      state['training_scope'] ?? _data!.trainingScope.value,
    );
    final needsReview = state['status'] == 'needs_review';
    final complete = state['status'] == 'complete';
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_notice!),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Text(
                    complete
                        ? 'Preparación finalizada'
                        : _paused
                        ? 'Tu programa está pausado'
                        : 'Tu programa está en marcha',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_targetDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Prueba · ${DateFormat('dd/MM/yyyy').format(_targetDate!)}',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _scopeLabel(TrainingScope.parse(state['training_scope'])),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (activeScope.includesPerformance && !_paused)
                    ProgramPhaseSection(path: _data!.programPath),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            needsReview
                                ? Icons.info_outline
                                : Icons.event_available_outlined,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state['message'] as String? ?? 'Entrena y registra tus resultados. EntrenaOP prepara la continuación.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : _paused
                        ? () => _beginResume()
                        : () => context.go(
                            '/plan/week?date=${DateFormat('yyyy-MM-dd').format(_week)}',
                          ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _paused
                          ? 'Retomar mi programa'
                          : 'Ver mis entrenamientos',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _paused
                        ? 'Al retomar, revisaremos los datos que sigan siendo válidos y adaptaremos los próximos entrenamientos a tu situación actual.'
                        : 'Al terminar las sesiones previstas, adaptamos lo siguiente con lo que has realizado, tu esfuerzo y las incidencias registradas. No tienes que calcular otra semana.',
                  ),
                  if (_plan != null && !_paused)
                    ExpansionTile(
                      title: Text(
                        _data!.pendingSessions.isEmpty
                            ? 'Entrenamientos y motivos de la pauta'
                            : 'Sesiones pendientes de registrar',
                      ),
                      initiallyExpanded: _data!.pendingSessions.isNotEmpty,
                      children: [_preview(showActions: false)],
                    ),
                  if (activeScope.includesPerformance &&
                      !_paused &&
                      _data!.calibrationOptions.isNotEmpty)
                    ExpansionTile(
                      leading: const Icon(Icons.add_task),
                      title: const Text('Preparar opciones de apoyo'),
                      subtitle: const Text(
                        'Opcional · el motor elige cuándo utilizarlas',
                      ),
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Estos ejercicios pueden complementar tu objetivo. Primero necesitamos una práctica real de cada variante; no deducimos su carga o sus repeticiones de otra prueba.',
                          ),
                        ),
                        for (final option in _data!.calibrationOptions)
                          ListTile(
                            title: Text(
                              option['name'] as String? ?? 'Ejercicio de apoyo',
                            ),
                            subtitle: Text(option['reason'] as String? ?? ''),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _busy
                                ? null
                                : () {
                                    final objective = _data!.objectives
                                        .where(
                                          (o) =>
                                              o['objective_key'] ==
                                              option['objective_key'],
                                        )
                                        .firstOrNull;
                                    _reference(
                                      objective:
                                          objective ??
                                          {
                                            'profile_code': option['goal_code'],
                                            'profile_version':
                                                option['goal_version'],
                                            'measurement':
                                                option['measurement'],
                                            'test_id': option['test_id'],
                                            'objective_key':
                                                option['objective_key'],
                                            'name': option['name'],
                                            'program_objective_key':
                                                option['program_objective_key'],
                                            'protocol_key':
                                                'working_${option['goal_code']}_v1',
                                            'protocol_version': 1,
                                          },
                                      initialMeasurement:
                                          option['preferred_measurement']
                                              as String?,
                                      initialWorkCode:
                                          option['work_code'] as String,
                                    );
                                  },
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : _paused
                        ? () => _beginResume(review: true)
                        : () => setState(() {
                            _editing = true;
                            _reviewOnly = needsReview;
                            final pending = _rows(state['review_items'])
                                .firstOrNull;
                            final status = pending?['status'] as String? ?? '';
                            _step = !needsReview
                                ? 0
                                : status.contains('running') &&
                                      _data!.hasRunning
                                ? _steps.indexOf('Carrera')
                                : status.contains('calibration') ||
                                      status.contains('reference')
                                ? _movementStep
                                : 1;
                          }),
                    icon: const Icon(Icons.tune),
                    label: Text(
                      needsReview
                          ? 'Revisar el dato pendiente'
                          : _paused
                          ? 'Revisar mi punto de partida'
                          : 'Cambiar datos de mi programa',
                    ),
                  ),
                  if (_started)
                    TextButton.icon(
                      onPressed: _busy ? null : _pause,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Pausar mi programa'),
                    ),
                  if (!_paused &&
                      _data!.updateOptions['can_replace_pending'] == true)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _reviewPending,
                      icon: const Icon(Icons.event_repeat),
                      label: const Text(
                        'Aplicar datos actuales a sesiones pendientes',
                      ),
                    ),
                  if (AppConfig.environment == AppEnvironment.development &&
                      _data!.canResetTrial) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Herramienta de desarrollo · Solo para ensayos',
                      style: TextStyle(fontSize: 12),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _resetTrial,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reiniciar ensayos de este programa'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview({bool showActions = true}) {
    final p = _plan!;
    final running = p['running'] is Map
        ? Map<String, dynamic>.from(p['running'] as Map)
        : null;
    final sessions =
        [
          ..._rows(p['sessions']),
          ..._rows(running?['sessions']).map((s) => {...s, 'kind': 'running'}),
        ]..sort((a, b) {
          final date = (a['date'] as String).compareTo(b['date'] as String);
          if (date != 0 || a['kind'] == b['kind']) return date;
          final strength = a['kind'] == 'running' ? b : a;
          final strengthFirst =
              strength['session_order'] == 'performance_first';
          return (a['kind'] != 'running') == strengthFirst ? -1 : 1;
        });
    final published = p['decision_id'] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Semana del ${DateFormat('dd/MM').format(_week)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(p['reason'] as String? ?? 'Revisa los datos pendientes.'),
        if (!published && p['status'] != 'ready') ...[
          const SizedBox(height: 16),
          const Text(
            'Antes de activar tu programa',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Pulsa cada aviso para revisar el dato indicado. Al terminar, vuelve a revisar la propuesta; el botón de activar se habilitará cuando podamos pautar tu preparación completa.',
          ),
        ],
        if (p['status'] == 'needs_context')
          FilledButton.tonal(
            onPressed: _busy ? null : () => _goStep(1),
            child: const Text('Revisar disponibilidad y situación'),
          ),
        if (published && _data!.pendingSessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Sesiones hasta hoy pendientes de resolver',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Puedes realizarlas desde la agenda. Si no las hiciste, indícalo para que el programa use tu situación real.',
          ),
          for (final session in _data!.pendingSessions)
            Card(
              child: ListTile(
                title: Text(session['name'] as String),
                subtitle: Text(
                  DateFormat('dd/MM')
                      .format(DateTime.parse(session['date'] as String)),
                ),
                trailing: session['status'] == 'planned'
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialog) => AlertDialog(
                                    title: const Text(
                                      '¿No realizaste esta sesión?',
                                    ),
                                    content: const Text(
                                      'Quedará registrada como no realizada. No se contará como entrenamiento completado.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, false),
                                        child: const Text('Volver'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, true),
                                        child: const Text('No la realicé'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && mounted) {
                                  await _run(() async {
                                    await widget.repository.skipSession(
                                      session['id'] as String,
                                    );
                                    await _load();
                                  });
                                }
                              },
                        child: const Text('No la realicé'),
                      )
                    : const Text('En curso'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        for (final item in _rows(p['pending']))
          Card(
            child: ListTile(
              onTap: _busy ? null : () => _openIssue(item),
              trailing: const Icon(Icons.chevron_right),
              leading: const Icon(Icons.info_outline),
              title: Text(item['name'] as String? ?? 'Dato pendiente'),
              subtitle: Text(
                item['reason'] as String? ?? 'Revisa esta referencia.',
              ),
            ),
          ),
        for (final day in sessions.map((s) => s['date'] as String).toSet()) ...[
          const SizedBox(height: 16),
          Text(
            '${const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][DateTime.parse(day).weekday - 1]} ${DateFormat('dd/MM').format(DateTime.parse(day))} · ${sessions.where((s) => s['date'] == day).fold<int>(0, (n, s) => n + (s['minutes'] as num).toInt())} min en total',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final s in sessions.where((s) => s['date'] == day))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s['kind'] == 'running'
                          ? 'Carrera · ${s['name']}'
                          : 'Fuerza y rendimiento',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${s['minutes']} minutos${s['kind'] == 'running' ? '' : ' · incluye calentamiento, descansos y vuelta a la calma'}',
                    ),
                    if (s['kind'] == 'running')
                      Text(s['description'] as String? ?? '')
                    else if (s['warm_up_instructions']
                        case final String instructions)
                      ExpansionTile(
                        title: Text(
                          'Preparación · ${formatPerformanceTime(s['warm_up_seconds'] as num? ?? 420)} min${s['combined'] == true ? ' + activación compartida con carrera' : ''}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(instructions),
                          ),
                        ],
                      ),
                    if (s['kind'] != 'running')
                      for (final work in _rows(s['work'])) ...[
                        const Divider(),
                        Text(
                          work['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (work['stimulus'] is Map)
                          Text((work['stimulus'] as Map)['name'] as String),
                        ExpansionTile(
                          title: const Text('Por qué este trabajo'),
                          children: [Text(work['reason'] as String)],
                        ),
                        if (work['role'] == 'regression' ||
                            work['role'] == 'support')
                          const Text(
                            'Trabajo de apoyo: no acredita una marca ni sustituye la práctica de la prueba completa.',
                          ),
                        if (work['review_due'] == true)
                          Text(
                            work['review_reason'] as String? ?? 'Revisa tu respuesta al entrenamiento y tu situación actual.',
                          ),
                        for (final (i, v)
                            in ((work['dose'] as Map)['targets'] as List)
                                .indexed)
                          Text(
                            'Serie ${i + 1}: ${_targetLabel(v as num, (work['dose'] as Map)['task']['measurement'] as String)}',
                          ),
                        Text(
                          'Descanso entre series: ${formatPerformanceTime((work['dose'] as Map)['rest_seconds'] as num)} min',
                        ),
                        if ((work['dose'] as Map)['task']['target_rir']
                            case final num rir)
                          Text(
                            'Conserva al menos ${rir.toInt()} repeticiones de margen.',
                          ),
                        if ((work['dose'] as Map)['task']['target_rpe']
                            case final num rpe)
                          Text(
                            'Esfuerzo hasta ${rpe.toInt()}/10; detente si pierdes la postura.',
                          ),
                        if ((work['dose'] as Map)['task']['external_load_kg'] !=
                            null)
                          Text(
                            'Carga externa: ${(work['dose'] as Map)['task']['external_load_kg']} kg',
                          ),
                      ],
                  ],
                ),
              ),
            ),
        ],
        if (showActions) ...[
          const SizedBox(height: 20),
          if (!published &&
              p['activation'] != null &&
              _rows((p['activation'] as Map)['pauses']).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Al activar este programa se pausará: ${_rows((p['activation'] as Map)['pauses']).map((program) => program['name']).join(', ')}. Conservaremos su progreso y retiraremos sus sesiones pendientes sin empezar.',
                ),
              ),
            ),
          if (published)
            FilledButton(
              onPressed: () => context.go(
                '/plan/week?date=${DateFormat('yyyy-MM-dd').format(_week)}',
              ),
              child: const Text('Semana guardada · ver en mi agenda'),
            )
          else
            FilledButton(
              onPressed: _busy || p['status'] != 'ready' ? null : _publish,
              child: Text(
                p['revision'] != null
                    ? 'Sustituir las sesiones pendientes'
                    : _paused
                    ? 'Retomar mi programa'
                    : _scopeChanged
                    ? 'Aplicar selección de entrenamiento'
                    : 'Activar mi programa',
              ),
            ),
          if (p['revision'] != null && !published)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await _load();
                      if (mounted) {
                        setState(() {
                          _editing = false;
                          _notice = 'Los datos están guardados. Has conservado las sesiones anteriores; se usarán en la siguiente adaptación.';
                        });
                      }
                    }),
              child: const Text('Conservar las sesiones anteriores'),
            ),
          if (published) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _data!.programState['message'] as String? ??
                      'Tu programa continúa con los resultados que registres.',
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _goStep(0),
              icon: const Icon(Icons.tune),
              label: const Text('Revisar objetivos y disponibilidad'),
            ),
          ],
          if (_data!.publishedWeeks.contains(_week) &&
              (published || p['revision'] == null)) ...[
            const SizedBox(height: 12),
            const Text(
              'Si aún no has empezado esta semana, puedes revisar una nueva propuesta con tus datos actuales. Solo se sustituirá cuando la guardes; las semanas realizadas se conservan.',
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _calculate(revise: true),
              child: const Text('Recalcular con mis datos actuales'),
            ),
          ],
          TextButton(
            onPressed: _busy ? null : () => _goStep(_lastInputStep),
            child: Text(
              _hasPerformance ? 'Volver a los movimientos' : 'Volver a carrera',
            ),
          ),
        ],
      ],
    );
  }

  String _targetLabel(num value, String mode) => switch (mode) {
    'DURATION' ||
    'TIME_FOR_DISTANCE' ||
    'TIME_FOR_COURSE' => '${formatPerformanceTime(value)} min',
    'PASS_FAIL' => 'un intento técnico',
    _ => '${value == value.truncate() ? value.toInt() : value} ${_unit(mode)}',
  };

  String _unit(String mode) => switch (mode) {
    'REPS' || 'LOAD_REPS' || 'REPS_IN_TIME' => 'repeticiones',
    'DISTANCE' || 'HEIGHT' => 'm',
    'PASS_FAIL' => 'intento técnico',
    _ => 's',
  };
}

class _TrialResetDialog extends StatefulWidget {
  const _TrialResetDialog();
  @override
  State<_TrialResetDialog> createState() => _TrialResetDialogState();
}

class _TrialResetDialogState extends State<_TrialResetDialog> {
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reiniciar los ensayos de este programa'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrarán las semanas automáticas de carrera y fuerza de esta preparación y sus resultados de entrenamiento, incluidos los ensayos ya completados. Esta acción no se puede deshacer.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Se conservan la fecha, los objetivos, la disponibilidad, las referencias actuales y las marcas de las pruebas. Verás una primera propuesta con esos datos antes de activar de nuevo el programa.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Escribe REINICIAR'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _input,
        builder: (_, value, _) => FilledButton(
          onPressed: value.text == 'REINICIAR'
              ? () => Navigator.pop(context, value.text)
              : null,
          child: const Text('Borrar ensayos y reiniciar'),
        ),
      ),
    ],
  );
}
