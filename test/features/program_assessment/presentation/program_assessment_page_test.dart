import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:entrenaop/features/program_assessment/presentation/program_assessment_page.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Assessment implements ProgramAssessmentRepository {
  _Assessment({this.allowRetry = false});
  final bool allowRetry;
  String? lastCategory;
  String? lastProgramId;
  List<AssessmentMarkInput> savedMarks = const [];

  @override
  Future<ProgramAssessmentRule> rule(String programId) async {
    lastProgramId = programId;
    return const ProgramAssessmentRule(
      mode: 'pass_fail',
      version: 'test_v1',
      stage: 'Ingreso',
      ageReference: 'assessment_date',
    );
  }

  @override
  Future<ProgramAssessmentContext> contextFor(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
  ) async {
    lastCategory = category;
    return ProgramAssessmentContext(
      age: 26,
      tests: [
        ProgramAssessmentTest(
          id: category == 'men' ? 'h' : 'm',
          name: category == 'men' ? 'Dominadas' : 'Suspensión',
          unit: 'repetitions',
          markStep: 1,
          order: 1,
          protocol: 'Haz el ejercicio según la convocatoria.',
          maxAttempts: allowRetry ? 2 : 1,
          retryPolicy: allowRetry ? 'invalid_only' : 'none',
        ),
      ],
    );
  }

  @override
  Future<ProgramAssessmentResult> preview(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
    List<AssessmentMarkInput> marks,
  ) async => ProgramAssessmentResult(
    passed: true,
    age: 26,
    version: 'test_v1',
    details: [
      ProgramAssessmentDetail(
        name: category == 'men' ? 'Dominadas' : 'Suspensión',
        passed: true,
        mark: marks.single.attempts.last.mark,
        minimumMark: 5,
      ),
    ],
  );

  @override
  Future<void> save(
    String goalId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    List<AssessmentMarkInput> marks,
  ) async {
    savedMarks = marks;
  }

  @override
  Future<List<ProgramAssessmentAttempt>> history(String goalId) async =>
      const [];
}

void main() {
  const goal = PreparationGoal(
    id: 'goal',
    program: PreparationProgram(
      id: 'program',
      name: 'Programa de prueba',
      kind: PreparationProgramKind.access,
    ),
  );
  test('el historial conserva el nulo y la segunda marca de una prueba', () {
    final record = ProgramAssessmentAttempt.fromJson({
      'id': 'attempt',
      'assessed_on': '2026-09-27',
      'category': 'men',
      'marks': [
        {
          'test_id': 'agility',
          'attempts': [
            {'valid': false},
            {'valid': true, 'mark': 8.2},
          ],
        },
      ],
      'result': {
        'passed': true,
        'age': 26,
        'scoring_version': 'cnp_v1',
        'total': 10,
        'details': [
          {
            'test_id': 'agility',
            'name': 'Agilidad',
            'passed': true,
            'mark': 8.2,
            'points': 10,
          },
        ],
      },
    });
    expect(record.marks.single.attempts.first.valid, false);
    expect(record.marks.single.attempts.last.mark, 8.2);
    expect(record.result.details.single.testId, 'agility');
  });

  testWidgets(
    'solo muestra la prueba aplicable y guarda la marca en la preparación',
    (tester) async {
      final repository = _Assessment();
      await tester.pumpWidget(
        MaterialApp(
          home: ProgramAssessmentPage(
            goalId: 'goal',
            loadGoal: (_) async => goal,
            repository: repository,
            loadBirthDate: () async => DateTime(2000, 1, 1),
            saveBirthDate: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.lastProgramId, 'program');
      expect(find.textContaining('Dominadas'), findsOneWidget);
      expect(find.textContaining('Suspensión'), findsNothing);
      await tester.tap(find.text('Baremo M'));
      await tester.pumpAndSettle();
      expect(repository.lastCategory, 'women');
      expect(find.textContaining('Suspensión'), findsOneWidget);
      expect(find.textContaining('Dominadas'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '8');
      await tester.scrollUntilVisible(
        find.text('Ver resultado'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ver resultado'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Apto estimado'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Apto estimado'), findsOneWidget);
      await tester.ensureVisible(find.text('Guardar estas marcas'));
      await tester.tap(find.text('Guardar estas marcas'));
      await tester.pumpAndSettle();
      expect(repository.savedMarks.single.testId, 'm');
      expect(repository.savedMarks.single.attempts.single.mark, 8);
    },
  );

  testWidgets('registra nulo y segundo intento cuando la prueba lo permite', (
    tester,
  ) async {
    final repository = _Assessment(allowRetry: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProgramAssessmentPage(
          goalId: 'goal',
          loadGoal: (_) async => goal,
          repository: repository,
          loadBirthDate: () async => DateTime(2000, 1, 1),
          saveBirthDate: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Añadir intento'), findsNothing);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Añadir intento'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Añadir intento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '8');
    await tester.scrollUntilVisible(
      find.text('Ver resultado'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar estas marcas'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar estas marcas'));
    await tester.pumpAndSettle();
    final attempts = repository.savedMarks.single.attempts;
    expect(attempts.length, 2);
    expect(attempts.first.valid, false);
    expect(attempts.last.mark, 8);
  });

  testWidgets('rechaza una preparación que no está activa', (tester) async {
    final repository = _Assessment();
    await tester.pumpWidget(
      MaterialApp(
        home: ProgramAssessmentPage(
          goalId: 'goal',
          loadGoal: (_) async => null,
          repository: repository,
          loadBirthDate: () async => DateTime(2000, 1, 1),
          saveBirthDate: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo abrir la evaluación.'), findsOneWidget);
    expect(repository.lastProgramId, isNull);
  });
}
