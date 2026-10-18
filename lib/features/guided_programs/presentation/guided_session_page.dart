import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_core/workout_template.dart';

import '../../exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import '../../workouts/domain/repositories/workout_repository.dart';
import '../../workouts/domain/usecases/get_starter_workout_usecase.dart';
import '../../workouts/domain/usecases/workout_execution_usecases.dart';
import '../../workouts/presentation/bloc/workout_preview_cubit.dart';
import '../../workouts/presentation/pages/workout_preview_page.dart';
import '../domain/guided_program_repository.dart';
import '../domain/start_guided_session.dart';

class GuidedSessionPage extends StatefulWidget {
  const GuidedSessionPage({
    super.key,
    required this.repository,
    required this.workouts,
    required this.programId,
    required this.phaseIndex,
    required this.sessionIndex,
    required this.getTemplate,
    required this.startDefault,
    this.getExercise,
  });
  final GuidedProgramRepository repository;
  final WorkoutRepository workouts;
  final String programId;
  final int phaseIndex, sessionIndex;
  final GetWorkoutTemplateUseCase getTemplate;
  final StartWorkoutExecutionUseCase startDefault;
  final GetExerciseByIdUseCase? getExercise;
  @override
  State<GuidedSessionPage> createState() => _GuidedSessionPageState();
}

class _GuidedSessionPageState extends State<GuidedSessionPage> {
  late Future<GuidedProgramDetail> _detail = _load();
  Future<GuidedProgramDetail> _load() async {
    final d = await widget.repository.detail(widget.programId);
    if (widget.phaseIndex < 0 ||
        widget.phaseIndex >= d.program.phases.length ||
        widget.sessionIndex < 0 ||
        widget.sessionIndex >=
            d.program.phases[widget.phaseIndex].sessions.length) {
      throw const FormatException(
        'La sesión no está disponible en este programa.',
      );
    }
    return d;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GuidedProgramDetail>(
    future: _detail,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return _GuidedPreview(
          key: ValueKey(
            '${widget.programId}/${widget.phaseIndex}/${widget.sessionIndex}',
          ),
          entry: widget,
          detail: snapshot.data!,
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Preparar sesión'),
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/library');
              }
            },
          ),
        ),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar la sesión del programa.'),
                    TextButton(
                      onPressed: () => setState(() => _detail = _load()),
                      child: const Text('Reintentar'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}

class _GuidedPreview extends StatefulWidget {
  const _GuidedPreview({super.key, required this.entry, required this.detail});
  final GuidedSessionPage entry;
  final GuidedProgramDetail detail;
  @override
  State<_GuidedPreview> createState() => _GuidedPreviewState();
}

class _GuidedPreviewState extends State<_GuidedPreview> {
  late final WorkoutPreviewCubit _cubit;
  late StartGuidedSession _launch;
  bool _omitWarmup = false, _attempted = false;
  bool _checking = false, _refreshFailed = false;
  int? _restSeconds;
  @override
  void initState() {
    super.initState();
    final e = widget.entry,
        session = widget
            .detail
            .program
            .phases[widget.entry.phaseIndex]
            .sessions[widget.entry.sessionIndex];
    _launch = _newLaunch();
    _cubit = WorkoutPreviewCubit(
      templateId: session.templateId,
      getWorkoutTemplate: e.getTemplate,
      startExecution: e.startDefault,
      getExercise: e.getExercise,
      startOverride: (_) async {
        setState(() => _attempted = true);
        return _launch(omitWarmup: _omitWarmup, restSeconds: _restSeconds);
      },
    )..load();
  }

  StartGuidedSession _newLaunch() {
    final e = widget.entry;
    return StartGuidedSession(
      repository: e.repository,
      workouts: e.workouts,
      programId: e.programId,
      phaseIndex: e.phaseIndex,
      sessionIndex: e.sessionIndex,
      operationId: const Uuid().v4(),
    );
  }

  Future<void> _afterExecution() async {
    if (!mounted) return;
    setState(() {
      _checking = true;
      _refreshFailed = false;
    });
    try {
      final detail = await widget.entry.repository.detail(
        widget.entry.programId,
      );
      if (!mounted) return;
      if (!detail.runs.any((r) => r.status == 'in_progress')) {
        _launch = _newLaunch();
        _attempted = false;
      }
    } catch (_) {
      if (mounted) _refreshFailed = true;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _settings() async {
    final session = widget
        .detail
        .program
        .phases[widget.entry.phaseIndex]
        .sessions[widget.entry.sessionIndex];
    final warmup =
        session.warmupId != null ||
        (_cubit.state.workout?.blocks.any(
              (b) => b.format == WorkoutBlockFormat.warmUp,
            ) ??
            false);
    final input = TextEditingController(text: _restSeconds?.toString() ?? '');
    var includeWarmup = !_omitWarmup, useOriginal = _restSeconds == null;
    String? error;
    final result = await showModalBottomSheet<({bool omit, int? rest})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajustes de esta sesión',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (warmup)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Calentamiento guiado'),
                  subtitle: const Text(
                    'Puedes omitirlo también durante la sesión.',
                  ),
                  value: includeWarmup,
                  onChanged: (v) => update(() => includeWarmup = v),
                ),
              if (session.restPolicy.adjustable) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Descansos según la pauta'),
                  value: useOriginal,
                  onChanged: (v) => update(() => useOriginal = v),
                ),
                if (!useOriginal)
                  TextField(
                    controller: input,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Descanso entre series (segundos)',
                      helperText:
                          'Entre ${session.restPolicy.minimumSeconds} y ${session.restPolicy.maximumSeconds} s',
                      errorText: error,
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'El ajuste se aplica a las series convencionales. Los formatos temporizados conservan sus tiempos.',
                ),
              ] else
                const Text(
                  'Los descansos están fijados por la pauta de esta sesión.',
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final rest = useOriginal
                      ? null
                      : int.tryParse(input.text.trim());
                  if (!useOriginal &&
                      (rest == null ||
                          rest < session.restPolicy.minimumSeconds! ||
                          rest > session.restPolicy.maximumSeconds!)) {
                    update(
                      () => error = 'Introduce un descanso dentro del rango.',
                    );
                    return;
                  }
                  Navigator.pop(ctx, (omit: !includeWarmup, rest: rest));
                },
                child: const Text('Aplicar ajustes'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
    // El campo del panel termina su animación de salida antes de liberarlo.
    Future<void>.delayed(const Duration(milliseconds: 400), input.dispose);
    if (result != null && mounted) {
      setState(() {
        _omitWarmup = result.omit;
        _restSeconds = result.rest;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final follow = widget.detail.follow;
    final canTrain =
        follow != null && follow.active && follow.phaseIndex == e.phaseIndex;
    final session =
        widget.detail.program.phases[e.phaseIndex].sessions[e.sessionIndex];
    return BlocProvider.value(
      value: _cubit,
      child: WorkoutPreviewPage(
        canStart: canTrain && !_checking && !_refreshFailed,
        onExecutionReturned: _afterExecution,
        routeBase:
            '/library/programs/${e.programId}/session/${e.phaseIndex}/${e.sessionIndex}',
        sessionOptions: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_refreshFailed)
              TextButton(
                onPressed: _afterExecution,
                child: const Text('Reintentar actualización del entrenamiento'),
              ),
            if (!canTrain)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  follow == null
                      ? 'Inicia el programa desde su ficha para entrenar con seguimiento.'
                      : follow.abandoned
                      ? 'Has dejado este programa. Puedes volver a iniciarlo desde su ficha.'
                      : follow.completed
                      ? 'Programa completado. Puedes repetirlo desde su ficha.'
                      : 'Vista previa: esta sesión pertenece a otra fase.',
                ),
              ),
            if (canTrain && session.warmupId != null && !_omitWarmup)
              Text(
                'Incluye calentamiento opcional',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_restSeconds != null || _omitWarmup)
              Text(
                [
                  if (_omitWarmup) 'Calentamiento omitido',
                  if (_restSeconds != null) 'Descanso: $_restSeconds s',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (canTrain)
              TextButton.icon(
                onPressed: _attempted ? null : _settings,
                icon: const Icon(Icons.tune, size: 18),
                label: Text(
                  _attempted ? 'Ajustes conservados' : 'Ajustes de esta sesión',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
