import 'dart:async';

import 'package:flutter/material.dart';

import '../../../exercises/domain/entities/exercise_entity.dart';
import '../../domain/entities/workout_execution.dart';
import '../../domain/services/workout_cue_service.dart';
import '../../domain/services/workout_timer_store.dart';
import 'workout_execution_layout.dart';
import 'workout_execution_labels.dart';
import 'workout_exercise_technique.dart';

/// Un único reloj evita sumar preparación y latencia de guardado entre rondas.
class WorkoutTabataEntry extends StatefulWidget {
  const WorkoutTabataEntry({
    required this.executionId,
    required this.sets,
    required this.exercises,
    required this.timerStore,
    required this.cueService,
    required this.onIntervalEnded,
    required this.records,
    this.onContinue,
    this.clock,
    this.wallClock,
    super.key,
  });

  final String executionId;
  final List<WorkoutExecutionSet> sets;
  final Map<String, ExerciseEntity> exercises;
  final WorkoutTimerStore timerStore;
  final WorkoutCueService cueService;
  final Future<bool> Function(String setId) onIntervalEnded;
  final Widget records;
  final VoidCallback? onContinue;
  final Duration Function()? clock;
  final DateTime Function()? wallClock;

  @override
  State<WorkoutTabataEntry> createState() => _WorkoutTabataEntryState();
}

class _WorkoutTabataEntryState extends State<WorkoutTabataEntry> {
  static const _preparation = 3;
  final _clock = Stopwatch();
  final _endedIds = <String>{};
  Timer? _ticker;
  Duration _beforeRun = Duration.zero;
  Duration? _startedAt;
  bool _loading = true, _hasStarted = false, _syncing = false;
  bool _changing = false, _finished = false;
  bool _restoreFailed = false;
  String? _error;
  int _seconds = 0;

  Duration get _now => widget.clock?.call() ?? _clock.elapsed;
  DateTime get _wallNow => (widget.wallClock?.call() ?? DateTime.now()).toUtc();
  String get _timerId =>
      '${widget.executionId}:tabata:${widget.sets.first.blockOrder}';
  int get _total => _preparation + widget.sets.length * 30;
  bool get _running => _startedAt != null;
  Duration get _elapsed =>
      _beforeRun + (_startedAt == null ? Duration.zero : _now - _startedAt!);
  int get _round => ((_seconds - _preparation).clamp(0, _total) ~/ 30).clamp(
    0,
    widget.sets.length - 1,
  );
  bool get _preparing => _seconds < _preparation;
  bool get _resting => !_preparing && (_seconds - _preparation) % 30 >= 20;
  int get _remaining => _seconds >= _total
      ? 0
      : _preparing
      ? _preparation - _seconds
      : (_resting ? 30 : 20) - (_seconds - _preparation) % 30;

  @override
  void initState() {
    super.initState();
    _clock.start();
    _endedIds.addAll(
      widget.sets
          .where((s) => s.status != WorkoutSetStatus.pending)
          .map((s) => s.id),
    );
    unawaited(_restore());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.stop();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final snapshot = await widget.timerStore.read(_timerId);
      if (!mounted) return;
      final firstPending = widget.sets.indexWhere(
        (s) => s.status == WorkoutSetStatus.pending,
      );
      final initial = firstPending > 0 ? _preparation + firstPending * 30 : 0;
      _beforeRun = Duration(seconds: initial);
      if (snapshot != null && snapshot.targetSeconds == _total) {
        _hasStarted = true;
        var elapsed = snapshot.elapsedBeforeRun;
        if (snapshot.phase == WorkoutTimerPhase.running) {
          final sinceWrite = _wallNow.difference(snapshot.phaseStartedAt);
          if (!sinceWrite.isNegative) elapsed += sinceWrite;
        }
        _beforeRun = elapsed;
        if (snapshot.phase == WorkoutTimerPhase.running) _startedAt = _now;
      }
      _loading = false;
      _restoreFailed = false;
      _error = null;
      _seconds = _elapsed.inSeconds.clamp(0, _total);
      setState(() {});
      if (_running) {
        _startTicker();
        await _synchronise();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _restoreFailed = true;
        _error =
            'No se ha podido recuperar el reloj. Reintenta para continuar.';
      });
    }
  }

  Future<void> _persist() => widget.timerStore.write(
    _timerId,
    WorkoutTimerSnapshot(
      phase: _running ? WorkoutTimerPhase.running : WorkoutTimerPhase.paused,
      targetSeconds: _total,
      // La preparación forma parte del mismo reloj y también admite pausa.
      preparationSeconds: 0,
      phaseStartedAt: _wallNow,
      elapsedBeforeRun: _elapsed,
    ),
  );

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(_synchronise()),
    );
  }

  Future<void> _toggle() async {
    if (_restoreFailed) return _restore();
    if (_changing || _finished) return;
    _changing = true;
    if (_running) {
      _beforeRun = _elapsed;
      _startedAt = null;
      _ticker?.cancel();
    } else {
      if (!_hasStarted && _preparing) _signal(WorkoutCue.preparationTick);
      _hasStarted = true;
      _startedAt = _now;
    }
    setState(() => _error = null);
    try {
      await _persist();
      if (!mounted) return;
      if (_running) {
        _startTicker();
        await _synchronise();
      }
    } catch (_) {
      _stopWithError();
    } finally {
      _changing = false;
      if (mounted) setState(() {});
    }
  }

  void _stopWithError() {
    if (!mounted) return;
    _beforeRun = _elapsed;
    _startedAt = null;
    _ticker?.cancel();
    setState(() {
      _error =
          'No se ha podido conservar el progreso. Reanuda para reintentar.';
    });
    // Se intenta conservar la pausa sin ocultar el fallo original.
    unawaited(_persist().catchError((Object _) {}));
  }

  void _signal(WorkoutCue cue) => unawaited(widget.cueService.signal(cue));

  Future<void> _synchronise() async {
    if (!mounted || _syncing) return;
    final previous = _seconds;
    _seconds = _elapsed.inSeconds.clamp(0, _total);
    if (previous != _seconds) {
      setState(() {});
      // Un salto de reloj solo anuncia la fase actual, sin ráfagas atrasadas.
      if (_seconds >= _total) {
        _signal(WorkoutCue.workFinished);
      } else if (_preparing) {
        _signal(WorkoutCue.preparationTick);
      } else if (previous < _preparation ||
          (previous - _preparation) ~/ 30 != _round) {
        _signal(_resting ? WorkoutCue.workFinished : WorkoutCue.workStarted);
      } else if (_resting && (previous - _preparation) % 30 < 20) {
        _signal(WorkoutCue.workFinished);
      } else if (_remaining <= 3) {
        _signal(WorkoutCue.workEndingTick);
      }
    }
    _syncing = true;
    try {
      for (var i = 0; i < widget.sets.length; i++) {
        final set = widget.sets[i];
        // La última recuperación pertenece al Tabata; no arranca otro bloque.
        final end = i == widget.sets.length - 1
            ? _total
            : _preparation + i * 30 + 20;
        if (_seconds < end || _endedIds.contains(set.id)) continue;
        if (!await widget.onIntervalEnded(set.id)) {
          _stopWithError();
          return;
        }
        _endedIds.add(set.id);
        if (!mounted) {
          if (_seconds >= _total) await widget.timerStore.clear(_timerId);
          return;
        }
      }
      if (_seconds >= _total) {
        _ticker?.cancel();
        await widget.timerStore.clear(_timerId);
        if (!mounted) return;
        setState(() {
          _beforeRun = Duration(seconds: _total);
          _startedAt = null;
          _finished = true;
        });
      }
    } catch (_) {
      _stopWithError();
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final set = widget.sets[_round];
    final next = _round + 1 < widget.sets.length
        ? widget.sets[_round + 1]
        : null;
    final phase = _finished
        ? 'Tabata completado'
        : !_hasStarted
        ? 'Listo para empezar'
        : !_running
        ? 'En pausa'
        : _preparing
        ? 'Prepárate…'
        : _resting
        ? 'Recuperación'
        : 'Trabajo';
    return WorkoutExecutionFrame(
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _finished
                ? widget.onContinue
                : _changing
                ? null
                : _toggle,
            icon: Icon(
              _finished
                  ? Icons.arrow_forward_rounded
                  : _running
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              _finished
                  ? 'Continuar'
                  : _restoreFailed
                  ? 'Reintentar'
                  : _running
                  ? 'Pausar'
                  : _hasStarted
                  ? 'Reanudar'
                  : 'Iniciar Tabata',
            ),
          ),
          widget.records,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.sets.first.blockName} · Tabata · 8 × 20/10'),
          const SizedBox(height: 16),
          WorkoutExerciseHeader(
            name: set.exerciseName,
            position: 'Intervalo ${_round + 1} de ${widget.sets.length}',
            imageUrl: widget.exercises[set.exerciseId]?.thumbnailUrl,
            onTechnique: () => showWorkoutTechnique(context, set),
          ),
          const SizedBox(height: 20),
          Text(
            phase,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Semantics(
            liveRegion: true,
            label: '$phase, quedan $_remaining segundos',
            child: Text(
              workoutClock(!_hasStarted ? 20 : _remaining),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: _resting ? Colors.greenAccent : const Color(0xFFFFA06F),
              ),
            ),
          ),
          if (_resting)
            Text(
              next == null
                  ? 'Última recuperación'
                  : 'A continuación: ${next.exerciseName}',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          const Text(
            'Trabajo y recuperación avanzan automáticamente. '
            'Podrás revisar los tiempos y completar los datos al terminar.',
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }
}
