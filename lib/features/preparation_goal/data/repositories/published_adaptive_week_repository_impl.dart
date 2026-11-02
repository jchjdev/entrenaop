import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/published_adaptive_week_repository.dart';

class SupabasePublishedAdaptiveWeekRepository
    implements PublishedAdaptiveWeekRepository {
  const SupabasePublishedAdaptiveWeekRepository(this.client);

  final SupabaseClient client;

  @override
  Future<PublishedAdaptiveWeek> read(String goalId, DateTime week) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const PublishedAdaptiveWeekException(
        'Vuelve a iniciar sesión para consultar tu plan.',
      );
    }
    final monday = DateTime(
      week.year,
      week.month,
      week.day - week.weekday + DateTime.monday,
    );
    final weekStart =
        '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
    try {
      final preparation = await _readDecision(
        'preparation_week_decisions',
        userId,
        goalId,
        weekStart,
      );
      _checkAccount(userId);
      final running = await _readDecision(
        'running_week_decisions',
        userId,
        goalId,
        weekStart,
      );
      _checkAccount(userId);
      return PublishedAdaptiveWeek(
        preparationDecision: preparation,
        runningDecision: running,
      );
    } on PublishedAdaptiveWeekException {
      rethrow;
    } catch (_) {
      throw const PublishedAdaptiveWeekException(
        'No se ha podido consultar tu plan. Vuelve a intentarlo.',
      );
    }
  }

  Future<Map<String, dynamic>?> _readDecision(
    String table,
    String userId,
    String goalId,
    String weekStart,
  ) async {
    // RLS protege el recurso. El filtro también acota cuentas administradoras.
    final row = await client
        .from(table)
        .select('decision')
        .eq('user_id', userId)
        .eq('preparation_goal_id', goalId)
        .eq('week_start', weekStart)
        .isFilter('superseded_at', null)
        .maybeSingle();
    // Una respuesta iniciada por otra cuenta nunca llega a la presentación.
    _checkAccount(userId);
    return row == null
        ? null
        : Map<String, dynamic>.from(row['decision'] as Map);
  }

  void _checkAccount(String userId) {
    if (client.auth.currentUser?.id != userId) {
      throw const PublishedAdaptiveWeekException(
        'La sesión ha cambiado. Vuelve a abrir tu plan.',
      );
    }
  }
}
