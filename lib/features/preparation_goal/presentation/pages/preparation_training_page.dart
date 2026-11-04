import 'package:entrena_ui/entrena_ui.dart'
    show EntrenaDialog, EntrenaDialogActions, EntrenaButtonStyles;
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/core/presentation/dismiss_keyboard.dart';

import '../widgets/program_phase_section.dart';
import '../widgets/preparation_goal_review_panel.dart';
import '../preparation_context_navigation.dart';

import 'dart:convert';
import 'dart:async';

import '../../../../core/presentation/app_dates.dart';
import '../../domain/repositories/preparation_setup_progress_store.dart';

import 'package:entrenaop/features/training_plan/presentation/widgets/training_context_fields.dart';

import 'package:workout_editor_ui/duration_input_formatter.dart';
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
    this.editOnOpen = false,
    this.progressStore,
    super.key,
  });
  final Widget Function(BuildContext, VoidCallback, VoidCallback)?
  runningStepBuilder;
  final String goalId;
  final PreparationTrainingRepository repository;
  final DateTime? initialWeek;
  final bool editOnOpen;
  final PreparationSetupProgressStore? progressStore;
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
  int _loadVersion = 0;
  DialogRoute<PerformanceReferenceInput>? _referenceRoute;
  int _step = 0;
  final _targetFormKey = GlobalKey<FormState>();
  final _targetAnchors = <String, GlobalKey>{};
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
    'Tu preparación',
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
  void _goStep(int step) {
    dismissKeyboard();
    setState(() {
      _step = step;
      _error = null;
    });
    unawaited(_rememberStep());
  }

  PreparationSetupStep get _stepId => switch (_steps[_step]) {
    'Disponibilidad' => PreparationSetupStep.availability,
    'Carrera' => PreparationSetupStep.running,
    'Movimientos' => PreparationSetupStep.movements,
    'Propuesta' => PreparationSetupStep.proposal,
    _ => PreparationSetupStep.program,
  };

  int _indexFor(PreparationSetupStep step) => switch (step) {
    PreparationSetupStep.program => 0,
    PreparationSetupStep.availability => 1,
    PreparationSetupStep.running => _hasRunning ? _steps.indexOf('Carrera') : 1,
    PreparationSetupStep.movements => _hasPerformance ? _movementStep : 1,
    PreparationSetupStep.proposal => _previewStep,
  };

  int _resumeIndex(PreparationSetupStep step) {
    final index = _indexFor(step);
    if (_targetDate == null) return 0;
    if (index > 1 &&
        (!_confirmed || !_availability.values.any((minutes) => minutes > 0))) {
      return 1;
    }
    return index;
  }

  Future<void> _rememberStep() async {
    if (!mounted ||
        _data == null ||
        _started ||
        _paused ||
        _data!.programState['status'] == 'complete') {
      return;
    }
    try {
      await widget.progressStore?.write(widget.goalId, _stepId);
    } catch (_) {
      // La posición de la pantalla no condiciona el guardado de datos reales.
    }
  }

  void _back() {
    if (_busy) return;
    final configuring =
        _data != null &&
        (_editing ||
            (!_started &&
                !_paused &&
                _data!.programState['status'] != 'complete'));
    if (configuring && _step > 0) {
      _goStep(_step - 1);
    } else {
      context.pop();
    }
  }

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

  Future<void> _openIssue(Map<String, dynamic> issue) async {
    if (issue['status'] == 'session_in_progress') {
      await _openBlockingSession();
      return;
    }
    setState(() {
      _editing = _started || _paused;
      _step = _issueStep(issue);
    });
  }

  Future<void> _openBlockingSession() async {
    String? executionId;
    await _run(() async {
      executionId = await widget.repository.getInProgressExecutionId();
      if (executionId == null) {
        // Puede haberse cerrado en otro dispositivo desde la propuesta.
        _plan = await widget.repository.calculate(
          widget.goalId,
          _week,
          activation: true,
        );
        _notice =
            'La sesión ya no está abierta. Hemos actualizado la propuesta.';
      }
    });
    if (!mounted || executionId == null) return;
    // Volver regresa a esta propuesta, sin sustituirla por la agenda de hoy.
    await context.push('/plan/week/active/$executionId');
    if (!mounted) return;
    await _run(() async {
      await _load(initialize: false);
      _plan = await widget.repository.calculate(
        widget.goalId,
        _week,
        activation: true,
      );
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
        ? DateTime(
            today.year,
            today.month,
            today.day + (n.weekday == 1 ? 0 : 8 - n.weekday),
          )
        : DateTime(
            requested.year,
            requested.month,
            requested.day - requested.weekday + 1,
          );
    _load();
  }

  @override
  void dispose() {
    final route = _referenceRoute;
    _referenceRoute = null;
    if (route != null) {
      // Un cambio de titular/objetivo desmonta la página, pero su diálogo vive
      // en el Navigator raíz. Retirar solo esa ruta evita conservar sus datos
      // sobre la nueva cuenta o cerrar una pantalla distinta que esté encima.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  Future<void> _load({bool initialize = true}) async {
    final version = ++_loadVersion;
    try {
      if (initialize) await widget.repository.advance(widget.goalId);
      final d = await widget.repository.load(widget.goalId);
      PreparationSetupStep? savedStep;
      if (initialize &&
          d.programState['auto_advance'] != true &&
          d.programState['status'] != 'paused' &&
          d.programState['status'] != 'complete') {
        try {
          savedStep = await widget.progressStore?.read(widget.goalId);
        } catch (_) {
          // Se puede configurar el plan aunque la preferencia local no se lea.
        }
      }
      if (!mounted || version != _loadVersion) return;
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
          if (widget.editOnOpen && _started) _editing = true;
          if (!_started &&
              !_paused &&
              d.programState['status'] != 'complete' &&
              savedStep != null) {
            _step = _resumeIndex(savedStep);
            _notice = 'Continuamos desde tus datos guardados. Puedes volver a los pasos anteriores para revisarlos.';
          }
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
        if (mounted && version == _loadVersion) {
          setState(() => _plan = published);
        }
      }
    } catch (e) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = _message(e));
      }
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
      if (mounted) {
        setState(() => _busy = false);
        await _rememberStep();
      }
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
      if (_targetError(value, mode) != null) {
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
    bool replacePersonalObjective = false,
  }) async {
    if (_referenceRoute != null) return;
    final data = _data!;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<PerformanceReferenceInput>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: false,
      barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (_) => PerformanceReferenceDialog(
        data: data,
        objective: objective,
        existing: existing,
        initialWorkCode: initialWorkCode,
        initialMeasurement: initialMeasurement,
        onSave: (input) async {
          if (!mounted) throw StateError('La preparación ya no está abierta.');
          await widget.repository.saveReference(widget.goalId, {
            ...input.reference,
            if (replacePersonalObjective) 'replace_personal_objective': true,
          }, testId: input.testId);
        },
      ),
    );
    _referenceRoute = route;
    final input = await navigator.push(route);
    if (identical(_referenceRoute, route)) _referenceRoute = null;
    if (input == null || !mounted) return;
    await _run(() async {
      if (objective != null || data.personalObjectiveLimit == null) {
        _equipment.addAll(input.equipment);
      }
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
  Future<void> _publish() async {
    var accepted = false;
    await _run(() async {
      final reviewed = {..._plan!}..remove('strength_schedule_alternative');
      final p = reviewed['revision'] != null
          ? await widget.repository.publish(widget.goalId, _week, reviewed)
          : await widget.repository.activate(widget.goalId, _week, reviewed);
      accepted = true;
      await _load(initialize: false);
      if (mounted) {
        setState(() {
          _plan = p;
          _editing = false;
          _notice = p['revision'] != null
              ? 'Las sesiones pendientes ya usan tus datos actuales. El plan continúa automáticamente.'
              : null;
        });
      }
    });
    if (!accepted || !mounted) return;
    try {
      await widget.progressStore?.clear(widget.goalId);
    } catch (_) {
      // Un fallo de la preferencia local no revierte una activación aceptada.
    }
    if (!mounted || GoRouter.maybeOf(context) == null) return;
    // La operación ya terminó: liberar busy antes de atravesar la guardia de
    // salida y mostrar la consulta canónica sin apilar otro panel de gestión.
    showPreparationContext(
      context,
      goalId: widget.goalId,
      week: _week,
      plan: true,
    );
  }

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
      _week = DateTime(
        today.year,
        today.month,
        today.day + (today.weekday == 1 ? 0 : 8 - today.weekday),
      );
      _step = review ? 1 : 0;
    });
  }

  Future<void> _pause() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pausar mi plan'),
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
            child: const Text('Pausar plan'),
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
    dismissKeyboard();
    final confirmation = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TrialResetDialog(),
    );
    // El diálogo puede restaurar el foco anterior al cerrarse. El nuevo paso
    // no debe heredar ni ese campo ni el teclado de confirmación.
    dismissKeyboard();
    if (confirmation == null || !mounted) return;
    await _run(() async {
      await widget.repository.resetTrial(widget.goalId, confirmation);
      if (!mounted) return;
      final today = DateUtils.dateOnly(DateTime.now());
      setState(() {
        _data = null;
        _week = DateTime(
          today.year,
          today.month,
          today.day + (today.weekday == 1 ? 0 : 8 - today.weekday),
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
      leading: IconButton(
        tooltip: 'Volver',
        onPressed: _busy ? null : _back,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _data != null &&
                    (_started ||
                        _paused ||
                        _data!.programState['status'] == 'complete') &&
                    !_editing
                ? 'Mi plan adaptativo'
                : _editing
                ? 'Cambiar configuración'
                : 'Configurar mi plan',
          ),
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
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
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
        'Configura tu plan',
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
              : 'Prueba: ${DateFormat('dd-MM-yyyy').format(_targetDate!)}',
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
            ? 'Retomar mi plan con mis datos actuales'
            : _started
            ? 'Guardar los cambios de mi plan'
            : 'Tu plan, listo para revisar',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      if (_targetDate != null)
        Text('Prueba: ${DateFormat('dd-MM-yyyy').format(_targetDate!)}'),
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
                  _week = DateTime(
                    today.year,
                    today.month,
                    today.day + (today.weekday == 1 ? 0 : 8 - today.weekday),
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
      key: key == null ? null : _targetAnchors.putIfAbsent(key, GlobalKey.new),
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
                  : 'Referencia: ${_referenceDate(ref['observed_on'])} · $count ${count == 1 ? 'serie' : 'series'}',
            ),
            if (key != null && measurement != 'PASS_FAIL') ...[
              const SizedBox(height: 12),
              TextFormField(
                enabled: !_busy,
                key: ValueKey('target-$key'),
                initialValue: targetValue == null
                    ? ''
                    : timed
                    ? formatDurationSeconds(targetValue)
                    : targetValue.toString(),
                inputFormatters: timed
                    ? const [DurationInputFormatter(allowFraction: true)]
                    : null,
                keyboardType: timed
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Marca objetivo',
                  suffixText: timed ? null : _unit(measurement),
                  hintText: timed ? '00:00' : null,
                  helperText:
                      '${timed ? 'Min:seg. ' : ''}Deja vacío para mejorar sin fijar una marca.',
                ),
                onChanged: (text) {
                  setState(() {
                    _plan = null;
                    final parsed = timed
                        ? parsePerformanceTime(text)
                        : num.tryParse(text.trim().replaceAll(',', '.'));
                    // Los valores no finitos tampoco pueden entrar en el sello
                    // JSON del borrador; el campo sigue mostrando su error.
                    final value = parsed?.isFinite == true ? parsed : null;
                    if (text.trim().isEmpty) {
                      _targets.remove(key);
                    } else {
                      _targets[key] = {
                        'measurement': measurement,
                        'value': value,
                      };
                    }
                  });
                },
                validator: (text) => text == null || text.trim().isEmpty
                    ? null
                    : _targetError(
                        (_targets[key] as Map?)?['value'] as num?,
                        measurement,
                      ),
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
            if (row != null &&
                _data!.personalObjectiveLimit != null &&
                _personalObjectiveCount > 1 &&
                _personalReferences.contains(row))
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _reference(
                        existing: row,
                        replacePersonalObjective: true,
                      ),
                child: const Text('Mantener este objetivo personal'),
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
      TextButton(
        onPressed: _busy ? null : () => _goStep(0),
        child: const Text('Atrás'),
      ),
    ],
  );
  Iterable<Map<String, dynamic>> get _personalReferences =>
      _data!.references.where(
        (row) =>
            row['test_id'] == null &&
            !(row['objective_key'] as String? ?? '').startsWith('legacy:') &&
            !_data!.objectives.any(
              (o) => o['objective_key'] == row['objective_key'],
            ),
      );

  int get _personalObjectiveCount =>
      _personalReferences.map((r) => r['objective_key']).toSet().length;

  Widget _movements() => Form(
    key: _targetFormKey,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
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
        if (_data!.personalObjectiveLimit != null)
          Text(
            _personalObjectiveCount > 1
                ? 'Elige qué objetivo personal quieres mantener. Mientras tanto, se prepara la semana de tus pruebas.'
                : 'Puedes tener un objetivo personal. Se añade cuando cabe después del trabajo de tus pruebas.',
          ),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _reference(
                  replacePersonalObjective:
                      _data!.personalObjectiveLimit != null &&
                      _personalReferences.isNotEmpty,
                ),
          icon: const Icon(Icons.add),
          label: Text(
            _data!.personalObjectiveLimit != null &&
                    _personalReferences.isNotEmpty
                ? 'Cambiar objetivo personal'
                : 'Añadir objetivo de mejora',
          ),
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
              onPressed: _busy ? null : _reviewMovements,
              child: const Text('Revisar mi plan'),
            ),
          ],
        ),
      ],
    ),
  );

  String? _targetError(num? value, Object? measurement) {
    if (value == null || !value.isFinite || value <= 0 || value > 100000) {
      return 'Introduce una marca mayor que cero o deja el campo vacío.';
    }
    if (const ['REPS', 'REPS_IN_TIME'].contains(measurement) &&
        value != value.truncate()) {
      return 'Introduce un número entero de repeticiones.';
    }
    return null;
  }

  void _reviewMovements() {
    if (_targetFormKey.currentState?.validate() != false) {
      _goStep(_previewStep);
      return;
    }
    final invalid = _targets.entries.where((entry) {
      final target = entry.value as Map;
      return _targetError(target['value'] as num?, target['measurement']) !=
          null;
    }).firstOrNull;
    setState(
      () => _error =
          'Revisa la marca objetivo indicada. También puedes dejarla vacía.',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _targetAnchors[invalid?.key]?.currentContext;
      if (mounted && anchor != null) {
        unawaited(
          Scrollable.ensureVisible(
            anchor,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
    });
  }

  String _referenceDate(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? 'Fecha no indicada' : formatAppDate(date);
  }

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
                        ? 'Tu plan está pausado'
                        : 'Tu plan está en marcha',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_targetDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Prueba · ${DateFormat('dd-MM-yyyy').format(_targetDate!)}',
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
                            state['message'] as String? ??
                                (complete
                                    ? 'Conservamos tu última pauta y tus resultados.'
                                    : 'Entrena y registra tus resultados. EntrenaOP prepara la continuación.'),
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
                      _paused ? 'Retomar mi plan' : 'Ver mis entrenamientos',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    complete
                        ? 'Puedes consultar los entrenamientos y resultados de esta preparación.'
                        : _paused
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
                      title: const Text('¿Ya has practicado algún apoyo?'),
                      subtitle: const Text(
                        'Opcional · aprovecha una referencia que ya tengas',
                      ),
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'El programa elige los apoyos y puede introducir una primera práctica guiada cuando haga falta. No tienes que calibrarlos todos. Si ya tienes un resultado reciente de uno de estos ejercicios, puedes registrarlo aquí para aprovecharlo.',
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
                          : complete
                          ? 'Revisar configuración'
                          : 'Cambiar configuración',
                    ),
                  ),
                  if (_started)
                    TextButton.icon(
                      onPressed: _busy ? null : _pause,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Pausar mi plan'),
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
        PreparationGoalReviewPanel(reviews: _rows(p['goal_reviews'])),
        PreparationControlSchedule(
          schedule:
              (p['control_schedule'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
        if (!published)
          if (p['strength_schedule_alternative'] case final Map move)
            _StrengthScheduleAlternative(
              move: move.cast<String, dynamic>(),
              onOpenAgenda: !showActions || _busy
                  ? null
                  : () async {
                      final date = move['from_date'] as String;
                      final id = Uri.encodeQueryComponent(move['scheduled_id'] as String);
                      await context.push('/plan/week?date=$date&session=$id');
                      if (mounted) await _calculate(revise: p['revision'] != null);
                    },
            ),
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
              onTap: _busy || item['status'] == 'personal_objective_deferred'
                  ? null
                  : () => _openIssue(item),
              trailing: item['status'] == 'personal_objective_deferred'
                  ? null
                  : const Icon(Icons.chevron_right),
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
                        if (work['personal_extra'] == true)
                          const Text(
                            'Objetivo personal · al final de la sesión, después del trabajo de las pruebas.',
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
                    ? 'Retomar mi plan'
                    : _scopeChanged
                    ? 'Aplicar selección de entrenamiento'
                    : 'Activar mi plan',
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

class _StrengthScheduleAlternative extends StatelessWidget {
  const _StrengthScheduleAlternative({required this.move, this.onOpenAgenda});

  final Map<String, dynamic> move;
  final VoidCallback? onOpenAgenda;

  String _day(String value) {
    final date = DateTime.parse(value);
    const names = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    return '${names[date.weekday - 1]} ${DateFormat('d/M').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ...move['agenda'] as List,
      ...move['running'] as List,
      ...move['performance'] as List,
    ].cast<Map>()..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.event_repeat_rounded),
        title: const Text('Un cambio de agenda deja hueco para las series'),
        subtitle: Text(
          'Puedes mover «${move['name']}» del ${_day(move['from_date'] as String)} '
          'al ${_day(move['to_date'] as String)} o conservar la propuesta actual.',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Así quedaría la semana', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_day(row['date'] as String)} · ${row['name']}'
                '${row['minutes'] == null ? '' : ' · ${row['minutes']} min'}',
              ),
            ),
          if (onOpenAgenda != null)
            OutlinedButton(
              onPressed: onOpenAgenda,
              child: const Text('Abrir sesión en mi agenda'),
            ),
        ],
      ),
    );
  }
}

class _TrialResetDialog extends StatefulWidget {
  const _TrialResetDialog();
  @override
  State<_TrialResetDialog> createState() => _TrialResetDialogState();
}

class _TrialResetDialogState extends State<_TrialResetDialog> {
  final _input = TextEditingController();

  void _close([String? confirmation]) {
    dismissKeyboard();
    Navigator.pop(context, confirmation);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EntrenaDialog(
    title: const Text('Reiniciar los ensayos de este programa'),
    content: Column(
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
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => dismissKeyboard(),
          decoration: const InputDecoration(labelText: 'Escribe REINICIAR'),
        ),
        const SizedBox(height: 12),
      ],
    ),
    actions: [
      EntrenaDialogActions(
        primaryLabel: 'Cancelar',
        onPrimary: _close,
        secondary: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (_, value, _) => OutlinedButton(
              onPressed: value.text == 'REINICIAR'
                  ? () => _close(value.text)
                  : null,
              style: EntrenaButtonStyles.destructive(context),
              child: const Text(
                'Borrar ensayos y reiniciar',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
