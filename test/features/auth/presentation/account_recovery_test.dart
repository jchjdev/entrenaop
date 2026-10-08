import 'dart:async';

import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/account_auth_fixture.dart';

void main() {
  test(
    'una respuesta de acceso tardía no restaura una sesión que ya terminó',
    () async {
      final repo = AccountAuthFixture()..pendingSignIn = Completer<void>();
      final auth = repo.cubit()..watchAuthState();
      addTearDown(repo.changes.close);
      addTearDown(auth.close);
      final signIn = auth.signIn(
        email: 'persona@example.com',
        password: 'clave-ficticia',
      );
      repo.changes.add(const AuthSessionChange(null));
      await Future<void>.delayed(Duration.zero);
      repo.pendingSignIn!.complete();
      await signIn;
      expect(auth.state, isA<AuthUnauthenticated>());
    },
  );
  test(
    'el enlace validado prevalece sobre consulta inicial y renovación',
    () async {
      final repo = AccountAuthFixture();
      final auth = repo.cubit()..watchAuthState();
      addTearDown(repo.changes.close);
      addTearDown(auth.close);
      repo.recover();
      await Future<void>.delayed(Duration.zero);
      await auth.checkCurrentUser();
      expect(auth.state, isA<AuthPasswordRecovery>());
      await auth.updateRecoveredPassword('otra-clave-segura');
      repo.recover();
      await Future<void>.delayed(Duration.zero);
      expect((auth.state as AuthPasswordRecovery).passwordUpdated, true);
      await auth.finishPasswordRecovery();
      expect(auth.state, isA<AuthUnauthenticated>());
    },
  );
  test('una URL por sí sola no habilita el cambio de contraseña', () async {
    final repo = AccountAuthFixture();
    final auth = repo.cubit();
    addTearDown(repo.changes.close);
    addTearDown(auth.close);
    await auth.updateRecoveredPassword('una-clave-segura');
    expect(repo.updateCalls, 0);
  });
  test('cambiar cuenta descarta una respuesta de guardado anterior', () async {
    final repo = AccountAuthFixture()..pendingUpdate = Completer<void>();
    final auth = repo.cubit()..watchAuthState();
    addTearDown(repo.changes.close);
    addTearDown(auth.close);
    repo.recover();
    await Future<void>.delayed(Duration.zero);
    final save = auth.updateRecoveredPassword('una-clave-segura');
    repo.recover(id: 'otra-cuenta');
    await Future<void>.delayed(Duration.zero);
    repo.pendingUpdate!.complete();
    await save;
    final state = auth.state as AuthPasswordRecovery;
    expect(state.userId, 'otra-cuenta');
    expect(state.passwordUpdated, false);
  });
  test(
    'evita envíos simultáneos y conserva el intervalo al cambiar pantalla',
    () async {
      final repo = AccountAuthFixture()..pendingEmail = Completer<void>();
      final auth = repo.cubit();
      addTearDown(auth.close);
      addTearDown(repo.changes.close);
      final first = auth.requestPasswordReset('persona@example.com');
      await auth.requestPasswordReset('persona@example.com');
      expect(repo.resetCalls, 1);
      repo.pendingEmail!.complete();
      await first;
      auth.dismissAccountNotice();
      await auth.resendConfirmation('persona@example.com');
      expect(repo.resendCalls, 0);
      expect((auth.state as AuthEmailConfirmationRequired).retryAt, isNotNull);
    },
  );
  test(
    'descarta un envío de correo tardío tras abrir la recuperación',
    () async {
      final repo = AccountAuthFixture()..pendingEmail = Completer<void>();
      final auth = repo.cubit()..watchAuthState();
      addTearDown(auth.close);
      addTearDown(repo.changes.close);
      final send = auth.requestPasswordReset('persona@example.com');
      repo.recover();
      await Future<void>.delayed(Duration.zero);
      repo.pendingEmail!.complete();
      await send;
      expect(auth.state, isA<AuthPasswordRecovery>());
    },
  );
  testWidgets(
    'solicitud conserva correo/error y muestra instrucciones persistentes',
    (tester) async {
      final repo = AccountAuthFixture()..failEmail = true;
      final (auth, router) = await _mount(tester, repo, '/');
      await tester.enterText(
        find.byType(TextFormField).first,
        'persona@example.com',
      );
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      expect(_path(router), '/forgot-password');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'persona@example.com',
      );
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sin conexión.'), findsOneWidget);
      repo.failEmail = false;
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.textContaining('Si existe una cuenta'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(auth.state, isA<AuthPasswordResetRequest>());
    },
  );
  testWidgets(
    'alta sin sesión y acceso sin confirmar llevan a confirmación estable',
    (tester) async {
      final repo = AccountAuthFixture()..emailNotConfirmed = true;
      final (auth, router) = await _mount(tester, repo, '/sign-up');
      await auth.signUp(
        email: 'persona@example.com',
        password: 'clave-segura',
        fullName: 'Persona',
      );
      await tester.pumpAndSettle();
      expect(_path(router), '/confirm-email');
      expect(find.text('Confirma tu correo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Confirma tu correo'), findsOneWidget);
      await auth.resendConfirmation('persona@example.com');
      await tester.pumpAndSettle();
      expect(find.textContaining('recibirás un nuevo correo'), findsOneWidget);
      await tester.tap(find.text('Volver al acceso'));
      await tester.pumpAndSettle();
      await auth.signIn(email: 'persona@example.com', password: 'clave-segura');
      await tester.pumpAndSettle();
      expect(_path(router), '/confirm-email');
    },
  );
  testWidgets(
    'recuperación protege la ruta, reintenta y borra campos tras guardar',
    (tester) async {
      final repo = AccountAuthFixture()..failUpdate = true;
      final (auth, router) = await _mount(tester, repo, '/');
      repo.recover();
      await tester.pumpAndSettle();
      expect(_path(router), '/reset-password');
      router.config.go('/home');
      await tester.pumpAndSettle();
      expect(_path(router), '/reset-password');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'nueva-clave-segura',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'otra');
      await tester.tap(find.text('Guardar nueva contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(repo.updateCalls, 0);
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nueva-clave-segura',
      );
      await tester.tap(find.text('Guardar nueva contraseña'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se ha podido guardar.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'nueva-clave-segura',
      );
      repo.failUpdate = false;
      await tester.tap(find.text('Guardar nueva contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      await tester.tap(find.text('Ir al acceso'));
      await tester.pumpAndSettle();
      expect(_path(router), '/');
      expect(auth.state, isA<AuthUnauthenticated>());
      expect(repo.finishCalls, 1);
    },
  );
  testWidgets(
    'un enlace caducado ofrece recuperación sin permitir editar contraseña',
    (tester) async {
      final repo = AccountAuthFixture();
      final (_, router) = await _mount(tester, repo, '/reset-password');
      expect(find.text('Necesitas un enlace nuevo'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      repo.changes.addError(const AuthLinkException());
      await tester.pumpAndSettle();
      expect(_path(router), '/auth-link-error');
      expect(find.textContaining('ha caducado'), findsOneWidget);
      await tester.tap(find.text('Solicitar enlace de recuperación'));
      await tester.pumpAndSettle();
      expect(_path(router), '/forgot-password');
    },
  );
}

String _path(AppRouter router) =>
    router.config.routeInformationProvider.value.uri.path;
Future<(AuthCubit, AppRouter)> _mount(
  WidgetTester tester,
  AccountAuthFixture repo,
  String path,
) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final auth = repo.cubit()..watchAuthState();
  repo.changes.add(const AuthSessionChange(null));
  final router = AppRouter(auth);
  addTearDown(router.dispose);
  addTearDown(auth.close);
  addTearDown(repo.changes.close);
  router.config.go(path);
  await tester.pumpWidget(
    BlocProvider.value(
      value: auth,
      child: MaterialApp.router(
        theme: EntrenaTheme.dark,
        routerConfig: router.config,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (auth, router);
}
