import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/training_context.dart';
import '../../domain/repositories/training_context_repository.dart';

class SupabaseTrainingContextRepository implements TrainingContextRepository {
  const SupabaseTrainingContextRepository(this.client);
  final SupabaseClient client;

  @override
  Future<TrainingContextSettings> load() async {
    final snapshot = Map<String, dynamic>.from(
      await client.rpc('get_training_context_settings') as Map,
    );
    final context = snapshot['context'] as Map?;
    final previous = snapshot['previous_preferences'] as Map?;
    return TrainingContextSettings(
      context: context == null
          ? null
          : TrainingContext(
              availability: (context['availability'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toInt()),
              ),
              equipment: (context['equipment'] as List).cast<String>().toSet(),
              reportsPain: context['reports_pain'] == true,
              capacityConfirmed: context['capacity_confirmed'] == true,
              observedAt: DateTime.tryParse(
                context['observed_at'] as String? ?? '',
              ),
            ),
      equipmentOptions: (snapshot['equipment_options'] as List? ?? [])
          .cast<String>()
          .toSet(),
      previousSessionMinutes: previous?['session_duration_minutes'] as int?,
      previousDaysPerWeek: previous?['available_days_per_week'] as int?,
      previousReportsLimitation:
          previous?['requires_professional_review'] == true,
      previousPullUpBar: (previous?['equipment'] as List? ?? []).contains(
        'pull_up_bar',
      ),
    );
  }

  @override
  Future<void> save(TrainingContext context) async {
    await client.rpc(
      'save_performance_context',
      params: {
        'p_availability': context.availability,
        'p_equipment': context.equipment.toList(),
        'p_reports_pain': context.reportsPain,
        'p_capacity_confirmed': context.capacityConfirmed,
      },
    );
  }
}
