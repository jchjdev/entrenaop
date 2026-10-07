import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_performance_strategy_section.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

class _Repository implements AdminProgramRepository {
  Map<String, dynamic>? saved;
  bool failSave = false;
  int saveCalls = 0;
  @override
  Future<AdminPerformanceSetup> loadPerformanceSetup(String programId) async =>
      AdminPerformanceSetup(
        StrengthExerciseCatalogCodec.decode(
          jsonDecode(
            File('../supabase/catalogs/strength_exercises_v1.json')
                .readAsStringSync(),
          ),
        ).exercises,
        const [
          {
            'test_id': 'push',
            'profile_code': 'push_up_standard',
            'profile_version': 1,
            'measurement_mode': 'REPS_IN_TIME',
            'review_note': 'Protocolo y condiciones revisados.',
            'training_parameters': {'fixed_duration_seconds': 120},
          },
        ],
      );
  @override
  Future<void> savePerformanceStrategy(
    String testId,
    Map<String, dynamic>? strategy,
  ) async {
    saveCalls++;
    if (failSave) throw StateError('Sin conexión');
    saved = strategy;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final published in [false, true]) {
    testWidgets(
      'estrategia ${published ? 'publicada queda bloqueada' : 'exige revisión y conserva ventana'}',
      (t) async {
        final repo = _Repository();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminPerformanceStrategySection(
                  program: AdminProgram(
                    id: 'program',
                    name: 'Programa',
                    kind: 'entry',
                    enabled: published,
                  ),
                  tests: const [
                    AdminProgramTest(
                      id: 'push',
                      code: 'push',
                      name: 'Flexiones',
                      unit: 'repetitions',
                      betterDirection: 'higher',
                      protocolNotes: 'Flexiones válidas en dos minutos.',
                      definitionVersion: 1,
                    ),
                  ],
                  repository: repo,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        if (published) {
          expect(find.text('Revisar'), findsNothing);
          expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        } else {
          await t.tap(find.text('Revisar'));
          await t.pumpAndSettle();
          expect(
            t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          await t.ensureVisible(find.byType(CheckboxListTile));
          await t.pumpAndSettle();
          await t.tap(find.byType(CheckboxListTile));
          await t.pumpAndSettle();
          repo.failSave = true;
          await t.tap(find.text('Guardar estrategia'));
          await t.pumpAndSettle();
          expect(
            find.textContaining('No se pudo guardar la estrategia'),
            findsOneWidget,
          );
          expect(
            t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
            isTrue,
          );
          repo.failSave = false;
          await t.tap(find.text('Guardar estrategia'));
          await t.pumpAndSettle();
          expect(repo.saveCalls, 2);
          expect(repo.saved?['measurement_mode'], 'REPS_IN_TIME');
          expect(repo.saved?['training_parameters'], {
            'fixed_duration_seconds': 120.0,
          });
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
