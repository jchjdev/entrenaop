import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_read_probe/domain/local_running_health.dart';
import 'package:health_read_probe/main.dart';
import 'package:health_read_probe/presentation/health_probe_cubit.dart';

final class FakeHealth implements LocalRunningHealth {
  @override
  LocalHealthPlatform get platform => LocalHealthPlatform.appleHealth;
  HealthStoreAvailability status = HealthStoreAvailability.available;
  HealthReadConsent consent = HealthReadConsent.queryAllowedUnknown;
  Future<LocalHealthRead> Function()? onRead;
  Future<HealthReadConsent> Function()? onConsent;
  int checks = 0, requests = 0, reads = 0;
  HealthReadWindow? window;
  final scopes = <String>[];
  @override
  Future<HealthStoreAvailability> availability() async {
    checks++;
    return status;
  }

  @override
  Future<HealthReadConsent> requestReadAccess() async {
    requests++;
    return onConsent == null ? consent : await onConsent!();
  }

  @override
  Future<LocalHealthRead> read({
    required HealthReadWindow window,
    required String localSessionScope,
  }) async {
    reads++;
    this.window = window;
    scopes.add(localSessionScope);
    return onRead == null ? empty() : await onRead!();
  }
}

LocalHealthRead empty() =>
    LocalHealthRead(activities: [], rejectedRecords: 0, truncated: false);

void main() {
  late FakeHealth source;
  late HealthProbeCubit cubit;
  final now = DateTime.utc(2026, 10, 21, 12);
  setUp(() {
    source = FakeHealth();
    cubit = HealthProbeCubit(source, nowUtc: () => now);
  });
  tearDown(() => cubit.close());
  Future<void> prepare() async {
    await cubit.check();
    await cubit.authorize();
  }

  test('opening and authorizing never read automatically; unknown Apple grant permits a query', () async {
    expect(source.checks + source.requests + source.reads, 0);
    await cubit.read();
    expect(source.reads, 0);
    await prepare();
    expect(source.reads, 0);
    expect(cubit.state.consent, HealthReadConsent.queryAllowedUnknown);
    await cubit.read();
    expect(cubit.state.phase, HealthProbePhase.result);
    expect(cubit.state.read!.activities, isEmpty);
    expect(source.window!.endUtc, now);
    expect(source.window!.startUtc, now.subtract(const Duration(days: 7)));
  });
  test('denied and unavailable block read requests', () async {
    source.status = HealthStoreAvailability.updateRequired;
    await prepare();
    await cubit.read();
    expect(source.requests, 0);
    expect(source.reads, 0);
    source.status = HealthStoreAvailability.available;
    source.consent = HealthReadConsent.denied;
    await prepare();
    await cubit.read();
    expect(source.reads, 0);
  });
  test('busy guards prevent simultaneous operations', () async {
    await prepare();
    final pending = Completer<LocalHealthRead>();
    source.onRead = () => pending.future;
    final operation = cubit.read();
    await cubit.read();
    await cubit.check();
    await cubit.authorize();
    expect(source.reads, 1);
    expect(source.checks, 1);
    pending.complete(empty());
    await operation;
  });
  test(
    'clearing invalidates late replies and rotates identity scope',
    () async {
      await prepare();
      final pending = Completer<LocalHealthRead>();
      source.onRead = () => pending.future;
      final operation = cubit.read();
      cubit.clear();
      pending.complete(empty());
      await operation;
      expect(cubit.state.phase, HealthProbePhase.idle);
      expect(cubit.state.read, isNull);
      source.onRead = null;
      await prepare();
      await cubit.read();
      expect(source.scopes[0], isNot(source.scopes[1]));
    },
  );
  test('background clears results and consent', () async {
    await prepare();
    await cubit.read();
    cubit.suspend();
    expect(cubit.state.read, isNull);
    expect(cubit.state.consent, isNull);
    await cubit.read();
    expect(source.reads, 1);
  });

  test('background invalidates an in-flight read', () async {
    await prepare();
    final pending = Completer<LocalHealthRead>();
    source.onRead = () => pending.future;
    final operation = cubit.read();
    cubit.suspend();
    pending.complete(empty());
    await operation;
    expect(cubit.state.phase, HealthProbePhase.idle);
    expect(cubit.state.read, isNull);
  });

  test(
    'system permission dialog can pause without triggering a read',
    () async {
      await cubit.check();
      final pending = Completer<HealthReadConsent>();
      source.onConsent = () => pending.future;
      final operation = cubit.authorize();
      cubit.suspend();
      expect(cubit.state.phase, HealthProbePhase.authorizing);
      pending.complete(HealthReadConsent.queryAllowedUnknown);
      await operation;
      expect(cubit.state.consent, HealthReadConsent.queryAllowedUnknown);
      expect(source.reads, 0);
    },
  );
  test('revocation clears previous result and consent', () async {
    await prepare();
    await cubit.read();
    source.onRead = () async =>
        throw const HealthProbeException(HealthProbeProblem.permissionRequired);
    await cubit.read();
    expect(cubit.state.phase, HealthProbePhase.failed);
    expect(cubit.state.problem, HealthProbeProblem.permissionRequired);
    expect(cubit.state.read, isNull);
    expect(cubit.state.consent, isNull);
  });
  test('closed cubit ignores in-flight responses', () async {
    await prepare();
    final pending = Completer<LocalHealthRead>();
    source.onRead = () => pending.future;
    final operation = cubit.read();
    await cubit.close();
    pending.complete(empty());
    await operation;
    expect(cubit.isClosed, isTrue);
  });
  testWidgets(
    'explicit flow fits a small screen with large text and clears on background',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(HealthProbeApp(source: source));
      expect(source.reads, 0);
      Future<void> press(String text) async {
        final target = find.text(text);
        await tester.scrollUntilVisible(target, 160, maxScrolls: 40);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await press('1. Comprobar disponibilidad');
      await press('2. Solicitar lectura de entrenamientos');
      expect(find.textContaining('Apple no revela'), findsOneWidget);
      await press('3. Leer carreras de los últimos 7 días');
      await tester.scrollUntilVisible(find.text('Carreras legibles: 0'), 160);
      expect(find.text('Carreras legibles: 0'), findsOneWidget);
      expect(source.reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(find.text('Carreras legibles: 0'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(source.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
