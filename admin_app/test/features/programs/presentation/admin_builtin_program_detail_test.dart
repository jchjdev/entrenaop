import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop_admin/features/programs/data/admin_builtin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_detail_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';

class Programs extends Fake implements AdminProgramRepository {
  int configurableReads = 0;
  @override
  Future<List<AdminProgramTest>> listTests(String id) async {
    configurableReads++;
    return [];
  }

  @override
  Future<AdminProgramScoringRule?> getScoringRule(String id) async {
    configurableReads++;
    return null;
  }

  @override
  Future<List<AdminProgramTrainingModule>> listTrainingModules(
    String id,
  ) async {
    configurableReads++;
    return [];
  }
}

class Workouts extends Fake implements AdminWorkoutRepository {}

class Builtin implements AdminBuiltinProgramRepository {
  int reads = 0;
  @override
  Future<AdminBuiltinProgramData> load(String id) async {
    reads++;
    return AdminBuiltinProgramData(
      programId: id,
      version: 'catalogo_v1',
      name: 'Catálogo existente',
      sourceUrl: 'https://www.boe.es/eli/es/o/2026/01/13/def15',
      effectiveFrom: '2027-01-01',
      objectives: const [],
      standards: const [
        AdminBuiltinStandard(
          testId: 'push',
          name: 'Flexiones',
          unit: 'repetitions',
          direction: 'higher',
          category: 'men',
          group: 'entry',
          threshold: 10,
        ),
      ],
    );
  }
}

void main() {
  for (final id in ['armed_forces_troop_entry', 'fas_periodic_assessment']) {
    testWidgets(
      '$id consulta su catálogo sin falsa ausencia ni clonación inerte',
      (t) async {
        final programs = Programs();
        final builtin = Builtin();
        await t.pumpWidget(
          MaterialApp(
            home: AdminProgramDetailPage(
              program: AdminProgram(
                id: id,
                name: 'Preparación existente',
                kind: 'access',
                enabled: true,
              ),
              repository: programs,
              workoutRepository: Workouts(),
              builtinRepository: builtin,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Catálogo existente'), findsOneWidget);
        expect(find.text('Versión: catalogo_v1'), findsOneWidget);
        expect(find.text('Flexiones'), findsOneWidget);
        expect(find.textContaining('Sin regla de evaluación'), findsNothing);
        expect(
          find.text('Este programa todavía no tiene pruebas definidas.'),
          findsNothing,
        );
        expect(find.text('Crear nueva versión editable'), findsNothing);
        expect(programs.configurableReads, 0);
        expect(builtin.reads, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
}
