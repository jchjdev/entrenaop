import 'dart:async';

import 'package:device_health/device_health.dart';
import 'package:entrenaop/features/device_activities/domain/running_history.dart';
import 'package:entrenaop/features/device_activities/presentation/device_activities_cubit.dart';
import 'package:entrenaop/features/device_activities/presentation/device_activities_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'history_fixtures.dart';

final class FakeHealth implements LocalRunningHealth {
  @override
  LocalHealthPlatform get platform => LocalHealthPlatform.appleHealth;
  HealthReadConsent consent = HealthReadConsent.queryAllowedUnknown;
  int reads = 0, permissions = 0;
  Future<LocalHealthRead> Function()? onRead;
  Future<HealthReadConsent> Function()? onConsent;
  @override
  Future<HealthStoreAvailability> availability() async =>
      HealthStoreAvailability.available;
  @override
  Future<HealthReadConsent> requestReadAccess() async {
    permissions++;
    return onConsent == null ? consent : await onConsent!();
  }

  @override
  Future<LocalHealthRead> read({
    required HealthReadWindow window,
    required String localSessionScope,
  }) async {
    reads++;
    return onRead == null
        ? LocalHealthRead(
            activities: [activity()],
            rejectedRecords: 0,
            truncated: false,
          )
        : await onRead!();
  }
}

final class FakeHistory implements RunningHistoryRepository {
  FakeHistory([this.ownerId = ownerA]);
  @override
  final String ownerId;
  List<RunningHistoryItem> items = [];
  int generation = 0, saves = 0, clears = 0;
  final requests = <RunningSaveRequest>[];
  final clearIds = <String>[];
  Future<RunningSaveReceipt> Function(RunningSaveRequest)? onSave;
  Future<void> Function()? onClear;
  Future<RunningHistoryPage> Function(RunningHistoryCursor?)? onLoad;
  @override
  Future<RunningHistoryPage> load({RunningHistoryCursor? before}) async =>
      onLoad != null
      ? await onLoad!(before)
      : RunningHistoryPage(
          connection: connection(owner: ownerId, generation: generation),
          items: items,
        );
  @override
  Future<RunningSaveReceipt> save(
    RunningSaveRequest request,
    RunningOperationFence fence,
  ) async {
    fence.check();
    saves++;
    requests.add(request);
    if (onSave != null) return onSave!(request);
    final updated = items.isNotEmpty;
    items = [
      saved(
        run: request.selections.single.activity,
        hashCharacter: updated ? 'b' : 'a',
      ),
    ];
    return RunningSaveReceipt(
      inserted: updated ? 0 : 1,
      updated: updated ? 1 : 0,
      unchanged: 0,
    );
  }

  @override
  Future<void> clear({
    required RunningHistoryConnection connection,
    required String operationId,
    required RunningOperationFence fence,
  }) async {
    fence.check();
    clears++;
    clearIds.add(operationId);
    if (onClear != null) {
      await onClear!();
      return;
    }
    generation++;
    items = [];
  }
}

void main() {
  late FakeHealth health;
  late FakeHistory history;
  late DeviceActivitiesCubit cubit;
  setUp(() {
    health = FakeHealth();
    history = FakeHistory();
    cubit = DeviceActivitiesCubit(
      ownerId: ownerA,
      health: health,
      history: history,
      nowUtc: () => fixtureNow,
    );
  });
  tearDown(() => cubit.close());
  test('a changed identity across pages refreshes canonical history and discards stale selection', () async {
    final previous = saved();
    final incoming = saved(
      run: activity(revision: 'fixture-B'),
      hashCharacter: 'b',
    );
    final changed = RunningHistoryItem(
      id: '00000000-0000-0000-0000-000000000001',
      activity: incoming.activity,
      snapshotHash: incoming.snapshotHash,
      savedAtUtc: incoming.savedAtUtc,
    );
    var loads = 0;
    history.onLoad = (before) async {
      loads++;
      if (loads == 1) {
        expect(before, isNull);
        return RunningHistoryPage(
          connection: connection(),
          items: [previous],
          next: RunningHistoryCursor(
            startedAtUtc: previous.activity.startedAtUtc!,
            id: previous.id,
          ),
        );
      }
      expect(before != null, loads == 2);
      return RunningHistoryPage(connection: connection(), items: [changed]);
    };
    await cubit.initialize();
    health.onRead = () async => LocalHealthRead(
      activities: [activity(revision: 'fixture-C')],
      rejectedRecords: 0,
      truncated: false,
    );
    await cubit.read();
    cubit.select(cubit.state.preview.single.id, true);
    expect(cubit.state.selected, isNotEmpty);
    await cubit.loadMore();
    expect(loads, 3);
    expect(cubit.state.history.single.activity.revision.token, 'fixture-B');
    expect(cubit.state.preview, isEmpty);
    expect(cubit.state.selected, isEmpty);
    expect(history.saves, 0);
    expect(health.reads, 1);
  });
  test('opening only loads saved history; reading never uploads and saving survives a new page', () async {
    await cubit.initialize();
    expect(health.reads + health.permissions, 0);
    await cubit.read();
    expect(history.saves, 0);
    expect(cubit.state.selected.length, 1);
    await cubit.save();
    expect(history.saves, 1);
    expect(
      cubit.state.history.single.activity.identity.accountScope,
      connectionId,
    );
    final reopened = DeviceActivitiesCubit(
      ownerId: ownerA,
      health: health,
      history: history,
    );
    await reopened.initialize();
    expect(reopened.state.history.length, 1);
    expect(health.reads, 1);
    await reopened.close();
    await cubit.read();
    expect(cubit.state.preview.single.unchanged, isTrue);
    expect(cubit.state.selected, isEmpty);
    await cubit.save();
    expect(history.saves, 1);
  });
  test('changed opaque revision is unchecked until explicit review with expected head', () async {
    history.items = [saved()];
    await cubit.initialize();
    health.onRead = () async => LocalHealthRead(
      activities: [activity(revision: 'fixture-B', distance: 5200.5)],
      rejectedRecords: 0,
      truncated: false,
    );
    await cubit.read();
    expect(cubit.state.selected, isEmpty);
    await cubit.save();
    expect(history.saves, 0);
    cubit.select(cubit.state.preview.single.id, true);
    await cubit.save();
    expect(
      history.requests.single.selections.single.expectedSnapshotHash,
      'a' * 64,
    );
    expect(cubit.state.history.single.activity.revision.token, 'fixture-B');
  });
  test('empty and revoked local reads never erase persisted history', () async {
    history.items = [saved()];
    await cubit.initialize();
    health.consent = HealthReadConsent.denied;
    await cubit.read();
    expect(cubit.state.history.length, 1);
    expect(history.clears, 0);
    expect(health.reads, 0);
    health.consent = HealthReadConsent.queryAllowedUnknown;
    health.onRead = () async =>
        LocalHealthRead(activities: [], rejectedRecords: 0, truncated: false);
    await cubit.read();
    expect(cubit.state.history.length, 1);
    expect(history.clears, 0);
  });
  test('network uncertainty preserves identical request and replay reloads canonical newer head', () async {
    await cubit.initialize();
    await cubit.read();
    history.onSave = (request) async {
      if (history.saves == 1) {
        throw const RunningHistoryException(RunningHistoryProblem.unavailable);
      }
      return const RunningSaveReceipt(inserted: 1, updated: 0, unchanged: 0);
    };
    await cubit.save();
    expect(cubit.state.pendingSave, isTrue);
    history.items = [
      saved(
        run: activity(revision: 'fixture-B'),
        hashCharacter: 'b',
      ),
    ];
    await cubit.read();
    expect(health.reads, 1);
    await cubit.save();
    expect(identical(history.requests[0], history.requests[1]), isTrue);
    expect(cubit.state.history.single.activity.revision.token, 'fixture-B');
    expect(cubit.state.pendingSave, isFalse);
  });
  test(
    'logout discards a late permission reply before any health read',
    () async {
      await cubit.initialize();
      final pending = Completer<HealthReadConsent>();
      health.onConsent = () => pending.future;
      final read = cubit.read();
      await Future<void>.delayed(Duration.zero);
      cubit.deactivate();
      pending.complete(HealthReadConsent.queryAllowedUnknown);
      await read;
      expect(health.reads, 0);
      expect(cubit.state.preview, isEmpty);
      expect(cubit.state.history, isEmpty);
    },
  );
  test('background invalidates a late health query and resuming never queries automatically', () async {
    history.items = [saved()];
    await cubit.initialize();
    final pending = Completer<LocalHealthRead>();
    health.onRead = () => pending.future;
    final read = cubit.read();
    await Future<void>.delayed(Duration.zero);
    cubit.suspend();
    pending.complete(
      LocalHealthRead(
        activities: [activity()],
        rejectedRecords: 0,
        truncated: false,
      ),
    );
    await read;
    cubit.resume();
    expect(cubit.state.preview, isEmpty);
    expect(cubit.state.history.length, 1);
    expect(health.reads, 1);
  });
  test('a response authorized for A may commit to A after logout but never appears for B', () async {
    await cubit.initialize();
    await cubit.read();
    final pending = Completer<RunningSaveReceipt>();
    history.onSave = (r) => pending.future;
    final save = cubit.save();
    cubit.deactivate();
    history.items = [saved()];
    pending.complete(
      const RunningSaveReceipt(inserted: 1, updated: 0, unchanged: 0),
    );
    await save;
    expect(cubit.state.history, isEmpty);
    expect(cubit.state.preview, isEmpty);
    final accountB = DeviceActivitiesCubit(
      ownerId: ownerB,
      health: health,
      history: FakeHistory(ownerB),
    );
    await accountB.initialize();
    expect(accountB.state.history, isEmpty);
    await accountB.close();
  });
  test('uncertain clear retries the same operation and reloads later imports without deleting them', () async {
    history.items = [saved()];
    await cubit.initialize();
    history.onClear = () async {
      if (history.clears == 1) {
        history.items = [];
        history.generation++;
        throw const RunningHistoryException(RunningHistoryProblem.unavailable);
      }
    };
    await cubit.clearHistory();
    expect(cubit.state.pendingClear, isTrue);
    history.items = [
      saved(
        run: activity(revision: 'fixture-B'),
        hashCharacter: 'b',
        generation: 1,
      ),
    ];
    await cubit.clearHistory();
    expect(history.clearIds[0], history.clearIds[1]);
    expect(cubit.state.history.single.activity.revision.token, 'fixture-B');
  });
  testWidgets(
    'small screen large text shows readable fields and deleting requires explicit dialog',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      history.items = [saved()];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => DeviceActivitiesPage(
              ownerId: ownerA,
              health: health,
              history: history,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      expect(health.reads + health.permissions, 0);
      await tester.scrollUntilVisible(find.text('5,00 km'), 150);
      await tester.pumpAndSettle();
      expect(find.text('Temporizador: 28 min 21 s'), findsOneWidget);
      final target = find.text('Borrar historial importado');
      await tester.scrollUntilVisible(target, 150);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(history.clears, 0);
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(history.clears, 0);
      expect(find.text('¿Borrar el historial importado?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
