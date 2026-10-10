import 'package:supabase_flutter/supabase_flutter.dart';

class DevelopmentAccountAccess {
  const DevelopmentAccountAccess({
    required this.userId,
    required this.isPro,
    required this.exercises,
    required this.sessions,
    this.validUntil,
  });
  final String userId;
  final bool isPro;
  final int exercises, sessions;
  final DateTime? validUntil;
  factory DevelopmentAccountAccess.fromJson(Map<String, dynamic> json) =>
      DevelopmentAccountAccess(
        userId: json['user_id'] as String,
        isPro: json['tier'] == 'pro',
        exercises: (json['personal_exercises'] as num).toInt(),
        sessions: (json['personal_sessions'] as num).toInt(),
        validUntil: DateTime.tryParse(json['valid_until'] as String? ?? ''),
      );
}

abstract class AdminProAccessRepository {
  Future<DevelopmentAccountAccess> find(String email);
  Future<DevelopmentAccountAccess> setAccess(
    String userId, {
    required bool enabled,
    required int days,
    required String reason,
  });
}

class SupabaseAdminProAccessRepository implements AdminProAccessRepository {
  const SupabaseAdminProAccessRepository(this.client);
  final SupabaseClient client;
  Future<DevelopmentAccountAccess> _call(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await client.rpc(name, params: params);
    return DevelopmentAccountAccess.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<DevelopmentAccountAccess> find(String email) =>
      _call('admin_find_development_account', {'p_email': email});
  @override
  Future<DevelopmentAccountAccess> setAccess(
    String userId, {
    required bool enabled,
    required int days,
    required String reason,
  }) => _call('admin_set_development_pro_access', {
    'p_user_id': userId,
    'p_enabled': enabled,
    'p_days': days,
    'p_reason': reason,
  });
}
