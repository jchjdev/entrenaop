import 'package:supabase_flutter/supabase_flutter.dart';

class TrainerTotpSetup {
  const TrainerTotpSetup(this.id, this.qr, this.secret);
  final String id, qr, secret;
}

abstract class TrainerSecurity {
  Future<bool> assured();
  Future<List<String>> factors();
  Future<TrainerTotpSetup> enroll();
  Future<void> verify(String factor, String code);
}

class SupabaseTrainerSecurity implements TrainerSecurity {
  const SupabaseTrainerSecurity(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _check() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  @override
  Future<bool> assured() async {
    _check();
    final result = await client.rpc('get_trainer_security_status');
    _check();
    return result == true;
  }

  @override
  Future<List<String>> factors() async {
    _check();
    final result = (await client.auth.mfa.listFactors()).totp
        .map((f) => f.id)
        .toList();
    _check();
    return result;
  }

  @override
  Future<TrainerTotpSetup> enroll() async {
    _check();
    final factors = (await client.auth.mfa.listFactors()).all;
    for (final factor in factors) {
      _check();
      if (factor.factorType == FactorType.totp &&
          factor.status == FactorStatus.unverified &&
          factor.friendlyName == 'EntrenaOP Preparadores') {
        await client.auth.mfa.unenroll(factor.id);
      }
    }
    _check();
    final data = await client.auth.mfa.enroll(
      factorType: FactorType.totp,
      friendlyName: 'EntrenaOP Preparadores',
      issuer: 'EntrenaOP',
    );
    _check();
    return TrainerTotpSetup(data.id, data.totp!.qrCode, data.totp!.secret);
  }

  @override
  Future<void> verify(String factor, String code) async {
    _check();
    await client.auth.mfa.challengeAndVerify(factorId: factor, code: code);
    _check();
  }
}
