import 'dart:convert';

import 'package:entrenaop_trainer/main.dart';
import 'package:entrenaop_trainer/trainer_account_pages.dart';
import 'package:entrenaop_trainer/trainer_security_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_account_access_test.dart'
    show accountOwner, accountSession, accountUser;
import 'trainer_account_pages_test.dart' show AccountFixture;

class PortalAccountFixture {
  bool assured = false;
  final rpc = <String>[];
  late final client = SupabaseClient(
    'https://auth.example.invalid',
    'public',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final name = request.url.pathSegments.last;
      rpc.add(name);
      final Object response = name == 'token'
          ? accountSession(accountOwner)
          : name == 'user'
          ? accountUser(accountOwner)
          : name == 'get_trainer_security_status'
          ? assured
          : [];
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  Future<void> signIn() =>
      client.auth.setInitialSession(jsonEncode(accountSession(accountOwner)));
}

void main() {
  testWidgets('login abre registro y recuperación sin APK ni MFA', (t) async {
    final fixture = PortalAccountFixture();
    await t.runAsync(() async {
      await fixture.client.rpc('fixture_ready');
      fixture.rpc.clear();
    });
    addTearDown(() => t.runAsync(fixture.client.dispose));
    await t.pumpWidget(
      TrainerApp(client: fixture.client, accounts: AccountFixture()),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Crear cuenta'));
    await t.tap(find.text('Crear cuenta'));
    await t.pumpAndSettle();
    expect(find.text('Crea tu cuenta de EntrenaOP'), findsOneWidget);
    expect(find.byType(TrainerSecurityPage), findsNothing);
    await t.tap(find.byTooltip('Volver a entrar'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('He olvidado mi contraseña'));
    await t.tap(find.text('He olvidado mi contraseña'));
    await t.pumpAndSettle();
    expect(find.text('Recupera tu contraseña'), findsOneWidget);
    expect(fixture.rpc, isEmpty);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'sin alta profesional no carga panel, clientes ni solicita autenticador',
    (t) async {
      final fixture = PortalAccountFixture();
      await t.runAsync(() async {
        await fixture.client.rpc('fixture_ready');
        fixture.rpc.clear();
      });
      await fixture.signIn();
      addTearDown(() => t.runAsync(fixture.client.dispose));
      final accounts = AccountFixture();
      await t.pumpWidget(
        TrainerApp(client: fixture.client, accounts: accounts),
      );
      await t.pumpAndSettle();
      expect(find.byType(TrainerAccountPendingPage), findsOneWidget);
      expect(find.byType(TrainerSecurityPage), findsNothing);
      expect(fixture.rpc, isEmpty);
      accounts.professional = true;
      accounts.enabled = true;
      await t.tap(find.text('Comprobar acceso'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continuar al panel'));
      await t.pumpAndSettle();
      expect(find.byType(TrainerSecurityPage), findsOneWidget);
      expect(find.byType(TrainerPasswordUpdatePage), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'recuperar conserva MFA existente y no permite salir al panel antes de cambiar clave',
    (t) async {
      final fixture = PortalAccountFixture();
      await t.runAsync(() async {
        await fixture.client.rpc('fixture_ready');
        fixture.rpc.clear();
      });
      await fixture.signIn();
      addTearDown(() => t.runAsync(fixture.client.dispose));
      final accounts = AccountFixture()
        ..recoveryOwner = accountOwner
        ..needsMfa = true;
      await t.pumpWidget(
        TrainerApp(client: fixture.client, accounts: accounts),
      );
      await t.pumpAndSettle();
      expect(find.byType(TrainerSecurityPage), findsOneWidget);
      expect(find.byType(TrainerPasswordUpdatePage), findsNothing);
      final router = GoRouter.of(t.element(find.byType(TrainerSecurityPage)));
      fixture.assured = true;
      router.refresh();
      await t.pumpAndSettle();
      expect(find.byType(TrainerPasswordUpdatePage), findsOneWidget);
      router.go('/home');
      await t.pumpAndSettle();
      expect(find.byType(TrainerPasswordUpdatePage), findsOneWidget);
      expect(accounts.updates, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
}
