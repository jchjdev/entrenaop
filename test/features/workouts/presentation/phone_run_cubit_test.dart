import 'dart:async';

import 'package:entrenaop/features/workouts/domain/services/phone_running.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/phone_run_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pausar y terminar liberan la ubicación y conservan los datos',
    () async {
      final location = _Location();
      final checkpoints = _Checkpoints();
      var now = DateTime.utc(2026, 11, 22, 9);
      final cubit = PhoneRunCubit(
        executionId: 'rodaje',
        location: location,
        checkpoints: checkpoints,
        now: () => now,
      );
      addTearDown(location.events.close);
      addTearDown(cubit.close);

      await cubit.open();
      expect(cubit.state.phase, PhoneRunPhase.acquiring);
      location.fix(now, 0);
      now = now.add(const Duration(seconds: 1));
      location.fix(now, .00004);
      final firstToken = location.starts.single;
      await cubit.pause();
      expect(location.stops, [firstToken]);
      expect(checkpoints.saved?.recording, isFalse);
      expect(cubit.state.phase, PhoneRunPhase.paused);

      now = now.add(const Duration(minutes: 1));
      await cubit.start();
      location.fix(now, 1);
      now = now.add(const Duration(seconds: 1));
      location.fix(now, 1.00004);
      await cubit.review();
      expect(location.stops, location.starts);
      expect(cubit.state.phase, PhoneRunPhase.review);
      expect(cubit.state.totals.seconds, 2);
      expect(cubit.state.totals.distanceMeters, closeTo(9, 1));
      expect(checkpoints.saved?.recording, isFalse);
    },
  );

  test(
    'una grabación interrumpida se recupera pausada sin reactivar el GPS',
    () async {
      final location = _Location();
      final checkpoints = _Checkpoints()
        ..saved = const PhoneRunCheckpoint(
          PhoneRunTotals(elapsedMilliseconds: 40000, distanceMeters: 90),
          recording: true,
        );
      final cubit = PhoneRunCubit(
        executionId: 'rodaje',
        location: location,
        checkpoints: checkpoints,
      );
      addTearDown(location.events.close);
      addTearDown(cubit.close);

      await cubit.open();
      expect(cubit.state.phase, PhoneRunPhase.paused);
      expect(cubit.state.totals.seconds, 40);
      expect(cubit.state.totals.distanceReliable, isFalse);
      expect(location.starts, isEmpty);
    },
  );

  test(
    'salir mientras se solicita permiso detiene el inicio pendiente',
    () async {
      final permission = Completer<void>();
      final location = _Location()..permission = permission.future;
      final cubit = PhoneRunCubit(
        executionId: 'rodaje',
        location: location,
        checkpoints: _Checkpoints(),
      );
      addTearDown(location.events.close);
      addTearDown(cubit.close);
      final opening = cubit.open();
      await Future<void>.delayed(Duration.zero);
      expect(location.starts, hasLength(1));
      await cubit.pause();
      permission.complete();
      await opening;
      expect(location.stops, location.starts);
      expect(cubit.state.phase, PhoneRunPhase.idle);
    },
  );
}

class _Location implements PhoneRunLocationSource {
  final events = StreamController<PhoneRunLocationEvent>.broadcast(sync: true);
  final starts = <String>[];
  final stops = <String>[];
  Future<void>? permission;

  @override
  Stream<PhoneRunLocationEvent> get locations => events.stream;

  @override
  Future<void> start(String token) async {
    starts.add(token);
    await permission;
  }

  @override
  Future<void> stop(String token) async => stops.add(token);

  void fix(DateTime at, double longitude) => events.add(
    PhoneRunLocationEvent(
      starts.last,
      fix: PhoneRunFix(
        latitude: 0,
        longitude: longitude,
        accuracyMeters: 5,
        at: at,
      ),
    ),
  );
}

class _Checkpoints implements PhoneRunCheckpoints {
  PhoneRunCheckpoint? saved;

  @override
  Future<PhoneRunCheckpoint?> read(String executionId) async => saved;

  @override
  Future<void> write(String executionId, PhoneRunCheckpoint value) async {
    saved = value;
  }

  @override
  Future<void> clear(String executionId) async => saved = null;
}
