import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/auth/domain/admin_security_repository.dart';
import 'package:entrenaop_admin/features/auth/presentation/admin_security_page.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_work.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Security extends Fake implements AdminSecurityRepository {
  AdminSecurityStatus state = const AdminSecurityStatus(
    eligible: true,
    mfaRequired: false,
    assured: false,
  );
  List<String> factors = [];
  int passwordChanges = 0, revokes = 0, enrolls = 0, verifies = 0, enables = 0;
  bool failRevoke = false, failEnable = false, failVerify = false;
  @override
  Future<AdminSecurityStatus> status() async => state;
  @override
  Future<List<String>> verifiedFactors() async => factors;
  @override
  Future<void> changePassword(String current, String password) async {
    passwordChanges++;
  }

  @override
  Future<void> revokeOtherSessions() async {
    revokes++;
    if (failRevoke) throw StateError('Sin conexión');
  }

  @override
  Future<AdminTotpSetup> enroll() async {
    enrolls++;
    return const AdminTotpSetup(
      factorId: 'factor',
      qrSvg: '<svg/>',
      secret: 'FIXTURE-ONLY',
    );
  }

  @override
  Future<void> verify(String factorId, String code) async {
    expect(factorId, 'factor');
    expect(code, '123456');
    verifies++;
    if (failVerify) throw StateError('Código incorrecto');
  }

  @override
  Future<void> enableRequirement() async {
    enables++;
    if (failEnable) throw StateError('Sin conexión');
  }

  @override
  Future<void> signOut() async {}
}

class _Programs extends Fake implements AdminProgramRepository {
  int reads = 0;
  @override
  Future<bool> hasAccess() async {
    reads++;
    return true;
  }
}

class _Exercises extends Fake implements AdminExerciseRepository {}

class _Workouts extends Fake implements AdminWorkoutRepository {}

class _Guided extends Fake implements AdminGuidedRepository {}

class _Work extends Fake implements AdminGuidedWorkRepository {}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _passwords(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Contraseña actual'),
    'old-fixture',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nueva contraseña'),
    'long-fixture-passphrase',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Repetir nueva contraseña'),
    'long-fixture-passphrase',
  );
}

void main() {
  testWidgets(
    'abre el QR sin repetir contraseña y permite volver tras recargar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Security();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSecurityPage(repository: repo, onComplete: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contraseña actual'), findsNothing);
      await _tap(tester, 'Mostrar QR del autenticador');
      expect(repo.passwordChanges, 0);
      expect(repo.revokes, 1);
      expect(repo.enrolls, 1);
      expect(find.text('Código de seis cifras'), findsOneWidget);
      expect(repo.enables, 0);
      // Una recarga destruye el estado local: el acceso al QR sigue disponible.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSecurityPage(repository: repo, onComplete: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contraseña actual'), findsNothing);
      await _tap(tester, 'Mostrar QR del autenticador');
      expect(repo.passwordChanges, 0);
      expect(repo.enrolls, 2);
      expect(repo.enables, 0);
    },
  );
  testWidgets('no administrador no obtiene formularios ni configura factores', (
    tester,
  ) async {
    final repo = _Security()
      ..state = const AdminSecurityStatus(
        eligible: false,
        mfaRequired: false,
        assured: false,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminSecurityPage(repository: repo, onComplete: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Esta cuenta no tiene permiso de administración.'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(repo.enrolls, 0);
  });
  testWidgets(
    'cambia contraseña una vez, reintenta revocación y verifica antes de activar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Security()..failRevoke = true;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSecurityPage(
            repository: repo,
            onComplete: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Cambiar contraseña (opcional)');
      await _tap(tester, 'Cambiar contraseña');
      expect(repo.passwordChanges, 0);
      expect(find.textContaining('al menos 16'), findsOneWidget);
      await _passwords(tester);
      await _tap(tester, 'Cambiar contraseña');
      expect(repo.passwordChanges, 1);
      expect(repo.enrolls, 0);
      repo.failRevoke = false;
      await _tap(tester, 'Reintentar cierre de otras sesiones');
      expect(repo.passwordChanges, 1);
      await _tap(tester, 'Mostrar QR del autenticador');
      expect(repo.enrolls, 1);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.widgetWithText(
                  TextFormField,
                  'Clave de configuración',
                ),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      repo.failVerify = true;
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código de seis cifras'),
        '123456',
      );
      await _tap(tester, 'Activar protección y entrar');
      expect(completed, isFalse);
      expect(repo.enables, 0);
      repo.failVerify = false;
      await _tap(tester, 'Activar protección y entrar');
      expect(repo.enables, 1);
      expect(completed, isTrue);
    },
  );
  testWidgets(
    'un fallo al confirmar la obligación no vuelve a consumir el OTP verificado',
    (tester) async {
      final repo = _Security()
        ..state = const AdminSecurityStatus(
          eligible: true,
          mfaRequired: true,
          assured: false,
        )
        ..factors = ['factor']
        ..failEnable = true;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSecurityPage(
            repository: repo,
            onComplete: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contraseña actual'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código de seis cifras'),
        '123456',
      );
      await _tap(tester, 'Verificar y entrar');
      expect(completed, isFalse);
      expect(repo.verifies, 1);
      repo.failEnable = false;
      await _tap(tester, 'Verificar y entrar');
      expect(repo.verifies, 1);
      expect(repo.enables, 2);
      expect(completed, isTrue);
    },
  );
  testWidgets(
    'una URL privada se desvía a seguridad antes de leer el recurso',
    (tester) async {
      final programs = _Programs();
      final router = createAdminRouter(
        programs: programs,
        workouts: _Workouts(),
        exercises: _Exercises(),
        guided: _Guided(),
        guidedWork: _Work(),
        onSignOut: () {},
        isAuthenticated: () => true,
        initialLocation: '/guided-programs/work/private',
        needsSecurity: () async => true,
        securityBuilder: (_) =>
            const Scaffold(body: Text('Verifica tu acceso')),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/security');
      expect(find.text('Verifica tu acceso'), findsOneWidget);
      expect(programs.reads, 0);
    },
  );
  testWidgets('configuración desplazable con 320 px y texto 2x', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AdminSecurityPage(repository: _Security(), onComplete: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mostrar QR del autenticador'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Mostrar QR del autenticador').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'un fallo al cerrar sesiones no crea el factor ni pide contraseña',
    (tester) async {
      final repo = _Security()..failRevoke = true;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSecurityPage(repository: repo, onComplete: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Mostrar QR del autenticador');
      expect(repo.enrolls, 0);
      expect(repo.enables, 0);
      expect(repo.passwordChanges, 0);
      expect(find.text('Contraseña actual'), findsNothing);
      repo.failRevoke = false;
      await _tap(tester, 'Mostrar QR del autenticador');
      expect(repo.enrolls, 1);
      expect(repo.revokes, 2);
      expect(repo.passwordChanges, 0);
    },
  );
}
