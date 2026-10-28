import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/features/apple_watch/presentation/apple_watch_page.dart';
import 'package:entrenaop/features/apple_watch/domain/apple_training.dart';

final plan = ApplePlan(
  ApplePrescription('Series', '2026-10-29', const [
    AppleStep('run', 'meters', 400, 'Carrera', 215, 220),
  ]),
  'revision',
  'plan',
  'attempt',
);

class Repo implements AppleTrainingRepository {
  bool current = true;
  final calls = <String>[];
  Future<void> Function()? preparing;
  @override
  String get ownerId => 'owner';
  @override
  bool get isCurrent => current;
  @override
  Future<AppleCatalog> load() async => const AppleCatalog(true, [], []);
  @override
  Future<ApplePlan> preview(String id) async => plan;
  @override
  Future<ApplePlan> prepare(String id, String revision) async {
    calls.add('prepare');
    await preparing?.call();
    return plan;
  }

  @override
  Future<void> record(String id, ApplePlan plan) async {
    calls.add('record');
  }

  @override
  Future<AppleRemoval> removal(String id) async {
    calls.add('removal');
    return const AppleRemoval('plan', 'revision', 'attempt');
  }

  @override
  Future<void> removed(String id, AppleRemoval removal) async {
    calls.add('removed');
  }
}

class Native implements AppleWorkoutScheduler {
  AppleAuthorization authorization = AppleAuthorization.authorized;
  Future<void> Function()? scheduling;
  final calls = <String>[];
  @override
  Future<AppleAuthorization> status() async => authorization;
  @override
  Future<AppleAuthorization> authorize() async => authorization;
  @override
  Future<void> schedule(String owner, ApplePlan p) async {
    calls.add('schedule:$owner');
    await scheduling?.call();
  }

  @override
  Future<void> remove(String owner, String id) async {
    calls.add('remove:$owner:$id');
  }
}

void main() {
  testWidgets('Abrir Apple no solicita permiso ni programa sesiones', (
    tester,
  ) async {
    final repo = Repo(),
        native = Native()..authorization = AppleAuthorization.notDetermined;
    await tester.pumpWidget(
      MaterialApp(
        home: AppleWatchPage(
          service: AppleTrainingService(repo, native),
          onOpenHealth: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Autorizar Apple Watch'), findsOneWidget);
    expect(native.calls, isEmpty);
    expect(repo.calls, isEmpty);
  });
  testWidgets('Un dispositivo incompatible conserva el acceso a Salud', (
    tester,
  ) async {
    final repo = Repo(),
        native = Native()..authorization = AppleAuthorization.unsupported;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppleWatchPage(
          service: AppleTrainingService(repo, native),
          onOpenHealth: () {
            opened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Este dispositivo no permite'), findsOneWidget);
    expect(find.text('Autorizar Apple Watch'), findsNothing);
    await tester.ensureVisible(find.text('Leer actividades de Salud'));
    await tester.tap(find.text('Leer actividades de Salud'));
    expect(opened, isTrue);
    expect(native.calls, isEmpty);
  });

  test('El ACK solo se registra después de la confirmación nativa', () async {
    final repo = Repo(), native = Native();
    final gate = Completer<void>();
    native.scheduling = () => gate.future;
    final sending = AppleTrainingService(repo, native).send('s', plan);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, ['prepare']);
    gate.complete();
    await sending;
    expect(repo.calls, ['prepare', 'record']);
    expect(native.calls, ['schedule:owner']);
  });
  test('Una sesión revocada durante la preparación no toca el reloj', () async {
    final repo = Repo(), native = Native();
    repo.preparing = () async {
      repo.current = false;
    };
    await expectLater(
      AppleTrainingService(repo, native).send('s', plan),
      throwsA(
        isA<AppleTrainingFailure>().having(
          (e) => e.code,
          'code',
          'account_changed',
        ),
      ),
    );
    expect(native.calls, isEmpty);
    expect(repo.calls, ['prepare']);
  });
  test(
    'El cambio de cuenta durante WorkoutKit no confirma en la cuenta nueva',
    () async {
      final repo = Repo(), native = Native();
      native.scheduling = () async {
        repo.current = false;
      };
      await expectLater(
        AppleTrainingService(repo, native).send('s', plan),
        throwsA(isA<AppleTrainingFailure>()),
      );
      expect(repo.calls, ['prepare']);
    },
  );
  test('Permiso denegado no prepara entregas', () async {
    final repo = Repo(),
        native = Native()..authorization = AppleAuthorization.denied;
    await expectLater(
      AppleTrainingService(repo, native).send('s', plan),
      throwsA(
        isA<AppleTrainingFailure>().having(
          (e) => e.code,
          'code',
          'permission_required',
        ),
      ),
    );
    expect(repo.calls, isEmpty);
    expect(native.calls, isEmpty);
  });
  test('Un fallo nativo no se convierte en enviado', () async {
    final repo = Repo(), native = Native();
    native.scheduling = () async {
      throw const AppleTrainingFailure('unsupported_prescription');
    };
    await expectLater(
      AppleTrainingService(repo, native).send('s', plan),
      throwsA(isA<AppleTrainingFailure>()),
    );
    expect(repo.calls, ['prepare']);
  });
  test('Doble toque no produce dos envíos', () async {
    final repo = Repo(), native = Native();
    final gate = Completer<void>();
    repo.preparing = () => gate.future;
    final service = AppleTrainingService(repo, native);
    final first = service.send('s', plan);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      service.send('s', plan),
      throwsA(
        isA<AppleTrainingFailure>().having(
          (e) => e.code,
          'code',
          'connection_busy',
        ),
      ),
    );
    gate.complete();
    await first;
    expect(native.calls.length, 1);
  });
  test(
    'Retirar utiliza solo el identificador del servidor y confirma después',
    () async {
      final repo = Repo(), native = Native();
      await AppleTrainingService(repo, native).withdraw('s');
      expect(native.calls, ['remove:owner:plan']);
      expect(repo.calls, ['removal', 'removed']);
    },
  );
}
