import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_security_repository.dart';

class SupabaseAdminSecurityRepository implements AdminSecurityRepository {
  const SupabaseAdminSecurityRepository(this.client);
  final SupabaseClient client;
  @override
  Future<AdminSecurityStatus> status() async {
    final data = Map<String, dynamic>.from(
      await client.rpc('get_admin_security_status') as Map,
    );
    return AdminSecurityStatus(
      eligible: data['eligible'] == true,
      mfaRequired: data['mfa_required'] == true,
      assured: data['assured'] == true,
    );
  }

  @override
  Future<List<String>> verifiedFactors() async =>
      (await client.auth.mfa.listFactors()).totp.map((f) => f.id).toList();
  @override
  Future<AdminTotpSetup> enroll() async {
    final factors = (await client.auth.mfa.listFactors()).all;
    for (final factor in factors) {
      // Un reintento tras perder el QR elimina solo configuraciones nunca verificadas.
      if (factor.factorType == FactorType.totp &&
          factor.status == FactorStatus.unverified &&
          factor.friendlyName == 'EntrenaOP Admin') {
        await client.auth.mfa.unenroll(factor.id);
      }
    }
    final data = await client.auth.mfa.enroll(
      factorType: FactorType.totp,
      friendlyName: 'EntrenaOP Admin',
      issuer: 'EntrenaOP',
    );
    return AdminTotpSetup(
      factorId: data.id,
      qrSvg: data.totp!.qrCode,
      secret: data.totp!.secret,
    );
  }

  @override
  Future<void> verify(String factorId, String code) async {
    await client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  }

  @override
  Future<void> enableRequirement() async {
    await client.rpc('enable_admin_mfa_requirement');
  }

  @override
  Future<void> changePassword(String current, String password) async {
    await client.auth.updateUser(
      UserAttributes(password: password, currentPassword: current),
    );
  }

  // Conserva esta sesión de configuración y revoca las demás renovaciones.
  @override
  Future<void> revokeOtherSessions() =>
      client.auth.signOut(scope: SignOutScope.others);
  @override
  Future<void> signOut() => client.auth.signOut();
}
