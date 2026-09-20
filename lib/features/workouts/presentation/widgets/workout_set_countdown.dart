import 'dart:async';

import 'package:flutter/material.dart';

/// Cuenta atras para las series cuya prescripcion se expresa en segundos.
///
/// Un reloj monotónico evita perder precisión si el sistema ralentiza los
/// repintados cuando la aplicación queda momentáneamente en segundo plano.
class WorkoutSetCountdown extends StatefulWidget {
  const WorkoutSetCountdown({
    required this.targetSeconds,
    required this.onElapsedChanged,
    this.preparationSeconds = 3,
    this.enabled = true,
    this.clock,
    super.key,
  }) : assert(targetSeconds > 0),
       assert(preparationSeconds >= 0);

  final int targetSeconds;
  final ValueChanged<int> onElapsedChanged;
  final int preparationSeconds;
  final bool enabled;

  /// Fuente de tiempo inyectable para comprobar el temporizador sin esperas
  /// reales. En la aplicación se usa un [Stopwatch] monotónico interno.
  final Duration Function()? clock;

  @override
  State<WorkoutSetCountdown> createState() => _WorkoutSetCountdownState();
}

class _WorkoutSetCountdownState extends State<WorkoutSetCountdown> {
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;
  int _elapsedSeconds = 0;
  Duration _elapsedBeforeRun = Duration.zero;
  Duration? _runStartedAt;
  bool _hasStarted = false;
  bool _isPreparing = false;
  int _preparationRemaining = 0;

  Duration get _now => widget.clock?.call() ?? _clock.elapsed;
  bool get _isRunning => _runStartedAt != null;
  bool get _isFinished => _elapsedSeconds >= widget.targetSeconds;
  int get _remainingSeconds =>
      (widget.targetSeconds - _elapsedSeconds).clamp(0, widget.targetSeconds);

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.stop();
    super.dispose();
  }

  void _toggle() {
    if (_isRunning) {
      _synchronise();
      _elapsedBeforeRun = _currentElapsed;
      _runStartedAt = null;
      _ticker?.cancel();
      setState(() {});
      return;
    }

    if (_isFinished) _reset(notify: false);
    if (!_hasStarted) return _startPreparation();
    _startExerciseTimer();
  }

  void _startPreparation() {
    _hasStarted = true;
    widget.onElapsedChanged(0);
    if (widget.preparationSeconds == 0) {
      _startExerciseTimer();
      return;
    }

    _isPreparing = true;
    _preparationRemaining = widget.preparationSeconds;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_preparationRemaining > 1) {
        setState(() => _preparationRemaining--);
        return;
      }
      timer.cancel();
      _isPreparing = false;
      _preparationRemaining = 0;
      _startExerciseTimer();
    });
    setState(() {});
  }

  void _startExerciseTimer() {
    _runStartedAt = _now;
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _synchronise(),
    );
    setState(() {});
  }

  void _synchronise() {
    final elapsed = (_currentElapsed.inMilliseconds ~/ 1000).clamp(
      0,
      widget.targetSeconds,
    );
    if (elapsed == _elapsedSeconds) return;

    _elapsedSeconds = elapsed;
    widget.onElapsedChanged(elapsed);
    if (_isFinished) {
      _elapsedBeforeRun = Duration(seconds: widget.targetSeconds);
      _runStartedAt = null;
      _ticker?.cancel();
    }
    if (mounted) setState(() {});
  }

  void _reset({bool notify = true}) {
    _ticker?.cancel();
    _elapsedBeforeRun = Duration.zero;
    _runStartedAt = null;
    _elapsedSeconds = 0;
    _hasStarted = false;
    _isPreparing = false;
    _preparationRemaining = 0;
    // Al reiniciar recuperamos el objetivo como resultado propuesto. Asi el
    // usuario todavia puede registrar una medicion hecha con otro reloj.
    if (notify) widget.onElapsedChanged(widget.targetSeconds);
    if (mounted) setState(() {});
  }

  Duration get _currentElapsed {
    final startedAt = _runStartedAt;
    if (startedAt == null) return _elapsedBeforeRun;
    return _elapsedBeforeRun + (_now - startedAt);
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = switch ((
      _isPreparing,
      _isRunning,
      _hasStarted,
      _isFinished,
    )) {
      (true, _, _, _) => 'Cancelar',
      (_, true, _, _) => 'Pausar',
      (_, false, _, true) => 'Repetir',
      (_, false, true, false) => 'Reanudar',
      _ => 'Iniciar temporizador',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text(
              'TEMPORIZADOR DE LA SERIE',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              label: _isPreparing
                  ? 'Prepárate, $_preparationRemaining'
                  : 'Quedan $_remainingSeconds segundos',
              child: Text(
                _isPreparing
                    ? '$_preparationRemaining'
                    : _formatClock(_remainingSeconds),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: _isFinished
                      ? Colors.greenAccent
                      : const Color(0xFFFFA06F),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isPreparing
                  ? 'Prepárate…'
                  : _isFinished
                  ? 'Tiempo completado'
                  : 'Realizado: $_elapsedSeconds s',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.enabled
                        ? (_isPreparing ? _reset : _toggle)
                        : null,
                    icon: Icon(
                      _isPreparing
                          ? Icons.close_rounded
                          : _isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(actionLabel),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Reiniciar temporizador',
                  onPressed: widget.enabled && _hasStarted ? _reset : null,
                  icon: const Icon(Icons.replay_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatClock(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}
