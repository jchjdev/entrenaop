class AdminSecurityStatus {
  const AdminSecurityStatus({
    required this.eligible,
    required this.mfaRequired,
    required this.assured,
  });
  final bool eligible, mfaRequired, assured;
  bool get needsSetupOrChallenge => eligible && (!mfaRequired || !assured);
}

class AdminTotpSetup {
  const AdminTotpSetup({
    required this.factorId,
    required this.qrSvg,
    required this.secret,
  });
  final String factorId, qrSvg, secret;
}

abstract interface class AdminSecurityRepository {
  Future<AdminSecurityStatus> status();
  Future<List<String>> verifiedFactors();
  Future<AdminTotpSetup> enroll();
  Future<void> verify(String factorId, String code);
  Future<void> enableRequirement();
  Future<void> changePassword(String current, String password);
  Future<void> revokeOtherSessions();
  Future<void> signOut();
}
