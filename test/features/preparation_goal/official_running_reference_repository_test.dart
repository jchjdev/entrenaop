import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/official_running_reference_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FAS entrega segundos medidos y excluye el historial no asociado', () {
    FasPeriodicAssessmentEntry entry(String id, String? goalId) =>
        FasPeriodicAssessmentEntry(
          id: id,
          goalId: goalId,
          scoringVersion: 'fas-2027-v1',
          completedAt: DateTime.utc(2026, 9, 28),
          category: 'men',
          age: 30,
          isPreEffectiveReference: true,
          marks: const [
            FasPeriodicAssessmentMark(
              testId: 'run_2000_m',
              testName: 'Carrera 2 km',
              unit: 'milliseconds',
              value: 650000,
              threshold: 714000,
              meetsMinimum: true,
            ),
          ],
        );
    final values = fasPeriodicRunningCandidates(
      goalId: 'fas-goal',
      entries: [entry('personal', null), entry('linked', 'fas-goal')],
    );
    expect(values, hasLength(1));
    expect(values.single.recordId, 'linked');
    expect(values.single.durationSeconds, 650);
    expect(values.single.source, RunningReferenceSource.fasPeriodicAssessment);
    expect(values.single.protocolVersion, isNull);
    expect(values.single.scoringVersion, 'fas-2027-v1');
  });

  test('Tropa extrae la marca oficial sin convertir su aptitud en ritmo', () {
    const test = PhysicalTestDefinition(
      id: 'run_2000_m',
      name: 'Carrera 2 km',
      unit: MarkUnit.milliseconds,
      betterDirection: BetterDirection.lower,
    );
    final entry = PhysicalAssessmentHistoryEntry(
      id: 'official-1',
      completedAt: DateTime.utc(2026, 9, 28),
      report: AssessmentReport(
        catalogVersion: 'troop-2026',
        category: AssessmentCategory.men,
        milestone: AssessmentMilestone.entry,
        results: const [
          AssessmentResult(
            passed: false,
            mark: RecordedMark(
              testId: 'run_2000_m',
              unit: MarkUnit.milliseconds,
              value: 700000,
            ),
            standard: AssessmentStandard(
              catalogVersion: 'troop-2026',
              test: test,
              category: AssessmentCategory.men,
              milestone: AssessmentMilestone.entry,
              threshold: 680000,
            ),
          ),
        ],
      ),
    );
    final values = troopOfficialRunningCandidates(
      goalId: 'troop-goal',
      entries: [entry],
    );
    expect(values.single.durationSeconds, 700);
    expect(values.single.scoringVersion, 'troop-2026');
    expect(values.single.protocolVersion, isNull);
    expect(
      values.single.source,
      RunningReferenceSource.troopOfficialAssessment,
    );
  });
}
