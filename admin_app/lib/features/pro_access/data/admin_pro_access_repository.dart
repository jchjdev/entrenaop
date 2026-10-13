import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAccountAccess {
  const AdminAccountAccess({
    required this.userId,
    required this.isPro,
    required this.exercises,
    required this.sessions,
    this.validUntil,
    this.source,
    this.freeProActive = false,
    this.freeProValidUntil,
    this.giftManagementEnabled = false,
    this.subscriptionActive = false,
    this.subscriptionValidUntil,
    this.subscriptionEnvironment,
    this.subscriptionProduct,
  });
  final String userId;
  final bool isPro;
  final int exercises, sessions;
  final DateTime? validUntil;
  final String? source, subscriptionEnvironment, subscriptionProduct;
  final bool freeProActive, giftManagementEnabled, subscriptionActive;
  final DateTime? freeProValidUntil, subscriptionValidUntil;
  factory AdminAccountAccess.fromJson(Map<String, dynamic> json) =>
      AdminAccountAccess(
        userId: json['user_id'] as String,
        isPro: json['tier'] == 'pro',
        exercises: (json['personal_exercises'] as num).toInt(),
        sessions: (json['personal_sessions'] as num).toInt(),
        validUntil: DateTime.tryParse(json['valid_until'] as String? ?? ''),
        source: json['source'] as String?,
        freeProActive: json['free_pro_active'] == true,
        freeProValidUntil: DateTime.tryParse(
          json['free_pro_valid_until'] as String? ?? '',
        ),
        giftManagementEnabled: json['gift_management_enabled'] == true,
        subscriptionActive: json['subscription_active'] == true,
        subscriptionValidUntil: DateTime.tryParse(
          json['subscription_valid_until'] as String? ?? '',
        ),
        subscriptionEnvironment: json['subscription_environment'] as String?,
        subscriptionProduct: json['subscription_product_identifier'] as String?,
      );
}

abstract class AdminProAccessRepository {
  Future<AdminAccountAccess> find(String email);
  Future<AdminAccountAccess> setAccess(
    String userId, {
    required bool enabled,
    DateTime? validUntil,
    required String reason,
  });
}

class SupabaseAdminProAccessRepository implements AdminProAccessRepository {
  const SupabaseAdminProAccessRepository(this.client);
  final SupabaseClient client;
  Future<AdminAccountAccess> _call(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await client.rpc(name, params: params);
    return AdminAccountAccess.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<AdminAccountAccess> find(String email) =>
      _call('admin_find_pro_account', {'p_email': email});
  @override
  Future<AdminAccountAccess> setAccess(
    String userId, {
    required bool enabled,
    DateTime? validUntil,
    required String reason,
  }) => _call('admin_set_free_pro_access', {
    'p_user_id': userId,
    'p_enabled': enabled,
    'p_valid_until': validUntil?.toUtc().toIso8601String(),
    'p_reason': reason,
  });
}
