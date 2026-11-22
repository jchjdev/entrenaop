import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/phone_running.dart';

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
  });

  final PhoneRunPhase phase;
  final PhoneRunTotals totals;
  final bool signalLost;
  final String? message;

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
  }) : _location = location,
       _checkpoints = checkpoints,
       _now = now,
       super(const PhoneRunState(PhoneRunPhase.loading));

  final String executionId;
  final PhoneRunLocationSource _location;
  final PhoneRunCheckpoints _checkpoints;
  final DateTime Function() _now;
  PhoneRunTrack _track = PhoneRunTrack();
  StreamSubscription<PhoneRunLocationEvent>? _subscription;
  Timer? _clock;
  DateTime? _acquiringSince, _lastCheckpoint;
  String? _token, _message;
  Future<void>? _stopping;
  bool _closing = false;

  Future<void> open() async {
    try {
      final saved = await _checkpoints.read(executionId);
      if (_closing || state.phase != PhoneRunPhase.loading) return;
      if (saved == null) {
        _show(PhoneRunPhase.idle);
        await start();
        return;
      }
      _track = PhoneRunTrack(
        PhoneRunTotals(
          elapsedMilliseconds: saved.totals.elapsedMilliseconds,
          distanceMeters: saved.totals.distanceMeters,
          distanceReliable: saved.totals.distanceReliable && !saved.recording,
        ),
      );
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
    if (_token != null || _stopping != null || _closing) return;
    _subscription ??= _location.locations.listen(
      _onLocation,
      onError: (Object _) => unawaited(_interrupt('interrupted')),
    );
    final token = const Uuid().v4();
    _token = token;
    _message = null;
    _show(PhoneRunPhase.acquiring);
    try {
      await _location.start(token);
      if (_token != token) return;
      _acquiringSince = _now();
      _lastCheckpoint = null;
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
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
    if (_token == null) return;
    final now = _now();
    if (!_track.hasFix) {
      if (now.difference(_acquiringSince!) >= const Duration(seconds: 60)) {
        unawaited(_interrupt('no_signal'));
      }
      return;
    }
    final totals = _track.totalsAt(now);
    _show(PhoneRunPhase.recording);
    final last = _lastCheckpoint;
    if (last == null || now.difference(last) >= const Duration(seconds: 5)) {
      _lastCheckpoint = now;
      unawaited(_checkpoint(totals, recording: true));
    }
  }

  Future<void> _checkpoint(
    PhoneRunTotals totals, {
    required bool recording,
  }) async {
    try {
      await _checkpoints.write(
        executionId,
        PhoneRunCheckpoint(totals, recording: recording),
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
    if (totals.elapsedMilliseconds > 0) {
      await _checkpoint(totals, recording: false);
    }
    _show(totals.seconds > 0 ? PhoneRunPhase.paused : PhoneRunPhase.idle);
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
    emit(
      PhoneRunState(
        phase,
        totals: _track.totalsAt(now),
        signalLost: _track.signalLostAt(now),
        message: _message,
      ),
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    await pause();
    await _subscription?.cancel();
    await super.close();
  }
}
