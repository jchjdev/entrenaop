import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';
import 'package:entrenaop_admin/features/pro_access/presentation/admin_pro_access_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'admin busca, concede y retira acceso de prueba de la cuenta elegida',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(home: AdminProAccessPage(repository: repository)),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Correo de una cuenta registrada'),
        'test@example.com',
      );
      await tester.tap(find.text('Buscar cuenta'));
      await tester.pumpAndSettle();
      expect(repository.email, 'test@example.com');
      expect(find.text('Cuenta Free'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Conceder Pro de prueba'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conceder Pro de prueba'));
      await tester.pumpAndSettle();
      expect(repository.owner, 'owner');
      expect(repository.days, 30);
      expect(repository.enabled, true);
      expect(find.text('Pro activo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Retirar Pro de prueba'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar Pro de prueba'));
      await tester.pumpAndSettle();
      expect(repository.enabled, false);
      expect(find.text('Cuenta Free'), findsOneWidget);
    },
  );
  testWidgets(
    'cambiar el correo descarta la cuenta resuelta para evitar modificar otra',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(home: AdminProAccessPage(repository: repository)),
      );
      await tester.enterText(find.byType(TextField).first, 'first@example.com');
      await tester.tap(find.text('Buscar cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'other@example.com');
      await tester.pumpAndSettle();
      expect(find.text('Conceder Pro de prueba'), findsNothing);
      expect(repository.owner, isNull);
    },
  );
  testWidgets('rechazo del servidor impide mostrar controles de concesión', (
    tester,
  ) async {
    final repository = _Repository()..denied = true;
    await tester.pumpWidget(
      MaterialApp(home: AdminProAccessPage(repository: repository)),
    );
    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.tap(find.text('Buscar cuenta'));
    await tester.pumpAndSettle();
    expect(
      find.text('Solo administración puede gestionar cuentas de prueba.'),
      findsOneWidget,
    );
    expect(find.text('Conceder Pro de prueba'), findsNothing);
  });
}

class _Repository implements AdminProAccessRepository {
  String? email, owner;
  int? days;
  bool enabled = false, denied = false;
  DevelopmentAccountAccess get account => DevelopmentAccountAccess(
    userId: 'owner',
    isPro: enabled,
    exercises: 9,
    sessions: 5,
    validUntil: enabled ? DateTime.utc(2026, 11, 10) : null,
  );
  @override
  Future<DevelopmentAccountAccess> find(String email) async {
    this.email = email;
    if (denied) {
      throw const PostgrestException(
        message: 'Solo administración puede gestionar cuentas de prueba.',
        code: '42501',
      );
    }
    return account;
  }

  @override
  Future<DevelopmentAccountAccess> setAccess(
    String userId, {
    required bool enabled,
    required int days,
    required String reason,
  }) async {
    owner = userId;
    this.enabled = enabled;
    this.days = days;
    return account;
  }
}
