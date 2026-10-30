import 'package:trainer_access/trainer_calendar.dart';

/// Solo consulta la agenda personal ya activada desde «Para mí».
/// No crea vínculos ni accede a la cartera del preparador del usuario.
class SupabaseTrainerPersonalCalendarRepository
    extends SupabaseTrainerSharedCalendarRepository {
  SupabaseTrainerPersonalCalendarRepository(super.client, super.userId);

  void _owner(String clientId) {
    if (clientId != userId || client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  @override
  Future<SharedCalendarPage> calendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) async {
    _owner(clientId);
    final links = await client
        .from('trainer_client_relations')
        .select('id')
        .eq('trainer_id', userId)
        .eq('client_id', userId)
        .isFilter('ended_at', null)
        .limit(1);
    _owner(clientId);
    if (links.isEmpty) {
      return SharedCalendarPage.fromJson({
        'shared': true,
        'has_more': false,
        'items': <Object>[],
        'coaches': <Object>[],
      });
    }
    return super.calendar(clientId, from, to, after: after);
  }

  @override
  Future<Map<String, dynamic>> workout(String clientId, String scheduledId) {
    _owner(clientId);
    return super.workout(clientId, scheduledId);
  }
}
