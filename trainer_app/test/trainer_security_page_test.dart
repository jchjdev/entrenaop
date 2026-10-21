import 'package:entrenaop_trainer/trainer_security_page.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_security.dart';

class SecurityFake implements TrainerSecurity {
  bool verified = false;
  int calls = 0;
  bool fail = false;
  bool serverAssured = true;
  List<String> existing = ['existing-admin-totp'];
  @override
  Future<bool> assured() async => verified && serverAssured;
  @override
  Future<List<String>> factors() async => existing;
  @override
  Future<TrainerTotpSetup> enroll() async =>
      const TrainerTotpSetup('new', 'svg', 'manual-key');
  @override
  Future<void> verify(String factor, String code) async {
    calls++;
    expect(factor, existing.firstOrNull ?? 'new');
    if (fail) throw StateError('invalid-code');
    verified = true;
  }
}

void main() {
  testWidgets(
    'un OTP confirmado no se vuelve a consumir al fallar la consulta final',
    (tester) async {
      final security = SecurityFake()..serverAssured = false;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerSecurityPage(
            repository: security,
            onComplete: () => completed = true,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verificar y entrar'));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      security.serverAssured = true;
      await tester.tap(find.text('Verificar y entrar'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(security.calls, 1);
    },
  );
  testWidgets(
    'primera configuración muestra QR y clave, y no entra antes de verificar',
    (tester) async {
      final security = SecurityFake()..existing = [];
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerSecurityPage(
            repository: security,
            onComplete: () => completed = true,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurar autenticador'));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      expect(find.text('Escanea el QR desde el navegador.'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.scrollUntilVisible(find.byType(TextField), 250);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.text('Verificar y entrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verificar y entrar'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    },
  );
  testWidgets(
    'reutiliza factor existente, valida seis cifras y exige confirmación del servidor',
    (tester) async {
      final security = SecurityFake();
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerSecurityPage(
            repository: security,
            onComplete: () => completed = true,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Configurar autenticador'), findsNothing);
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Verificar y entrar'));
      await tester.pumpAndSettle();
      expect(security.calls, 0);
      security.fail = true;
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verificar y entrar'));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      security.fail = false;
      await tester.tap(find.text('Verificar y entrar'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    },
  );
}
