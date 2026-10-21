import 'dart:async';

import 'package:device_activity_core/device_activity_core.dart';
import 'package:entrenaop/features/device_activities/data/running_history_codec.dart';
import 'package:entrenaop/features/device_activities/data/supabase_running_history_repository.dart';
import 'package:entrenaop/features/device_activities/domain/running_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'history_fixtures.dart';

Matcher problem(RunningHistoryProblem value) =>
    isA<RunningHistoryException>().having((e) => e.problem, 'problem', value);
void main() {
  test('projection replaces ephemeral namespace and canonicalizes only object UUID without changing measurements', () {
    final raw = activity();
    final projected = projectRunningActivity(raw, connection());
    expect(projected.identity.accountScope, connectionId);
    expect(projected.identity.externalId, externalId.toLowerCase());
    expect(raw.identity.accountScope, 'ephemeral-read');
    expect(projected.metrics.distanceMeters, 5000.125);
    expect(projected.metrics.timer!.inMicroseconds, 1700812345);
    expect(projected.revision.modifiedAtUtc, isNull);
    expect(projected.timeZoneId, isNull);
    expect(
      () => projectRunningActivity(raw, connection(owner: ownerB)),
      throwsA(problem(RunningHistoryProblem.accountChanged)),
    );
  });
  test('missing metrics remain missing, zero remains zero and duplicate UUID case is rejected', () {
    Map<String, dynamic> encoded(ExternalActivity run) =>
        RunningHistoryCodec.selections(
          RunningSaveRequest(
            operationId: 'fixture-op',
            connection: connection(),
            selections: [ReviewedRunningActivity(activity: run)],
          ),
        ).single;
    expect(
      encoded(activity(distance: null, timer: null))['distance_meters'],
      isNull,
    );
    expect(encoded(activity(distance: 0))['distance_meters'], 0);
    expect(
      () => RunningSaveRequest(
        operationId: 'fixture-op',
        connection: connection(),
        selections: [
          ReviewedRunningActivity(activity: activity()),
          ReviewedRunningActivity(
            activity: activity(id: externalId.toLowerCase()),
          ),
        ],
      ),
      throwsA(problem(RunningHistoryProblem.invalidData)),
    );
  });
  test('DTO allowlist excludes read scope, owner and receipt time; round trip preserves original snapshot', () {
    final request = RunningSaveRequest(
      operationId: 'fixture-op',
      connection: connection(),
      selections: [ReviewedRunningActivity(activity: activity())],
    );
    final json = RunningHistoryCodec.selections(request).single;
    expect(json.keys, isNot(contains('owner_id')));
    expect(json.keys, isNot(contains('account_scope')));
    expect(json.keys, isNot(contains('received_at')));
    final page = RunningHistoryCodec.page({
      'connection': connectionJson(),
      'items': [savedJson()],
      'has_more': false,
    }, ownerA);
    expect(
      page.items.single.activity.sameContentAs(
        projectRunningActivity(activity(), connection()),
      ),
      isTrue,
    );
    expect(
      () => RunningHistoryCodec.page({
        'connection': connectionJson(),
        'items': [
          {...savedJson(), 'owner_id': ownerB},
        ],
        'has_more': false,
      }, ownerA),
      throwsA(problem(RunningHistoryProblem.accountChanged)),
    );
  });
  test('read and save check current owner before and after async RPC; expected owner also travels to server', () async {
    var activeOwner = ownerA;
    final pending = Completer<Object?>();
    var calls = 0;
    final repo = SupabaseRunningHistoryRepository.withTransport(
      ownerId: ownerA,
      currentOwnerId: () => activeOwner,
      invoke: (name, params) async {
        calls++;
        expect(params['p_expected_owner'], ownerA);
        return pending.future;
      },
    );
    final operation = repo.load();
    activeOwner = ownerB;
    pending.complete(connectionJson());
    await expectLater(
      operation,
      throwsA(problem(RunningHistoryProblem.accountChanged)),
    );
    expect(calls, 1);
    await expectLater(
      repo.load(),
      throwsA(problem(RunningHistoryProblem.accountChanged)),
    );
    expect(calls, 1);
  });
  test('fence cancels transmission; uncertain retries serialize identical operation and expected revision', () async {
    final bodies = <Map<String, dynamic>>[];
    final repo = SupabaseRunningHistoryRepository.withTransport(
      ownerId: ownerA,
      currentOwnerId: () => ownerA,
      invoke: (name, params) async {
        bodies.add(params);
        return {'inserted': 1, 'updated': 0, 'unchanged': 0};
      },
    );
    final request = RunningSaveRequest(
      operationId: 'fixture-op',
      connection: connection(),
      selections: [ReviewedRunningActivity(activity: activity())],
    );
    final cancelled = RunningOperationFence()..cancel();
    await expectLater(
      repo.save(request, cancelled),
      throwsA(problem(RunningHistoryProblem.accountChanged)),
    );
    expect(bodies, isEmpty);
    await repo.save(request, RunningOperationFence());
    await repo.save(request, RunningOperationFence());
    expect(bodies[0], bodies[1]);
    expect(
      bodies.singleWhere((b) => identical(b, bodies[0]))['p_connection_id'],
      connectionId,
    );
  });
  test('coded server conflicts remain distinct and raw payloads never escape errors', () async {
    for (final entry in {
      'history_conflict': RunningHistoryProblem.conflict,
      'historical_revision': RunningHistoryProblem.historicalRevision,
      'revision_collision': RunningHistoryProblem.revisionCollision,
      'operation_reused': RunningHistoryProblem.operationReused,
      'history_limit': RunningHistoryProblem.limitReached,
      'stale_generation': RunningHistoryProblem.staleGeneration,
      'secret-native-message': RunningHistoryProblem.unavailable,
    }.entries) {
      final repo = SupabaseRunningHistoryRepository.withTransport(
        ownerId: ownerA,
        currentOwnerId: () => ownerA,
        invoke: (name, params) async => throw PostgrestException(
          message: entry.key,
          details: 'secret payload',
        ),
      );
      try {
        await repo.load();
        fail('expected failure');
      } on RunningHistoryException catch (e) {
        expect(e.problem, entry.value);
        expect(e.toString(), isNot(contains('secret')));
      }
    }
  });
}
