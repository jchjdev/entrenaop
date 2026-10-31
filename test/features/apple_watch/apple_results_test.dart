import 'dart:async';

import 'package:entrenaop/features/apple_watch/domain/apple_results.dart';
import 'package:entrenaop/features/apple_watch/domain/apple_training.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/apple_watch/presentation/apple_results_coordinator.dart';

final plan = ApplePlan(
  ApplePrescription('Carrera', '2026-10-31', []),
  'revision',
  'plan',
  null,
);
final observation = AppleResultObservation(
  workoutId: 'workout',
  planId: 'plan',
  revision: 'revision',
  matchesPrescription: true,
  startedAt: DateTime.utc(2026, 10, 31, 10),
  endedAt: DateTime.utc(2026, 10, 31, 10, 2),
  seconds: 120,
);

class Repository implements AppleResultsRepository {
  @override
  bool isCurrent = true;
  bool enabled = true;
  int saves = 0;
  Future<void> Function(bool)? onEnable;
  final batches = <int>[];
  @override
  Future<AppleResultCatalog> load() async =>
      AppleResultCatalog(enabled, [plan], []);
  @override
  Future<void> enable(bool value) async {
    await onEnable?.call(value);
    enabled = value;
  }

  @override
  Future<void> ingest(List<AppleResultObservation> observations) async {
    saves++;
    batches.add(observations.length);
  }

  @override
  Future<void> classify(String id, bool isTest) async {}
}

class Reader implements AppleResultsReader {
  @override
  bool supported = true;
  int reads = 0;
  Future<List<AppleResultObservation>> Function()? action;
  @override
  Future<void> authorize() async {}
  @override
  Future<List<AppleResultObservation>> read(List<ApplePlan> plans) async {
    reads++;
    return action == null ? [observation] : await action!();
  }
}

void main() {
  testWidgets(
    'Los cambios de consentimiento se serializan para que un encendido tardío no anule el apagado',
    (tester) async {
      final repository = Repository();
      final reader = Reader();
      final pending = Completer<void>();
      final writes = <bool>[];
      repository.onEnable = (value) async {
        writes.add(value);
        await pending.future;
      };
      final coordinator = AppleResultsCoordinator((_) => repository, reader);
      try {
        coordinator.setAccount('owner');
        await tester.pump();
        final disabling = coordinator.enable(false);
        await coordinator.enable(true);
        expect(writes, [false]);
        pending.complete();
        await disabling;
        expect(coordinator.catalog!.enabled, isFalse);
        expect(coordinator.configuring, isFalse);
      } finally {
        coordinator.dispose();
      }
    },
  );
  testWidgets(
    'Un fallo inicial conserva el reintento automático sin exigir otro botón',
    (tester) async {
      final repository = Repository();
      final reader = Reader();
      reader.action = () async {
        if (reader.reads == 1) {
          throw const AppleTrainingFailure('connection_busy');
        }
        return [observation];
      };
      final coordinator = AppleResultsCoordinator((_) => repository, reader);
      try {
        coordinator.setAccount('owner');
        await tester.pump();
        expect(coordinator.error, isNotNull);
        await tester.pump(const Duration(minutes: 1));
        await tester.pump();
        expect(reader.reads, 2);
        expect(repository.saves, 1);
        expect(coordinator.error, isNull);
      } finally {
        coordinator.dispose();
      }
    },
  );
  test('Desactivado no consulta Salud ni sube actividades', () async {
    final repository = Repository()..enabled = false;
    final reader = Reader();
    await SyncAppleResults(repository, reader)();
    expect(reader.reads, 0);
    expect(repository.saves, 0);
  });
  test(
    'Un cambio de cuenta durante HealthKit impide subir la respuesta tardía',
    () async {
      final repository = Repository();
      final reader = Reader()
        ..action = () async {
          repository.isCurrent = false;
          return [observation];
        };
      await expectLater(
        SyncAppleResults(repository, reader)(),
        throwsA(isA<AppleTrainingFailure>()),
      );
      expect(repository.saves, 0);
    },
  );
  test(
    'Cerrar el ámbito invalida la lectura aunque siga llegando del reloj',
    () async {
      final repository = Repository();
      final pending = Completer<List<AppleResultObservation>>();
      final reader = Reader()..action = () => pending.future;
      final sync = SyncAppleResults(repository, reader);
      final result = sync();
      await Future<void>.delayed(Duration.zero);
      sync.dispose();
      final expectation = expectLater(
        result,
        throwsA(isA<AppleTrainingFailure>()),
      );
      pending.complete([observation]);
      await expectation;
      expect(repository.saves, 0);
    },
  );
  test('Reanudar mientras ya hay lectura no inicia otro recorrido', () async {
    final repository = Repository();
    final pending = Completer<List<AppleResultObservation>>();
    final reader = Reader()..action = () => pending.future;
    final sync = SyncAppleResults(repository, reader);
    final first = sync();
    await Future<void>.delayed(Duration.zero);
    expect(await sync(), isNull);
    expect(reader.reads, 1);
    pending.complete([observation]);
    await first;
    expect(repository.saves, 1);
  });
  test(
    'Una lectura vacía no se transforma en borrado ni en resultados inventados',
    () async {
      final repository = Repository();
      final reader = Reader()..action = () async => [];
      await SyncAppleResults(repository, reader)();
      expect(repository.saves, 0);
    },
  );
  test('Las subidas se acotan sin perder la última actividad', () async {
    final repository = Repository();
    final reader = Reader()..action = () async => List.filled(41, observation);
    await SyncAppleResults(repository, reader)();
    expect(repository.batches, [20, 20, 1]);
  });
}
