import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_core/running_step.dart';

import '../../domain/services/phone_run_plan.dart';
import '../../domain/services/phone_running.dart';
import '../../domain/services/workout_cue_service.dart';

enum PhoneRunPhase {
  loading,
  idle,
  acquiring,
  recording,
  stopping,
  paused,
  review,
}

class PhoneRunState {
  const PhoneRunState(
    this.phase, {
    this.totals = const PhoneRunTotals(),
    this.signalLost = false,
    this.message,
    this.step,
    this.nextStep,
    this.stepNumber = 0,
    this.stepCount = 0,
    this.recentPace,
    this.sessionDistanceMeters = 0,
    this.trackMode = false,
    this.voice = PhoneRunVoice.off,
    this.paceAlerts = false,
  });

  final PhoneRunPhase phase;
  final PhoneRunTotals totals;
  final bool signalLost;
  final String? message;
  final PhoneRunStep? step, nextStep;
  final int stepNumber, stepCount;
  final int? recentPace;
  final double sessionDistanceMeters;
  final bool trackMode, paceAlerts;
  final PhoneRunVoice voice;

  bool get busy =>
      phase == PhoneRunPhase.loading || phase == PhoneRunPhase.stopping;
  bool get tracking =>
      phase == PhoneRunPhase.acquiring || phase == PhoneRunPhase.recording;
}

class PhoneRunCubit extends Cubit<PhoneRunState> {
  PhoneRunCubit({
    required this.executionId,
    required PhoneRunLocationSource location,
    required PhoneRunCheckpoints checkpoints,
    DateTime Function() now = DateTime.now,
    WorkoutCueService? cues,
    PhoneRunFeedback? feedback,
  }) : _location = location,
       _checkpoints = checkpoints,
       _now = now,
       _cues = cues,
       _feedback = feedback,
       super(const PhoneRunState(PhoneRunPhase.loading));

  final String executionId;
  final PhoneRunLocationSource _location;
  final PhoneRunCheckpoints _checkpoints;
  final DateTime Function() _now;
  final WorkoutCueService? _cues;
  final PhoneRunFeedback? _feedback;
  PhoneRunTrack _track = PhoneRunTrack();
  StreamSubscription<PhoneRunLocationEvent>? _subscription;
  Timer? _clock;
  DateTime? _acquiringSince, _lastCheckpoint;
  String? _token, _message;
  Future<void>? _stopping;
  bool _closing = false;
  List<PhoneRunStep> _steps = const [];
  final _laps = <PhoneRunLap>[];
  int _stepIndex = 0, _splitIndex = 0;
  int? _lastCountdown;
  bool _trackMode = false, _paceAlerts = false, _started = false;
  int? _softGoalSeconds;
  bool _softGoalAnnounced = false;
  PhoneRunVoice _voice = PhoneRunVoice.off;
  DateTime? _lastDisplay, _lastSpoken, _offPaceSince, _lastPaceAlert;
  int _paceDirection = 0;
  Timer? _speechAfterCue;

  PhoneRunStep? get _step =>
      _stepIndex < _steps.length ? _steps[_stepIndex] : null;
  List<PhoneRunLap> get laps => List.unmodifiable(_laps);
  bool get guided => _steps.isNotEmpty;
  PhoneRunLap? get partial {
    final step = _step;
    final totals = _track.totalsAt(_now());
    return step == null || totals.elapsedMilliseconds < 1000
        ? null
        : PhoneRunLap(step.id, totals);
  }

  void configure({bool? trackMode, PhoneRunVoice? voice, bool? paceAlerts}) {
    if (trackMode != null && !state.tracking) _trackMode = trackMode;
    if (voice != null && voice != _voice) {
      _voice = voice;
      _resetSplitIndex();
      if (voice == PhoneRunVoice.off) _silence();
    }
    if (paceAlerts != null) _paceAlerts = paceAlerts;
    _show(state.phase);
    final totals = state.totals;
    if (totals.elapsedMilliseconds > 0 || _laps.isNotEmpty) {
      unawaited(_checkpoint(totals, recording: state.tracking));
    }
  }

  Future<void> open({
    List<PhoneRunStep> steps = const [],
    int? softGoalSeconds,
  }) async {
    _steps = List.unmodifiable(steps);
    _softGoalSeconds = steps.isEmpty ? softGoalSeconds : null;
    try {
      final saved = await _checkpoints.read(executionId);
      if (_closing || state.phase != PhoneRunPhase.loading) return;
      if (saved == null) {
        _show(PhoneRunPhase.idle);
        if (!guided) await start();
        return;
      }
      _trackMode = saved.trackMode;
      _voice = saved.voice;
      _paceAlerts = saved.paceAlerts;
      if (guided) {
        // La secuencia puede haber avanzado por el registro manual.
        final known = {for (final lap in saved.laps) lap.stepId: lap};
        for (final step in _steps) {
          final lap = known[step.id];
          if (lap == null) break;
          _laps.add(lap);
          _stepIndex++;
        }
        if (_step == null) {
          _show(PhoneRunPhase.review);
          return;
        }
        if (_step!.id != saved.stepId) {
          _show(_laps.isEmpty ? PhoneRunPhase.idle : PhoneRunPhase.paused);
          return;
        }
      }
      _track = PhoneRunTrack(
        PhoneRunTotals(
          elapsedMilliseconds: saved.totals.elapsedMilliseconds,
          distanceMeters: saved.totals.distanceMeters,
          distanceReliable: saved.totals.distanceReliable && !saved.recording,
        ),
      );
      _started = saved.totals.elapsedMilliseconds > 0 || _laps.isNotEmpty;
      final softGoal = _softGoalSeconds;
      _softGoalAnnounced =
          softGoal != null &&
          saved.totals.elapsedMilliseconds >= softGoal * 1000;
      _resetSplitIndex();
      if (saved.recording) {
        _message = 'La grabación se interrumpió. Se conserva el tiempo medido hasta entonces.';
      }
      _show(PhoneRunPhase.paused);
    } catch (_) {
      if (state.phase != PhoneRunPhase.loading) return;
      _message = 'No se han podido recuperar los datos guardados en el móvil.';
      _show(PhoneRunPhase.idle);
    }
  }

  Future<void> start() async {
    if (_token != null ||
        _stopping != null ||
        _closing ||
        (guided && _step == null)) {
      return;
    }
    _subscription ??= _location.locations.listen(
      _onLocation,
      onError: (Object _) => unawaited(_interrupt('interrupted')),
    );
    final token = const Uuid().v4();
    _token = token;
    _message = null;
    _show(PhoneRunPhase.acquiring);
    unawaited(_safe(_cues?.prepare));
    try {
      await _location.start(token);
      if (_token != token) return;
      _acquiringSince = _now();
      _lastCheckpoint = null;
      _lastDisplay = null;
      _publishDisplay(token, _acquiringSince!, force: true);
      _clock = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _tick(),
      );
    } on PhoneRunLocationFailure catch (error) {
      if (_token == token) await _interrupt(error.code);
    } catch (_) {
      if (_token == token) await _interrupt('unavailable');
    }
  }

  void _onLocation(PhoneRunLocationEvent event) {
    if (event.token != _token) return;
    if (event.error case final error?) {
      unawaited(_interrupt(error));
      return;
    }
    final fix = event.fix;
    final acquiringSince = _acquiringSince;
    if (fix == null ||
        acquiringSince == null ||
        fix.at.isBefore(acquiringSince)) {
      return;
    }
    _track.add(fix, _now());
    _tick();
  }

  void _tick() {
    final token = _token;
    final acquiringSince = _acquiringSince;
    if (token == null || acquiringSince == null) return;
    final now = _now();
    if (!_track.hasFix) {
      if (now.difference(acquiringSince) >= const Duration(seconds: 60)) {
        unawaited(_interrupt('no_signal'));
      }
      return;
    }
    final totals = _track.totalsAt(now);
    if (!_started) {
      _started = true;
      if (guided) _cue(WorkoutCue.workStarted);
    }
    final step = _step;
    if (step != null && step.reached(totals, trackMode: _trackMode)) {
      _advance(step, totals, now);
      return;
    }
    final softGoal = _softGoalSeconds;
    if (softGoal != null &&
        !_softGoalAnnounced &&
        totals.elapsedMilliseconds >= softGoal * 1000) {
      _softGoalAnnounced = true;
      _cue(WorkoutCue.workFinished);
    }
    if (step != null) _countdown(step, totals);
    _announceSplit(totals, step, now);
    _checkPace(totals, step, now);
    _show(PhoneRunPhase.recording);
    _publishDisplay(token, now);
    final last = _lastCheckpoint;
    if (last == null || now.difference(last) >= const Duration(seconds: 5)) {
      _lastCheckpoint = now;
      unawaited(_checkpoint(totals, recording: true));
    }
  }

  void markLap(String stepId) {
    final step = _step;
    final now = _now();
    final totals = _track.totalsAt(now);
    // La pulsación se refiere al tramo que estaba visible al tocar el botón.
    if (step?.id != stepId ||
        !state.tracking ||
        totals.elapsedMilliseconds < 1000) {
      return;
    }
    _advance(step!, totals, now);
  }

  void _advance(PhoneRunStep step, PhoneRunTotals totals, DateTime now) {
    _laps.add(PhoneRunLap(step.id, totals));
    _stepIndex++;
    _splitIndex = 0;
    _lastCountdown = null;
    _offPaceSince = null;
    _track = _track.nextStep(now);
    _lastCheckpoint = now;
    final pace = step.recovery ? null : totals.paceSecondsPerKm;
    final summary =
        _voice == PhoneRunVoice.off || !_soundEnabled || pace == null
        ? null
        : 'Parcial a ${phoneRunSpokenPace(pace)}';
    final next = _step;
    if (next == null) {
      // Cambia de estado antes de la espera nativa para que un segundo evento no avance.
      unawaited(_finishWithCue(summary));
      return;
    }
    unawaited(_checkpoint(const PhoneRunTotals(), recording: true));
    _cue(
      step.recovery ? WorkoutCue.restFinished : WorkoutCue.workFinished,
      summary: summary,
    );
    _show(PhoneRunPhase.recording);
    if (_token case final token?) _publishDisplay(token, now, force: true);
  }

  Future<void> _finishWithCue(String? summary) async {
    await review();
    if (!_closing) _cue(WorkoutCue.workFinished, summary: summary);
  }

  void _countdown(PhoneRunStep step, PhoneRunTotals totals) {
    if (!step.recovery || step.completion != RunningStepCompletion.time) return;
    final remaining =
        ((step.seconds! * 1000 - totals.elapsedMilliseconds) / 1000).ceil();
    if (remaining >= 1 && remaining <= 3 && remaining != _lastCountdown) {
      _lastCountdown = remaining;
      _cue(WorkoutCue.preparationTick);
    }
  }

  double _splitInterval(PhoneRunStep? step) =>
      step?.meters == null ? (guided ? 0 : 1000) : step!.meters! / 4;

  void _resetSplitIndex() {
    _splitIndex = phoneRunSplitIndex(
      _track.totalsAt(_now()).distanceMeters,
      _splitInterval(_step),
    );
  }

  void _announceSplit(PhoneRunTotals totals, PhoneRunStep? step, DateTime now) {
    if (_voice != PhoneRunVoice.splits ||
        !_soundEnabled ||
        step?.recovery == true ||
        !totals.distanceReliable) {
      return;
    }
    final interval = _splitInterval(step);
    final index = phoneRunSplitIndex(
      totals.distanceMeters,
      interval,
      limit: step == null ? null : 3,
    );
    if (index <= _splitIndex) return;
    _splitIndex = index;
    final pace = totals.paceSecondsPerKm;
    if (pace == null || !_canSpeak(now)) return;
    _speak(
      '${(index * interval).round()} metros, a ${phoneRunSpokenPace(pace)}',
    );
  }

  void _checkPace(PhoneRunTotals totals, PhoneRunStep? step, DateTime now) {
    final pace = _track.recentPaceAt(now);
    final fastest = step?.fastestPace, slowest = step?.slowestPace;
    if (!_paceAlerts ||
        pace == null ||
        fastest == null ||
        slowest == null ||
        !totals.distanceReliable ||
        step?.passive == true) {
      _offPaceSince = null;
      return;
    }
    final direction = pace < fastest
        ? -1
        : pace > slowest
        ? 1
        : 0;
    if (direction == 0 || direction != _paceDirection) _offPaceSince = null;
    _paceDirection = direction;
    if (direction == 0) return;
    final since = _offPaceSince ??= now;
    final last = _lastPaceAlert;
    if (now.difference(since).inSeconds < 8 ||
        (last != null && now.difference(last).inSeconds < 30)) {
      return;
    }
    _lastPaceAlert = now;
    if (_voice != PhoneRunVoice.off && _soundEnabled && _canSpeak(now)) {
      _speak(direction < 0 ? 'Afloja un poco' : 'Acelera un poco');
    } else if (_voice == PhoneRunVoice.off) {
      _cue(direction < 0 ? WorkoutCue.halfway : WorkoutCue.tenSecondsRemaining);
    }
  }

  bool get _soundEnabled => _cues?.preferences.soundEnabled ?? true;
  bool _canSpeak(DateTime now) =>
      _lastSpoken == null || now.difference(_lastSpoken!).inSeconds >= 8;

  void _speak(String text) {
    _lastSpoken = _now();
    unawaited(_safe(() async => _feedback?.speak(text)));
  }

  void _silence() {
    _speechAfterCue?.cancel();
    unawaited(_safe(_feedback?.silence));
  }

  void _cue(WorkoutCue cue, {String? summary}) {
    _silence();
    _lastSpoken = _now();
    unawaited(_safe(() async => _cues?.signal(cue)));
    if (summary != null) {
      _speechAfterCue = Timer(const Duration(milliseconds: 700), () {
        if (!_closing && _voice != PhoneRunVoice.off && _soundEnabled) {
          _speak(summary);
        }
      });
    }
  }

  void _publishDisplay(String token, DateTime now, {bool force = false}) {
    final feedback = _feedback;
    final last = _lastDisplay;
    if (feedback == null ||
        (!force && last != null && now.difference(last).inSeconds < 4)) {
      return;
    }
    _lastDisplay = now;
    final current = state;
    final step = current.step;
    final pace = current.recentPace;
    final progress = switch (step?.completion) {
      RunningStepCompletion.time =>
        '${(step!.seconds! - current.totals.seconds).clamp(0, step.seconds!)} s restantes',
      RunningStepCompletion.distance =>
        '${current.totals.distanceMeters.round()} / ${step!.meters!.round()} m',
      RunningStepCompletion.manual => 'Hasta marcar vuelta',
      null => '',
    };
    unawaited(
      _safe(
        () => feedback.publish(
          token,
          phase: current.phase == PhoneRunPhase.acquiring
              ? 'Buscando GPS'
              : step?.kind.label ?? 'Rodaje',
          progress: progress,
          pace: pace == null
              ? '— min/km'
              : '${pace ~/ 60}:${(pace % 60).toString().padLeft(2, '0')} min/km',
          distance:
              '${(current.sessionDistanceMeters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km',
          seconds: _laps.fold(
            current.totals.seconds,
            (total, lap) => total + lap.totals.seconds,
          ),
        ),
      ),
    );
  }

  Future<void> _safe(Future<void> Function()? operation) async {
    try {
      await operation?.call();
    } catch (_) {
      /* Un aviso no detiene la grabación. */
    }
  }

  Future<void> _checkpoint(
    PhoneRunTotals totals, {
    required bool recording,
  }) async {
    try {
      await _checkpoints.write(
        executionId,
        PhoneRunCheckpoint(
          totals,
          recording: recording,
          stepId: _step?.id,
          laps: laps,
          trackMode: _trackMode,
          voice: _voice,
          paceAlerts: _paceAlerts,
        ),
      );
    } catch (_) {
      _message = 'No se ha podido guardar una copia local.';
      _show(state.phase);
    }
  }

  Future<void> pause() {
    if (_stopping case final pending?) return pending;
    final token = _token;
    if (token == null) {
      if (state.phase == PhoneRunPhase.loading) _show(PhoneRunPhase.idle);
      return Future.value();
    }
    return _stopping = _stop(token).whenComplete(() {
      _stopping = null;
    });
  }

  Future<void> _stop(String token) async {
    _token = null;
    _acquiringSince = null;
    _clock?.cancel();
    _silence();
    final totals = _track.pause(_now());
    _show(PhoneRunPhase.stopping);
    try {
      await _location.stop(token);
    } catch (_) {
      // Cancelar la escucha también detiene la captura en ambos sistemas.
      final subscription = _subscription;
      _subscription = null;
      await subscription?.cancel();
    }
    await _safe(() async => _feedback?.end(token));
    if (totals.elapsedMilliseconds > 0 || _laps.isNotEmpty) {
      await _checkpoint(totals, recording: false);
    }
    _show(
      totals.seconds > 0 || _laps.isNotEmpty
          ? PhoneRunPhase.paused
          : PhoneRunPhase.idle,
    );
  }

  Future<void> _interrupt(String reason) async {
    if (_token == null) return;
    await pause();
    _message = switch (reason) {
      'permission' => 'Activa la ubicación precisa de EntrenaOP en Ajustes.',
      'disabled' => 'Activa la ubicación del móvil y vuelve a intentarlo.',
      'no_signal' => 'No se ha encontrado señal GPS. Sal a una zona abierta y vuelve a intentarlo.',
      _ => 'La grabación se ha interrumpido. Puedes reintentar o registrar el rodaje manualmente.',
    };
    _show(state.phase);
  }

  Future<void> review() async {
    await pause();
    _show(PhoneRunPhase.review);
  }

  Future<void> clearCheckpoint() => _checkpoints.clear(executionId);

  void _show(PhoneRunPhase phase) {
    if (_closing) return;
    final now = _now();
    final step = _step;
    final totals = _track.totalsAt(now);
    final results = {for (final item in _steps) item.id: item};
    emit(
      PhoneRunState(
        phase,
        totals: totals,
        signalLost: _track.signalLostAt(now),
        message: _message,
        step: step,
        nextStep: _stepIndex + 1 < _steps.length
            ? _steps[_stepIndex + 1]
            : null,
        stepNumber: _stepIndex + 1,
        stepCount: _steps.length,
        recentPace: step?.passive == true ? null : _track.recentPaceAt(now),
        sessionDistanceMeters: _laps.fold(
          step?.passive == true ? 0.0 : totals.distanceMeters,
          (sum, lap) =>
              sum +
              (results[lap.stepId]?.passive == true
                  ? 0
                  : lap.totals.distanceMeters),
        ),
        trackMode: _trackMode,
        voice: _voice,
        paceAlerts: _paceAlerts,
      ),
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    _silence();
    await pause();
    await _subscription?.cancel();
    await super.close();
  }
}
