import 'package:entrenaop/features/pro/domain/pro_access.dart';

class ProAccessFixture implements ProAccessRepository {
  ProAccessFixture({this.isPro = false});
  bool isPro;
  int calls = 0;
  @override
  Future<ProAccess> load() async {
    calls++;
    return ProAccess(
      userId: 'fixture',
      isPro: isPro,
      checkedAt: DateTime.utc(2026, 10, 10),
      validUntil: isPro ? DateTime.utc(2026, 11, 10) : null,
      source: isPro ? 'development_manual' : null,
      personalExercises: 0,
      personalSessions: 0,
    );
  }
}
