import 'package:entrenaop_trainer/trainer_account_access.dart';
import 'package:entrenaop_trainer/trainer_account_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AccountFixture implements TrainerAccountAccess {
  final registered = <(String, String, String)>[];
  int recoveries = 0, resends = 0, updates = 0, finishes = 0;
  bool professional = false, enabled = false, needsMfa = false;
  @override
  String? recoveryOwner;
  @override
  String? get email => 'ana@example.invalid';
  @override
  bool get recovering => recoveryOwner != null;
  @override
  bool get linkFailed => false;
  @override
  Future<void> register(String name, String email, String password) async {
    registered.add((name, email, password));
  }

  @override
  Future<void> resend(String email) async {
    resends++;
  }

  @override
  Future<void> recover(String email) async {
    recoveries++;
  }

  @override
  Future<TrainerAccountStatus> status() async =>
      TrainerAccountStatus(professionalAccount: professional, enabled: enabled);
  @override
  Future<bool> recoveryNeedsMfa() async => needsMfa;
  @override
  Future<void> updatePassword(String password) async {
    updates++;
  }

  @override
  Future<void> finishRecovery() async {
    finishes++;
    recoveryOwner = null;
  }

  @override
  Future<void> rememberRecovery(String owner) async {
    recoveryOwner = owner;
  }

  @override
  Future<void> clearRecovery() async {
    recoveryOwner = null;
  }
}

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('registro web valida y confirma envío sin pedir APK a $width', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final fixture = AccountFixture();
      await t.pumpWidget(
        MaterialApp(
          home: TrainerAccountFormPage(
            accounts: fixture,
            mode: TrainerAccountForm.register,
          ),
        ),
      );
      await t.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await t.enterText(fields.at(0), 'Ana Soria');
      await t.enterText(fields.at(1), 'ana@example.invalid');
      await t.enterText(fields.at(2), 'password-strong');
      await t.enterText(fields.at(3), 'different');
      await t.ensureVisible(find.text('Crear cuenta'));
      await t.tap(find.text('Crear cuenta'));
      await t.pumpAndSettle();
      expect(fixture.registered, isEmpty);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      await t.enterText(fields.at(3), 'password-strong');
      await t.ensureVisible(find.text('Crear cuenta'));
      await t.tap(find.text('Crear cuenta'));
      await t.pumpAndSettle();
      expect(fixture.registered, [
        ('Ana Soria', 'ana@example.invalid', 'password-strong'),
      ]);
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'recuperación y reenvío tienen respuesta genérica y evitan altas',
    (t) async {
      final fixture = AccountFixture();
      for (final mode in [
        TrainerAccountForm.recover,
        TrainerAccountForm.confirm,
      ]) {
        await t.pumpWidget(
          MaterialApp(
            home: TrainerAccountFormPage(
              key: ValueKey(mode),
              accounts: fixture,
              mode: mode,
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextFormField), 'ana@example.invalid');
        await t.tap(
          find.text(
            mode == TrainerAccountForm.recover
                ? 'Enviar enlace de recuperación'
                : 'Reenviar confirmación',
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Revisa tu correo'), findsOneWidget);
      }
      expect(fixture.recoveries, 1);
      expect(fixture.resends, 1);
      expect(fixture.registered, isEmpty);
    },
  );
  testWidgets(
    'pendiente no tiene acceso a panel; detecta habilitación posterior',
    (t) async {
      final fixture = AccountFixture();
      await t.pumpWidget(
        MaterialApp(
          home: TrainerAccountPendingPage(
            accounts: fixture,
            onSignOut: () async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Continuar al panel'), findsNothing);
      expect(find.textContaining('pendiente de habilitación'), findsOneWidget);
      fixture.professional = true;
      fixture.enabled = true;
      await t.tap(find.text('Comprobar acceso'));
      await t.pumpAndSettle();
      expect(find.text('Continuar al panel'), findsOneWidget);
    },
  );
  testWidgets('cambiar contraseña valida y limpia los campos al confirmar', (
    t,
  ) async {
    final fixture = AccountFixture()..recoveryOwner = 'owner';
    await t.pumpWidget(
      MaterialApp(home: TrainerPasswordUpdatePage(accounts: fixture)),
    );
    await t.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'new-password');
    await t.enterText(fields.at(1), 'new-password');
    await t.tap(find.text('Guardar contraseña'));
    await t.pumpAndSettle();
    expect(fixture.updates, 1);
    expect(find.text('Contraseña actualizada'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
