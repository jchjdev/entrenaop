import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/device_training_progress.dart';

import 'trainer_calendar_date.dart';
import 'trainer_workout_repository.dart';

class TrainerClientAgendaPage {
  const TrainerClientAgendaPage({required this.items, required this.hasMore});
  factory TrainerClientAgendaPage.fromJson(Map<String, dynamic> json) =>
      TrainerClientAgendaPage(
        items: (json['items'] as List)
            .map(
              (row) => TrainerClientAgendaItem.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
        hasMore: json['has_more'] == true,
      );
  final List<TrainerClientAgendaItem> items;
  final bool hasMore;
}

class TrainerClientAgendaItem {
  TrainerClientAgendaItem.fromJson(Map<String, dynamic> json)
    : assignment = TrainerAssignment.fromJson(json),
      running = json['is_running'] == true,
      deviceTraining = json['device_training'] == null
          ? null
          : DeviceTrainingProgress.fromJson(
              Map<String, dynamic>.from(json['device_training'] as Map),
            ) {
    if (deviceTraining != null && deviceTraining!.id != assignment.id) {
      throw const FormatException(
        'El estado de Garmin no corresponde a esta pauta.',
      );
    }
  }
  final TrainerAssignment assignment;
  final bool running;
  final DeviceTrainingProgress? deviceTraining;
}

abstract class TrainerClientPlanningRepository {
  Future<TrainerClientAgendaPage> week(
    String clientId,
    DateTime from,
    DateTime to, {
    TrainerClientAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  });
}

class SupabaseTrainerClientPlanningRepository
    implements TrainerClientPlanningRepository {
  const SupabaseTrainerClientPlanningRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  @override
  Future<TrainerClientAgendaPage> week(
    String clientId,
    DateTime from,
    DateTime to, {
    TrainerClientAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  }) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    final result = await authenticatedTrainerRpc(
      client,
      userId,
      'list_trainer_client_agenda_filtered',
      params: {
        'p_visibility': visibility.name,
        'p_expected_owner': userId,
        'p_client_id': clientId,
        'p_from': trainerCalendarDate(from),
        'p_to': trainerCalendarDate(to),
        'p_after_date': after == null
            ? null
            : trainerCalendarDate(after.assignment.date),
        'p_after_id': after?.assignment.id,
      },
    );
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    return TrainerClientAgendaPage.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}
