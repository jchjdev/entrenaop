import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

Map<String, dynamic> _json(Object? value) =>
    Map<String, dynamic>.from(value as Map);

Map<String, dynamic> _snapshot(Map<String, dynamic> state) =>
    _json(jsonDecode(jsonEncode(state)));

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _sameJson(a[i], b[i]));
  }
  return a == b;
}

bool _isWorkConflict(PostgrestException error) =>
    error.code == '40001' ||
    (error.code == '22023' &&
        error.message ==
            'El reintento no coincide con la petición de trabajo original.');

/// Adapta el puerto común; derechos, CAS y recibos se validan en servidor.
class SupabaseTrainerProgramWorkRepository implements GuidedWorkRepository {
  const SupabaseTrainerProgramWorkRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) =>
      authenticatedTrainerRpc(
        client,
        userId,
        name,
        params: {...params, 'p_expected_owner': userId},
      );

  GuidedWork _decode(Map<String, dynamic> row) {
    if (row['permanently_deleted'] == true) {
      return GuidedWork(
        id: row['id'] as String,
        state: const {},
        permanentlyDeleted: true,
      );
    }
    return GuidedWork(
      id: row['id'] as String,
      state: _snapshot(_json(row['state'])),
      revision: (row['revision'] as num).toInt(),
      baseProgramId: row['base_program_id'] as String?,
      finalizedProgramId: row['finalized_program_id'] as String?,
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'] as String),
      discarded: row['lifecycle'] == 'discarded' || row['discarded_at'] != null,
      permanentlyDeleted: row['permanently_deleted'] == true,
    );
  }

  @override
  Future<List<GuidedWork>> list() async {
    final rows = await _rpc('list_trainer_program_work', {});
    return (rows as List)
        .map((row) => _decode(_json(row)))
        .where(
          (work) =>
              !work.discarded &&
              !work.permanentlyDeleted &&
              work.finalizedProgramId == null,
        )
        .toList();
  }

  @override
  Future<GuidedWork?> load(String id) async {
    final row = await _rpc('get_trainer_program_work', {'p_id': id});
    if (row == null) return null;
    return _decode(_json(row));
  }

  GuidedWork _receipt(
    Object? value,
    GuidedWork requested, {
    required String lifecycle,
    Map<String, dynamic>? state,
  }) {
    final envelope = _json(value);
    final row = _json(_json(envelope['receipt'])['work']);
    final receipt = _decode(row);
    // Un recibo viejo no acredita que la petición siga siendo el head actual.
    // Tampoco se sustituye por ese head: se conserva la petición incierta del
    // controlador común y se exige resolver el conflicto explícitamente.
    if (receipt.id != requested.id ||
        receipt.baseProgramId != requested.baseProgramId ||
        receipt.revision != requested.revision + 1 ||
        envelope['current_revision'] != receipt.revision ||
        envelope['current_lifecycle'] != lifecycle ||
        row['lifecycle'] != lifecycle ||
        receipt.permanentlyDeleted ||
        (state != null && !_sameJson(receipt.state, state))) {
      throw const GuidedWorkConflict();
    }
    return receipt;
  }

  @override
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state) async {
    final sent = _snapshot(state);
    try {
      return _receipt(
        await _rpc('save_trainer_program_work', {
          'p_id': work.id,
          'p_revision': work.revision,
          'p_state': sent,
          'p_base_program_id': work.baseProgramId,
        }),
        work,
        lifecycle: 'open',
        state: sent,
      );
    } on PostgrestException catch (error) {
      if (_isWorkConflict(error)) throw const GuidedWorkConflict();
      rethrow;
    }
  }

  @override
  Future<String> finalize(GuidedWork work, GuidedProgram program) async {
    validateGuidedProgram(program);
    try {
      return (await _rpc('finalize_trainer_program_work', {
        'p_id': work.id,
        'p_revision': work.revision,
        'p_content': _snapshot(guidedProgramToJson(program)),
      })) as String;
    } on PostgrestException catch (error) {
      if (_isWorkConflict(error)) throw const GuidedWorkConflict();
      rethrow;
    }
  }

  @override
  Future<void> discard(GuidedWork work) async {
    try {
      _receipt(
        await _rpc('discard_trainer_program_work', {
          'p_id': work.id,
          'p_revision': work.revision,
        }),
        work,
        lifecycle: 'discarded',
      );
    } on PostgrestException catch (error) {
      if (_isWorkConflict(error)) throw const GuidedWorkConflict();
      rethrow;
    }
  }
}
