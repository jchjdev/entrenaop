import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../../../packages/trainer_access/test_support/fake_trainer_repository.dart';

class Programs extends Fake implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => true;
}

class Workouts extends Fake implements AdminWorkoutRepository {}

class Exercises extends Fake implements AdminExerciseRepository {}

class Accounts extends Fake implements AdminProAccessRepository {
  Accounts(this.allowed);
  final bool allowed;
  @override
  Future<bool> canManageAccounts() async => allowed;
  @override
  Future<AdminAccountDirectory> list({
    String search = '',
    String? afterId,
  }) async => const AdminAccountDirectory([]);
}

class Trainers extends FakeTrainerRepository {
  int reads = 0;
  @override
  Future<List<ManagedTrainer>> managedTrainers({String? afterId}) async {
    reads++;
    return [];
  }
}

void main() {
  for (final (allowed, mfa) in [(true, false), (false, false), (true, true)]) {
    testWidgets(
      'ruta profesional dentro de Cuentas: gestor $allowed reto MFA $mfa',
      (tester) async {
        final trainers = Trainers();
        final router = createAdminRouter(
          programs: Programs(),
          workouts: Workouts(),
          exercises: Exercises(),
          proAccess: Accounts(allowed),
          trainers: trainers,
          isAuthenticated: () => true,
          onSignOut: () {},
          needsSecurity: () async => mfa,
          securityBuilder: (_) =>
              const Scaffold(body: Text('Segundo factor pendiente')),
          initialLocation: '/trainers',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (mfa) {
          expect(router.state.uri.path, '/security');
          expect(trainers.reads, 0);
        } else if (!allowed) {
          expect(
            find.text(
              'Solo el responsable de cuentas puede gestionar entrenadores.',
            ),
            findsOneWidget,
          );
          expect(trainers.reads, 0);
        } else {
          expect(find.text('Accesos profesionales'), findsOneWidget);
          expect(trainers.reads, 1);
          await tester.ensureVisible(find.text('Cuentas registradas'));
          await tester.tap(find.text('Cuentas registradas'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/accounts');
          expect(find.text('Gestionar entrenadores'), findsOneWidget);
          await tester.ensureVisible(find.text('Gestionar entrenadores'));
          await tester.tap(find.text('Gestionar entrenadores'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/trainers');
          expect(trainers.reads, 2);
        }
      },
    );
  }
}
