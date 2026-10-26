class CiqLink {
  const CiqLink(
    this.id,
    this.createdAt,
    this.validUntil,
    this.revoked,
    this.lastSeenAt,
  );
  final String id;
  final DateTime createdAt, validUntil;
  final bool revoked;
  final DateTime? lastSeenAt;
}

class CiqAccount {
  const CiqAccount(this.allowed, this.links);
  final bool allowed;
  final List<CiqLink> links;
}

class CiqPairReview {
  const CiqPairReview(this.id, this.device, this.expiresAt);
  final String id, device;
  final DateTime expiresAt;
}

class CiqException implements Exception {
  const CiqException(this.code);
  final String code;
}

abstract interface class CiqConnectionRepository {
  Future<CiqAccount> load();
  Future<CiqPairReview> review(String code);
  Future<void> approve(String code, String id);
  Future<void> revoke(String id);
}
