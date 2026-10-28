import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_rpc.dart';

class CoachPushPreferences {
  const CoachPushPreferences({
    this.revision = 0,
    this.enabled = false,
    this.messages = true,
    this.videos = true,
    this.available = false,
  });
  factory CoachPushPreferences.fromJson(Map row) => CoachPushPreferences(
    revision: (row['revision'] as num).toInt(),
    enabled: row['enabled'] == true,
    messages: row['messages'] == true,
    videos: row['videos'] == true,
    available: row['available'] == true,
  );
  final int revision;
  final bool enabled, messages, videos, available;
  CoachPushPreferences copyWith({
    bool? enabled,
    bool? messages,
    bool? videos,
  }) => CoachPushPreferences(
    revision: revision,
    available: available,
    enabled: enabled ?? this.enabled,
    messages: messages ?? this.messages,
    videos: videos ?? this.videos,
  );
}

abstract class CoachNotificationRepository {
  Future<CoachPushPreferences> preferences();
  Future<CoachPushPreferences> save(CoachPushPreferences value);
  Future<void> videoRead(String assetId);
}

/// Puerto compartido entre el portal y el modo profesional del móvil.
class SupabaseCoachNotificationRepository
    implements CoachNotificationRepository {
  const SupabaseCoachNotificationRepository(this.client, this.owner);
  final SupabaseClient client;
  final String owner;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) =>
      authenticatedTrainerRpc(
        client,
        owner,
        name,
        params: {'p_expected_owner': owner, ...params},
      );
  @override
  Future<CoachPushPreferences> preferences() async =>
      CoachPushPreferences.fromJson(
        await _rpc('get_my_coach_push_preferences', {}) as Map,
      );
  @override
  Future<CoachPushPreferences> save(CoachPushPreferences value) async =>
      CoachPushPreferences.fromJson(
        await _rpc('save_my_coach_push_preferences', {
          'p_revision': value.revision,
          'p_enabled': value.enabled,
          'p_messages': value.messages,
          'p_videos': value.videos,
        }) as Map,
      );
  @override
  Future<void> videoRead(String assetId) async {
    await _rpc('read_my_coach_video', {'p_asset_id': assetId});
  }
}
