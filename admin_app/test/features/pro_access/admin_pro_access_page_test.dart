import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';
import 'package:entrenaop_admin/features/pro_access/presentation/admin_pro_access_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> searchAccount(
  WidgetTester tester,
  AdminProAccessRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: AdminProAccessPage(repository: repository)),
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Correo de una cuenta registrada'),
    'test@example.com',
  );
  await tester.tap(find.text('Buscar cuenta'));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'admin confirma un regalo temporal y lo retira conservando la cuenta',
    (tester) async {
      final repository = _Repository();
      await searchAccount(tester, repository);
      expect(repository.email, 'test@example.com');
      expect(find.text('Cuenta Free'), findsOneWidget);
      await press(tester, 'Conceder Pro gratuito');
      expect(repository.owner, isNull);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(repository.owner, 'owner');
      expect(repository.enabled, true);
      expect(repository.until!.isAfter(DateTime.now()), true);
      expect(find.text('Pro activo'), findsOneWidget);
      await press(tester, 'Retirar Pro gratuito');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(repository.enabled, false);
      expect(find.text('Cuenta Free'), findsOneWidget);
    },
  );
  testWidgets(
    'sin fecha de fin concede un regalo indefinido y permite cancelar la confirmación',
    (tester) async {
      final repository = _Repository();
      await searchAccount(tester, repository);
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<int>),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin fecha de fin').last);
      await tester.pumpAndSettle();
      await press(tester, 'Conceder Pro gratuito');
      expect(find.textContaining('hasta que lo retires'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(repository.owner, isNull);
      await press(tester, 'Conceder Pro gratuito');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(repository.enabled, true);
      expect(repository.until, isNull);
      expect(find.text('Activo sin fecha de fin.'), findsOneWidget);
    },
  );
  testWidgets('retirar el regalo conserva y muestra una suscripción vigente', (
    tester,
  ) async {
    final repository = _Repository()
      ..enabled = true
      ..paid = true;
    await searchAccount(tester, repository);
    expect(find.text('Suscripción de tienda · Mensual'), findsOneWidget);
    await press(tester, 'Retirar Pro gratuito');
    expect(
      find.textContaining('La suscripción vigente seguirá dando acceso Pro'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(repository.enabled, false);
    expect(find.text('Pro activo'), findsOneWidget);
    expect(find.text('Sin acceso gratuito vigente.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Retirar Pro gratuito'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('cambiar el correo descarta la cuenta resuelta', (tester) async {
    final repository = _Repository();
    await searchAccount(tester, repository);
    await tester.enterText(find.byType(TextField).first, 'other@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Conceder Pro gratuito'), findsNothing);
    expect(repository.owner, isNull);
  });
  testWidgets('gestión deshabilitada por servidor impide conceder y retirar', (
    tester,
  ) async {
    final repository = _Repository()
      ..management = false
      ..enabled = true;
    await searchAccount(tester, repository);
    await tester.scrollUntilVisible(
      find.text('Retirar Pro gratuito'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Cambiar Pro gratuito'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Retirar Pro gratuito'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('rechazo del servidor impide mostrar controles', (tester) async {
    final repository = _Repository()..denied = true;
    await searchAccount(tester, repository);
    expect(
      find.text('Solo administración puede gestionar Cuentas y Pro.'),
      findsOneWidget,
    );
    expect(find.text('Conceder Pro gratuito'), findsNothing);
  });
  test('la ficha separa regalos y compras aunque el regalo sea el acceso dominante', () {
    final value = AdminAccountAccess.fromJson({
      'user_id': 'owner',
      'tier': 'pro',
      'source': 'administrative_gift',
      'valid_until': null,
      'personal_exercises': 9,
      'personal_sessions': 5,
      'free_pro_active': true,
      'free_pro_valid_until': null,
      'gift_management_enabled': true,
      'subscription_active': true,
      'subscription_environment': 'SANDBOX',
      'subscription_product_identifier': 'entrenaop_pro_annual',
      'subscription_valid_until': '2026-12-01T00:00:00Z',
    });
    expect(value.freeProActive, true);
    expect(value.freeProValidUntil, isNull);
    expect(value.subscriptionActive, true);
    expect(value.subscriptionEnvironment, 'SANDBOX');
    expect(value.subscriptionValidUntil, isNotNull);
  });
}

class _Repository implements AdminProAccessRepository {
  String? email, owner;
  DateTime? until;
  bool enabled = false, denied = false, paid = false, management = true;
  AdminAccountAccess get account => AdminAccountAccess(
    userId: 'owner',
    isPro: enabled || paid,
    exercises: 9,
    sessions: 5,
    freeProActive: enabled,
    freeProValidUntil: enabled ? until : null,
    giftManagementEnabled: management,
    subscriptionActive: paid,
    subscriptionEnvironment: paid ? 'PRODUCTION' : null,
    subscriptionProduct: paid ? 'entrenaop_pro_monthly' : null,
    subscriptionValidUntil: paid ? DateTime.utc(2027, 1, 1) : null,
  );
  @override
  Future<AdminAccountAccess> find(String email) async {
    this.email = email;
    if (denied) {
      throw const PostgrestException(
        message: 'Solo administración puede gestionar Cuentas y Pro.',
        code: '42501',
      );
    }
    return account;
  }

  @override
  Future<AdminAccountAccess> setAccess(
    String userId, {
    required bool enabled,
    DateTime? validUntil,
    required String reason,
  }) async {
    owner = userId;
    this.enabled = enabled;
    until = validUntil;
    return account;
  }
}
