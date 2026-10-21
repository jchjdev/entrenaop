import 'package:workout_core/exercise_catalog_preferences.dart';

/// Adaptación del protocolo compartido. Cada app aporta transporte e identidad;
/// este cliente no conoce Auth, Supabase ni permisos administrativos.
class ExercisePreferencesClient implements ExerciseCatalogPreferences {
  ExercisePreferencesClient({
    required this.call,
    required this.checkIdentity,
    required String Function() operationId,
    required ExercisePreferenceContext context,
    required this.isConflict,
  }) : _operationId = operationId,
       _context = context == ExercisePreferenceContext.adminOfficial
           ? 'admin_official'
           : 'trainer_private';

  final Future<dynamic> Function(String name, Map<String, dynamic> parameters)
  call;
  final void Function() checkIdentity;
  final bool Function(Object error) isConflict;
  final String Function() _operationId;
  final String _context;
  final _orders = <String, _PreferenceOrder>{};
  final _inflight = <String, Future<ExercisePreferenceEntry>>{};

  @override
  String newOperationId() => _operationId();

  Future<dynamic> _rpc(String name, Map<String, dynamic> parameters) async {
    checkIdentity();
    try {
      final result = await call(name, {'p_context': _context, ...parameters});
      checkIdentity();
      return result;
    } catch (_) {
      checkIdentity();
      rethrow;
    }
  }

  static ExercisePreferenceEntry _entry(dynamic value) {
    final row = Map<String, dynamic>.from(value as Map);
    return ExercisePreferenceEntry(
      exerciseId: row['exercise_id'] as String,
      favorite: row['favorite'] as bool,
      favoriteRevision: row['favorite_revision'] as int,
      lastSelectedAt: row['last_selected_at'] == null
          ? null
          : DateTime.parse(row['last_selected_at'] as String),
    );
  }

  Future<ExercisePreferenceEntry> _current(String exerciseId) async => _entry(
    await _rpc('get_editor_exercise_preference', {'p_exercise_id': exerciseId}),
  );

  @override
  Future<ExercisePreferenceSnapshot> read() async {
    final row = Map<String, dynamic>.from(
      await _rpc('get_editor_exercise_preferences', {}) as Map,
    );
    return ExercisePreferenceSnapshot(
      entries: (row['entries'] as List).map(_entry),
      recentLimit: row['recent_limit'] as int,
      favoriteLimit: row['favorite_limit'] as int,
    );
  }

  @override
  Future<ExercisePreferenceEntry> setFavorite(
    String exerciseId,
    bool favorite, {
    required int expectedRevision,
    required String operationId,
  }) => _submit(
    operationId,
    _PreferenceOrder(exerciseId, favorite, expectedRevision),
  );

  @override
  Future<ExercisePreferenceEntry> recordSelection(
    String exerciseId, {
    required String operationId,
  }) => _submit(operationId, _PreferenceOrder(exerciseId, null, null));

  Future<ExercisePreferenceEntry> _submit(
    String operationId,
    _PreferenceOrder proposed,
  ) {
    checkIdentity();
    final order = _orders.putIfAbsent(operationId, () => proposed);
    if (!order.matches(proposed)) {
      return Future.error(
        StateError('El reintento debe conservar la preferencia original.'),
      );
    }
    return _inflight.putIfAbsent(operationId, () async {
      try {
        return await _write(operationId, order);
      } finally {
        _inflight.remove(operationId);
      }
    });
  }

  Future<ExercisePreferenceEntry> _write(
    String operationId,
    _PreferenceOrder order,
  ) async {
    final favorite = order.favorite;
    if (favorite != null && order.resolvedRevision == null) {
      var revision = order.expectedRevision!;
      if (revision == 0) {
        // El snapshot acotado puede omitir una fila desmarcada antigua. Consultar
        // su CAS no cambia la intención del click ni concede acceso al ejercicio.
        final current = await _current(order.exerciseId);
        if (current.favorite) throw ExercisePreferenceConflict(current);
        revision = current.favoriteRevision;
      }
      // Se fija ANTES del primer envío. Un resultado incierto nunca reconsulta
      // esta revisión para fabricar un payload distinto con el mismo UUID.
      order.resolvedRevision = revision;
    }
    try {
      return _entry(
        await _rpc(
          favorite == null
              ? 'record_editor_exercise_selection'
              : 'set_editor_exercise_favorite',
          {
            'p_operation_id': operationId,
            'p_exercise_id': order.exerciseId,
            if (favorite != null) ...{
              'p_favorite': favorite,
              'p_expected_revision': order.resolvedRevision,
            },
          },
        ),
      );
    } catch (error) {
      if (favorite != null && isConflict(error)) {
        throw ExercisePreferenceConflict(await _current(order.exerciseId));
      }
      rethrow;
    }
  }
}

class _PreferenceOrder {
  _PreferenceOrder(this.exerciseId, this.favorite, this.expectedRevision);
  final String exerciseId;
  final bool? favorite;
  final int? expectedRevision;
  int? resolvedRevision;

  bool matches(_PreferenceOrder other) =>
      exerciseId == other.exerciseId &&
      favorite == other.favorite &&
      expectedRevision == other.expectedRevision;
}
