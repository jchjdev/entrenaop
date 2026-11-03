import 'dart:async';

import 'package:entrenaop/features/apple_watch/domain/apple_training.dart';
import 'package:entrenaop/features/apple_watch/domain/sync_apple_training.dart';
import 'package:entrenaop/features/apple_watch/presentation/apple_training_coordinator.dart';
import 'package:entrenaop/features/apple_watch/data/apple_training_sync_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/features/apple_watch/presentation/apple_watch_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apple_training_test.dart' as fixture;

ApplePlan prescription(String revision, {String date = '2026-11-03'}) =>
    ApplePlan(
      ApplePrescription('Series', date, fixture.plan.prescription.steps),
      revision,
      null,
      null,
    );

AppleReceipt receipt(
  String id, {
  String revision = 'v1',
  String status = 'submitted',
  bool removal = false,
  bool started = false,
  String date = '2026-11-03',
}) => AppleReceipt(
  id,
  'Series',
  date,
  revision,
  status,
  removal,
  started,
  planId: 'plan-$id',
);

class Repository extends fixture.Repo {
  bool allowed = true;
  List<AppleCandidate> candidates = const [
    AppleCandidate('a', 'Series', '2026-11-03'),
  ];
  List<AppleReceipt> receipts = [];
  Map<String, ApplePlan> plans = {'a': prescription('v1')};
  Map<String, String> previewErrors = {};
  int loads = 0;
  @override
  Future<AppleCatalog> load() async {
    loads++;
    return AppleCatalog(allowed, candidates, List.of(receipts));
  }

  @override
  Future<ApplePlan> preview(String id) async {
    if (previewErrors[id] case final code?) throw AppleTrainingFailure(code);
    return plans[id]!;
  }

  @override
  Future<ApplePlan> prepare(String id, String revision) async {
    calls.add('prepare:$id');
    await preparing?.call();
    final preview = plans[id]!;
    return ApplePlan(preview.prescription, revision, 'plan-$id', 'attempt');
  }

  @override
  Future<void> record(String id, ApplePlan plan) async {
    calls.add('record:$id');
    receipts = [
      ...receipts.where((row) => row.id != id),
      receipt(id, revision: plan.revision, date: plan.prescription.date),
    ];
  }

  @override
  Future<AppleRemoval> removal(String id) async {
    calls.add('removal:$id');
    return AppleRemoval('plan-$id', 'v1', 'attempt');
  }

  @override
  Future<void> removed(String id, AppleRemoval removal) async {
    calls.add('removed:$id');
    receipts = [
      ...receipts.where((row) => row.id != id),
      receipt(id, status: 'removed'),
    ];
  }
}

class Scheduler extends fixture.Native {
  Map<String, AppleScheduledState> local = {};
  final inspections = <String>[];
  final failing = <String>{};
  @override
  Future<AppleScheduledState> inspect(String owner, ApplePlan plan) async {
    inspections.add(plan.planId!);
    return local[plan.planId] ?? AppleScheduledState.missing;
  }

  @override
  Future<void> schedule(String owner, ApplePlan plan) async {
    calls.add('schedule:${plan.planId}');
    await scheduling?.call();
    if (failing.contains(plan.planId)) {
      throw const AppleTrainingFailure('unsupported_prescription');
    }
    local[plan.planId!] = AppleScheduledState.matching;
  }
}

class Preference implements AppleTrainingSyncPreference {
  final values = <String, bool>{};
  @override
  Future<bool> enabled(String owner) async => values[owner] ?? false;
  @override
  Future<void> setEnabled(String owner, bool value) async {
    values[owner] = value;
  }
}

Future<AppleTrainingSyncReport> reconcile(
  Repository repo,
  Scheduler scheduler, {
  bool Function()? active,
}) => SyncAppleTraining(
  AppleTrainingService(repo, scheduler),
  now: () => DateTime(2026, 11, 3),
)(active ?? () => true);

void main() {
  testWidgets(
    'El interruptor de agenda activa el envío sin activar lectura de Salud',
    (tester) async {
      final repo = Repository(),
          scheduler = Scheduler(),
          preferences = Preference();
      final service = AppleTrainingService(repo, scheduler);
      final coordinator = AppleTrainingCoordinator(
        (_) => service,
        preferences,
        supported: true,
      );
      coordinator.setAccount('owner');
      await tester.pumpWidget(
        MaterialApp(
          home: AppleWatchPage(
            service: service,
            training: coordinator,
            onOpenHealth: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scheduler.calls, isEmpty);
      await tester.tap(find.text('Sincronizar agenda automáticamente'));
      await tester.pumpAndSettle();
      expect(coordinator.enabled, isTrue);
      expect(scheduler.calls, ['schedule:plan-a']);
      expect(find.text('Recibir resultados automáticamente'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      coordinator.dispose();
    },
  );

  test(
    'La sesión nueva de hoy se programa y se confirma después del nativo',
    () async {
      final repo = Repository(), scheduler = Scheduler();
      final result = await reconcile(repo, scheduler);
      expect(scheduler.calls, ['schedule:plan-a']);
      expect(repo.calls, ['prepare:a', 'record:a']);
      expect(result.catalog.receipts.single.status, 'submitted');
      expect(result.failures, isEmpty);
      await reconcile(repo, scheduler);
      expect(scheduler.calls.length, 1);
    },
  );

  test(
    'El ACK del servidor no oculta una pauta ausente en este iPhone',
    () async {
      final repo = Repository()..receipts = [receipt('a')];
      final scheduler = Scheduler();
      await reconcile(repo, scheduler);
      expect(scheduler.calls, ['schedule:plan-a']);
      expect(scheduler.inspections, ['plan-a']);
    },
  );

  test(
    'La revisión nueva actualiza la referencia existente sin otra copia',
    () async {
      final repo = Repository()
        ..receipts = [receipt('a')]
        ..plans['a'] = prescription('v2', date: '2026-11-04');
      final scheduler = Scheduler()
        ..local['plan-a'] = AppleScheduledState.changed;
      await reconcile(repo, scheduler);
      expect(scheduler.calls, ['schedule:plan-a']);
      expect(repo.receipts.single.revision, 'v2');
      expect(repo.receipts.single.date, '2026-11-04');
    },
  );

  test(
    'Una cancelación se retira incluso si el derecho comercial ha vencido',
    () async {
      final repo = Repository()
        ..allowed = false
        ..candidates = []
        ..receipts = [receipt('a', removal: true)];
      final scheduler = Scheduler();
      await reconcile(repo, scheduler);
      expect(scheduler.calls, ['remove:owner:plan-a']);
      expect(repo.calls, ['removal:a', 'removed:a']);
    },
  );

  test(
    'Una fecha fuera de ventana retira la cita antigua sin borrar historial',
    () async {
      final repo = Repository()
        ..candidates = []
        ..receipts = [receipt('a')]
        ..previewErrors['a'] = 'date_outside_window';
      final scheduler = Scheduler();
      await reconcile(repo, scheduler);
      expect(scheduler.calls, ['remove:owner:plan-a']);
    },
  );

  test(
    'Ausencia en una lista limitada no se interpreta como cancelación',
    () async {
      final repo = Repository()
        ..candidates = []
        ..receipts = [receipt('a')];
      final scheduler = Scheduler()
        ..local['plan-a'] = AppleScheduledState.matching;
      await reconcile(repo, scheduler);
      expect(scheduler.calls, isEmpty);
    },
  );

  test(
    'Apple completado y una ejecución iniciada nunca se reprograman',
    () async {
      final repo = Repository()..receipts = [receipt('a')];
      final scheduler = Scheduler()
        ..local['plan-a'] = AppleScheduledState.completed;
      await reconcile(repo, scheduler);
      repo.receipts = [receipt('a', started: true)];
      await reconcile(repo, scheduler);
      expect(scheduler.calls, isEmpty);
    },
  );

  test('Sin autorización no se preparan ni escriben pautas', () async {
    final repo = Repository(),
        scheduler = Scheduler()..authorization = AppleAuthorization.denied;
    await expectLater(
      reconcile(repo, scheduler),
      throwsA(isA<AppleTrainingFailure>()),
    );
    expect(repo.loads, 0);
    expect(repo.calls, isEmpty);
    expect(scheduler.calls, isEmpty);
  });

  test('Sin derecho comercial no se crean pautas nuevas', () async {
    final repo = Repository()..allowed = false;
    final scheduler = Scheduler();
    await reconcile(repo, scheduler);
    expect(repo.calls, isEmpty);
    expect(scheduler.calls, isEmpty);
  });

  test(
    'Una receta incompatible no bloquea las demás ni confirma un falso éxito',
    () async {
      final repo = Repository()
        ..candidates = [
          const AppleCandidate('a', 'A', '2026-11-03'),
          const AppleCandidate('b', 'B', '2026-11-03'),
        ]
        ..plans['b'] = prescription('b');
      final scheduler = Scheduler()..failing.add('plan-a');
      final result = await reconcile(repo, scheduler);
      expect(result.failures, {'a': 'unsupported_prescription'});
      expect(repo.calls, ['prepare:a', 'prepare:b', 'record:b']);
    },
  );

  test('Desactivar durante la preparación impide tocar WorkoutKit', () async {
    final repo = Repository(), scheduler = Scheduler();
    var active = true;
    repo.preparing = () async {
      active = false;
    };
    await expectLater(
      reconcile(repo, scheduler, active: () => active),
      throwsA(isA<AppleTrainingFailure>()),
    );
    expect(repo.calls, ['prepare:a']);
    expect(scheduler.calls, isEmpty);
  });

  test('Una cuenta que cambia durante el nativo no recibe el ACK', () async {
    final repo = Repository(), scheduler = Scheduler();
    scheduler.scheduling = () async {
      repo.current = false;
    };
    await expectLater(
      reconcile(repo, scheduler),
      throwsA(isA<AppleTrainingFailure>()),
    );
    expect(repo.calls, ['prepare:a']);
  });

  testWidgets(
    'El arranque no programa sin activar y al activarlo concilia sin abrir Apple',
    (tester) async {
      final repo = Repository(),
          scheduler = Scheduler(),
          preference = Preference();
      final coordinator = AppleTrainingCoordinator(
        (_) => AppleTrainingService(repo, scheduler),
        preference,
        supported: true,
      );
      coordinator.setAccount('owner');
      await tester.pump();
      expect(scheduler.calls, isEmpty);
      await coordinator.enable(true);
      expect(scheduler.calls, ['schedule:plan-a']);
      expect(preference.values, {'owner': true});
      coordinator.dispose();
    },
  );

  testWidgets(
    'Volver a primer plano recoge una cita nueva sin entrar en Perfil',
    (tester) async {
      final repo = Repository(),
          scheduler = Scheduler(),
          preference = Preference()..values['owner'] = true;
      final coordinator = AppleTrainingCoordinator(
        (_) => AppleTrainingService(repo, scheduler),
        preference,
        supported: true,
      );
      coordinator.setAccount('owner');
      await tester.pump();
      coordinator.foreground(false);
      repo.candidates = [const AppleCandidate('b', 'B', '2026-11-03')];
      repo.plans['b'] = prescription('v1');
      coordinator.foreground(true);
      await tester.pump();
      expect(scheduler.calls, ['schedule:plan-a', 'schedule:plan-b']);
      coordinator.dispose();
    },
  );

  testWidgets(
    'Dos comprobaciones simultáneas comparten operación y no duplican envío',
    (tester) async {
      final repo = Repository(),
          scheduler = Scheduler(),
          preference = Preference()..values['owner'] = true;
      final gate = Completer<void>();
      repo.preparing = () => gate.future;
      final coordinator = AppleTrainingCoordinator(
        (_) => AppleTrainingService(repo, scheduler),
        preference,
        supported: true,
      );
      coordinator.setAccount('owner');
      await tester.pump();
      final first = coordinator.refresh(), second = coordinator.refresh();
      expect(identical(first, second), isTrue);
      gate.complete();
      await first;
      expect(scheduler.calls, ['schedule:plan-a']);
      coordinator.dispose();
    },
  );

  testWidgets('Salir de la cuenta durante la preparación cancela el envío', (
    tester,
  ) async {
    final repo = Repository(),
        scheduler = Scheduler(),
        preference = Preference()..values['owner'] = true;
    final gate = Completer<void>();
    repo.preparing = () => gate.future;
    final coordinator = AppleTrainingCoordinator(
      (_) => AppleTrainingService(repo, scheduler),
      preference,
      supported: true,
    );
    coordinator.setAccount('owner');
    await tester.pump();
    final pending = coordinator.refresh();
    coordinator.setAccount(null);
    gate.complete();
    await pending;
    expect(coordinator.enabled, isFalse);
    expect(coordinator.catalog, isNull);
    expect(scheduler.calls, isEmpty);
    coordinator.dispose();
  });

  test(
    'La preferencia local no activa otra cuenta ni concede permisos',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = LocalAppleTrainingSyncPreference();
      await preferences.setEnabled('a', true);
      expect(await preferences.enabled('a'), isTrue);
      expect(await preferences.enabled('b'), isFalse);
      await preferences.setEnabled('a', false);
      expect(await preferences.enabled('a'), isFalse);
    },
  );
}
