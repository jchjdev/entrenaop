import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_editor_ui/editor_work_checkpoint.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

Map<String, dynamic> _json(Object? value) =>
    Map<String, dynamic>.from(value as Map);

Map<String, dynamic> _snapshot(Map<String, dynamic> value) =>
    _json(jsonDecode(jsonEncode(value)));

bool _sameJson(Map<String, dynamic> a, Map<String, dynamic> b) =>
    canonicalEditorState(a) == canonicalEditorState(b);

bool _conflict(PostgrestException error) =>
    error.code == '40001' ||
    error.code == '22023' &&
        error.message ==
            'El reintento no coincide con la petición de trabajo original.';

/// El puerto de presentación es común; identidad, recibos y cuotas son propios.
/// No concede permisos ADMIN ni convierte una revisión de biblioteca en pauta.
class SupabaseTrainerWorkoutWorkRepository
    implements WorkoutEditorWorkRepository {
  const SupabaseTrainerWorkoutWorkRepository(this.client, this.userId);

  final SupabaseClient client;
  final String userId;

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) =>
      authenticatedTrainerRpc(
        client,
        userId,
        name,
        params: {...params, 'p_expected_owner': userId},
      );

  WorkoutEditorWork _decode(Object? value) {
    final row = _json(value);
    final lifecycle = row['lifecycle'];
    if (row['context'] != 'trainer_private' ||
        !{'open', 'discarded', 'finalized'}.contains(lifecycle) ||
        (lifecycle == 'finalized') != (row['result_id'] != null)) {
      throw const FormatException('Trabajo profesional incompatible.');
    }
    return WorkoutEditorWork(
      id: row['id'] as String,
      origin: _snapshot(_json(row['origin'])),
      state: _snapshot(_json(row['state'])),
      revision: (row['revision'] as num).toInt(),
      resultId: row['result_id'] as String?,
      discarded: lifecycle == 'discarded',
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'] as String),
    );
  }

  WorkoutEditorWork _receipt(
    Object? value,
    WorkoutEditorWork requested, {
    required String lifecycle,
    Map<String, dynamic>? state,
    bool allowFinalized = false,
  }) {
    final envelope = _json(value);
    final row = _json(_json(envelope['receipt'])['work']);
    final receipt = _decode(row);
    final receivedLifecycle = row['lifecycle'];
    // El recibo histórico no se sustituye por el HEAD de otra pestaña. Si el
    // HEAD avanzó, el controlador conserva su petición local y muestra conflicto.
    if (receipt.id != requested.id ||
        !_sameJson(receipt.origin, requested.origin) ||
        receipt.revision != requested.revision + 1 ||
        envelope['current_revision'] != receipt.revision ||
        envelope['current_lifecycle'] != receivedLifecycle ||
        (receivedLifecycle != lifecycle &&
            !(allowFinalized && receivedLifecycle == 'finalized')) ||
        (state != null && !_sameJson(receipt.state, state))) {
      throw const WorkoutWorkConflict();
    }
    return receipt;
  }

  Future<T> _operation<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (error) {
      if (_conflict(error)) throw const WorkoutWorkConflict();
      rethrow;
    }
  }

  @override
  Future<List<WorkoutEditorWork>> list() async =>
      (await _rpc('list_trainer_session_work', {}) as List)
          .map(_decode)
          .toList(growable: false);

  @override
  Future<WorkoutEditorWork?> load(String id) async {
    final row = await _rpc('get_trainer_session_work', {'p_id': id});
    return row == null ? null : _decode(row);
  }

  @override
  Future<WorkoutEditorWork> save(
    WorkoutEditorWork work,
    Map<String, dynamic> state,
  ) {
    // Congela antes del primer await: mutar el formulario no cambia el envío.
    final sent = _snapshot(state);
    final origin = _snapshot(work.origin);
    return _operation(
      () async => _receipt(
        await _rpc('save_trainer_session_work', {
          'p_id': work.id,
          'p_revision': work.revision,
          'p_origin': origin,
          'p_state': sent,
        }),
        work,
        lifecycle: 'open',
        state: sent,
      ),
    );
  }

  @override
  Future<String> finalize(WorkoutEditorWork work) => _operation(
    () async => (await _rpc('finalize_trainer_session_work', {
      'p_id': work.id,
      'p_revision': work.revision,
    })) as String,
  );

  @override
  Future<void> discard(WorkoutEditorWork work) => _operation(() async {
    _receipt(
      await _rpc('discard_trainer_session_work', {
        'p_id': work.id,
        'p_revision': work.revision,
      }),
      work,
      lifecycle: 'discarded',
    );
  });

  @override
  Future<WorkoutEditorWork> reopen(WorkoutEditorWork work) => _operation(
    () async => _receipt(
      await _rpc('reopen_trainer_session_work', {
        'p_id': work.id,
        'p_revision': work.revision,
      }),
      work,
      lifecycle: 'open',
      allowFinalized: true,
    ),
  );
}
