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
  Future<bool> canManageAccounts();
  Future<AdminAccountDirectory> list({String search = '', String? afterId});
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
  @override
  Future<bool> canManageAccounts() async =>
      await client.rpc('can_manage_pro_accounts') == true;
  @override
  Future<AdminAccountDirectory> list({
    String search = '',
    String? afterId,
  }) async {
    final result = await client.rpc(
      'admin_list_pro_accounts',
      params: {'p_search': search, 'p_after_id': afterId, 'p_limit': 25},
    );
    return AdminAccountDirectory.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

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

class AdminAccountSummary {
  const AdminAccountSummary({
    required this.userId,
    required this.email,
    required this.isPro,
    this.freeProActive = false,
    this.subscriptionActive = false,
    this.subscriptionEnvironment,
  });
  final String userId, email;
  final bool isPro, freeProActive, subscriptionActive;
  final String? subscriptionEnvironment;
  String get description {
    if (!isPro) return 'Free';
    final sources = [
      if (freeProActive) 'Pro gratuito',
      if (subscriptionActive)
        subscriptionEnvironment == 'SANDBOX'
            ? 'Suscripción de prueba'
            : 'Suscripción',
    ];
    return sources.isEmpty ? 'Pro' : sources.join(' · ');
  }

  factory AdminAccountSummary.fromJson(Map<String, dynamic> json) =>
      AdminAccountSummary(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        isPro: json['tier'] == 'pro',
        freeProActive: json['free_pro_active'] == true,
        subscriptionActive: json['subscription_active'] == true,
        subscriptionEnvironment: json['subscription_environment'] as String?,
      );
}

class AdminAccountDirectory {
  const AdminAccountDirectory(this.accounts, {this.nextCursor});
  final List<AdminAccountSummary> accounts;
  final String? nextCursor;
  factory AdminAccountDirectory.fromJson(Map<String, dynamic> json) =>
      AdminAccountDirectory(
        (json['accounts'] as List)
            .map(
              (item) => AdminAccountSummary.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );
}
