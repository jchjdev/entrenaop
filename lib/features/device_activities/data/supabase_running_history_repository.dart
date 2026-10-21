import 'package:device_activity_core/device_activity_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/running_history.dart';
import 'running_history_codec.dart';

typedef RunningHistoryRpc = Future<Object?> Function(
  String name,
  Map<String, dynamic> parameters,
);

final class SupabaseRunningHistoryRepository
    implements RunningHistoryRepository {
  SupabaseRunningHistoryRepository(SupabaseClient client, String ownerId)
    : this.withTransport(
        ownerId: ownerId,
        currentOwnerId: () => client.auth.currentUser?.id,
        invoke: (name, params) async => await client.rpc(name, params: params),
      );

  SupabaseRunningHistoryRepository.withTransport({
    required this.ownerId,
    required String? Function() currentOwnerId,
    required RunningHistoryRpc invoke,
    this.channel = ActivityChannel.appleHealth,
  }) : _currentOwnerId = currentOwnerId,
       _invoke = invoke;
  @override
  final String ownerId;
  final ActivityChannel channel;
  final String? Function() _currentOwnerId;
  final RunningHistoryRpc _invoke;

  void _identity() {
    if (_currentOwnerId() != ownerId) {
      throw const RunningHistoryException(RunningHistoryProblem.accountChanged);
    }
  }

  Future<Object?> _rpc(
    String name,
    Map<String, dynamic> parameters, [
    RunningOperationFence? fence,
  ]) async {
    _identity();
    fence?.check();
    try {
      final result = await _invoke(name, {
        'p_expected_owner': ownerId,
        ...parameters,
      });
      _identity();
      fence?.check();
      return result;
    } on RunningHistoryException {
      rethrow;
    } on PostgrestException catch (error) {
      _identity();
      fence?.check();
      // Solo códigos conocidos: los mensajes y detalles del servidor no llegan a la UI.
      throw RunningHistoryException(switch (error.message) {
        'account_changed' => RunningHistoryProblem.accountChanged,
        'history_conflict' => RunningHistoryProblem.conflict,
        'historical_revision' => RunningHistoryProblem.historicalRevision,
        'revision_collision' => RunningHistoryProblem.revisionCollision,
        'operation_reused' => RunningHistoryProblem.operationReused,
        'history_limit' => RunningHistoryProblem.limitReached,
        'stale_generation' => RunningHistoryProblem.staleGeneration,
        'invalid_running_history' => RunningHistoryProblem.invalidData,
        _ =>
          error.code == '42501'
              ? RunningHistoryProblem.accountChanged
              : RunningHistoryProblem.unavailable,
      });
    } catch (_) {
      _identity();
      fence?.check();
      throw const RunningHistoryException(RunningHistoryProblem.unavailable);
    }
  }

  @override
  Future<RunningHistoryPage> load({RunningHistoryCursor? before}) async {
    final connection = RunningHistoryCodec.connection(
      await _rpc('open_running_health_connection', {
        'p_channel': RunningHistoryCodec.channel(channel),
      }),
      ownerId,
    );
    _scope(connection);
    final page = RunningHistoryCodec.page(
      await _rpc('list_running_health_history', {
        'p_connection_id': connection.id,
        'p_limit': 50,
        'p_before_started_at': before?.startedAtUtc.toIso8601String(),
        'p_before_id': before?.id,
      }),
      ownerId,
    );
    if (page.connection.id != connection.id ||
        page.connection.channel != channel) {
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
    }
    return page;
  }

  @override
  Future<RunningSaveReceipt> save(
    RunningSaveRequest request,
    RunningOperationFence fence,
  ) async {
    _scope(request.connection);
    final items = RunningHistoryCodec.selections(request);
    return RunningHistoryCodec.receipt(
      await _rpc('save_running_health_history', {
        'p_connection_id': request.connection.id,
        'p_expected_generation': request.connection.generation,
        'p_operation_id': request.operationId,
        'p_items': items,
      }, fence),
    );
  }

  @override
  Future<void> clear({
    required RunningHistoryConnection connection,
    required String operationId,
    required RunningOperationFence fence,
  }) async {
    _scope(connection);
    final row = RunningHistoryCodec.object(
      await _rpc('clear_running_health_history', {
        'p_connection_id': connection.id,
        'p_expected_generation': connection.generation,
        'p_operation_id': operationId,
      }, fence),
    );
    if (row['cleared'] != true) {
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
    }
  }

  void _scope(RunningHistoryConnection connection) {
    _identity();
    if (connection.ownerId != ownerId || connection.channel != channel) {
      throw const RunningHistoryException(RunningHistoryProblem.accountChanged);
    }
  }
}
