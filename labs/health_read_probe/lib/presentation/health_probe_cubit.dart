import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/local_running_health.dart';

enum HealthProbePhase {
  idle,
  checking,
  ready,
  authorizing,
  reading,
  result,
  failed,
}

final class HealthProbeState {
  const HealthProbeState({
    this.phase = HealthProbePhase.idle,
    this.availability,
    this.consent,
    this.read,
    this.problem,
  });

  final HealthProbePhase phase;
  final HealthStoreAvailability? availability;
  final HealthReadConsent? consent;
  final LocalHealthRead? read;
  final HealthProbeProblem? problem;

  bool get busy => const {
    HealthProbePhase.checking,
    HealthProbePhase.authorizing,
    HealthProbePhase.reading,
  }.contains(phase);
}

final class HealthProbeCubit extends Cubit<HealthProbeState> {
  HealthProbeCubit(this.source, {DateTime Function()? nowUtc})
    : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
      super(const HealthProbeState());

  final LocalRunningHealth source;
  final DateTime Function() _nowUtc;
  int _generation = 0;
  String _sessionScope = _newScope();

  Future<void> check() async {
    if (state.busy) return;
    final generation = ++_generation;
    emit(const HealthProbeState(phase: HealthProbePhase.checking));
    try {
      final availability = await source.availability();
      if (_active(generation)) {
        emit(
          HealthProbeState(
            phase: HealthProbePhase.ready,
            availability: availability,
          ),
        );
      }
    } catch (_) {
      _fail(generation, HealthProbeProblem.unavailable);
    }
  }

  Future<void> authorize() async {
    if (state.busy || state.availability != HealthStoreAvailability.available) {
      return;
    }
    final generation = ++_generation;
    emit(
      const HealthProbeState(
        phase: HealthProbePhase.authorizing,
        availability: HealthStoreAvailability.available,
      ),
    );
    try {
      final consent = await source.requestReadAccess();
      if (_active(generation)) {
        emit(
          HealthProbeState(
            phase: HealthProbePhase.ready,
            availability: HealthStoreAvailability.available,
            consent: consent,
          ),
        );
      }
    } catch (error) {
      _fail(
        generation,
        error is HealthProbeException
            ? error.problem
            : HealthProbeProblem.readFailed,
      );
    }
  }

  Future<void> read() async {
    if (state.busy ||
        state.availability != HealthStoreAvailability.available ||
        !const {
          HealthReadConsent.granted,
          HealthReadConsent.queryAllowedUnknown,
        }.contains(state.consent)) {
      return;
    }
    final consent = state.consent;
    final generation = ++_generation;
    final end = _nowUtc();
    final scope = _sessionScope;
    emit(
      HealthProbeState(
        phase: HealthProbePhase.reading,
        availability: HealthStoreAvailability.available,
        consent: consent,
      ),
    );
    try {
      final result = await source.read(
        window: HealthReadWindow(
          startUtc: end.subtract(const Duration(days: 7)),
          endUtc: end,
        ),
        localSessionScope: scope,
      );
      if (_active(generation)) {
        emit(
          HealthProbeState(
            phase: HealthProbePhase.result,
            availability: HealthStoreAvailability.available,
            consent: consent,
            read: result,
          ),
        );
      }
    } catch (error) {
      _fail(
        generation,
        error is HealthProbeException
            ? error.problem
            : HealthProbeProblem.readFailed,
      );
    }
  }

  /// No revoca el permiso del sistema. Vacía memoria e invalida respuestas tardías.
  void clear() {
    _generation++;
    _sessionScope = _newScope();
    emit(const HealthProbeState());
  }

  void suspend() {
    // La pantalla de permisos puede pausar la app: no anulamos su propia solicitud.
    if (state.phase == HealthProbePhase.authorizing) return;
    clear();
  }

  bool _active(int generation) => !isClosed && generation == _generation;

  void _fail(int generation, HealthProbeProblem problem) {
    if (_active(generation)) {
      emit(HealthProbeState(phase: HealthProbePhase.failed, problem: problem));
    }
  }
}

String _newScope() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
