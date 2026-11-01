import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/device_activity_inbox.dart';
import 'package:workout_core/device_activity_summary.dart';

class SupabaseDeviceActivityInboxRepository
    implements DeviceActivityInboxRepository {
  const SupabaseDeviceActivityInboxRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  @override
  Future<List<DeviceActivitySummary>> load() async {
    final rows = await authenticatedTrainerRpc(
      client,
      userId,
      'my_unassigned_device_activities',
      params: {'p_expected_owner': userId},
    );
    return [
      for (final row in rows as List)
        DeviceActivitySummary.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
