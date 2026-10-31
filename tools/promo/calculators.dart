// Adaptadores locales de las calculadoras gratuitas; no inicializan servicios.
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';

class DemoBirthDate implements ProfileBirthDateRepository {
  DateTime value = DateTime(1998, 5, 12);
  @override
  Future<DateTime?> get() async => value;
  @override
  Future<void> save(DateTime birthDate) async {
    value = birthDate;
  }
}

class DemoFasResults implements FasPeriodicAssessmentRepository {
  @override
  Future<List<FasPeriodicAssessmentEntry>> history({String? goalId}) async =>
      [];
  @override
  Future<String> save({
    String? goalId,
    required String category,
    required int age,
    required Map<String, int> marks,
    DateTime? completedAt,
  }) async => 'demo-fas-result';
  @override
  Future<void> linkRecentToGoal({
    required String assessmentId,
    required String goalId,
  }) async {}
}
