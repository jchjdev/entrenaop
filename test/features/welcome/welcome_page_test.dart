import 'dart:async';

import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/welcome/domain/welcome_repository.dart';
import 'package:entrenaop/features/welcome/presentation/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';

import '../../support/account_auth_fixture.dart';

class WelcomeFixture implements WelcomeRepository {
  final completed = <String>{};
  int writes = 0;
  @override
  Future<bool> isCompleted(String userId) async => completed.contains(userId);
  @override
  Future<void> complete(String userId) async {
    writes++;
    completed.add(userId);
  }

  @override
  void skipForSession(String userId) => completed.add(userId);
}

void main() {
  testWidgets(
    'una cuenta nueva elige Herramientas y puede volver voluntariamente a la bienvenida',
    (tester) async {
      final account = AccountAuthFixture();
      final auth = account.cubit();
      final welcome = WelcomeFixture();
      await auth.checkCurrentUser();
      final router = AppRouter(auth, welcome: welcome);
      addTearDown(router.dispose);
      addTearDown(auth.close);
      addTearDown(account.changes.close);
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router.config,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿Por dónde\nempezamos?'), findsOneWidget);
      await tester.tap(find.text('Usar las herramientas'));
      await tester.pumpAndSettle();
      expect(router.config.routeInformationProvider.value.uri.path, '/tools');
      expect(welcome.writes, 1);
      expect(await welcome.isCompleted(account.user.id), isTrue);
      expect(find.text('Ritmos de carrera'), findsOneWidget);
      router.config.go('/welcome?review=1');
      await tester.pumpAndSettle();
      expect(find.text('¿Por dónde\nempezamos?'), findsOneWidget);
      expect(find.byTooltip('Volver'), findsOneWidget);
    },
  );

  testWidgets('espera la confirmación del guardado y evita acciones dobles', (
    tester,
  ) async {
    final pending = Completer<void>();
    final choices = <WelcomeDestination>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: WelcomePage(
          onChoose: (destination) async {
            choices.add(destination);
            await pending.future;
          },
          onContinueForNow: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Usar las herramientas'));
    await tester.pump();
    await tester.tap(find.text('Empezar a entrenar'));
    expect(choices, [WelcomeDestination.tools]);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'un fallo permite reintentar o seguir al destino sin fingir un guardado',
    (tester) async {
      WelcomeDestination? continued;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: WelcomePage(
            onChoose: (_) async => throw StateError('Sin red'),
            onContinueForNow: (destination) => continued = destination,
          ),
        ),
      );
      await tester.tap(find.text('Tengo una invitación'));
      await tester.pumpAndSettle();
      expect(continued, isNull);
      await tester.ensureVisible(find.text('Continuar por ahora'));
      await tester.tap(find.text('Continuar por ahora'));
      expect(continued, WelcomeDestination.trainer);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets(
    'omitir utiliza Inicio y la misma confirmación de no repetición',
    (tester) async {
      WelcomeDestination? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: WelcomePage(
            onChoose: (destination) async => chosen = destination,
            onContinueForNow: (_) {},
          ),
        ),
      );
      await tester.ensureVisible(find.text('Omitir y no volver a mostrar'));
      await tester.tap(find.text('Omitir y no volver a mostrar'));
      await tester.pumpAndSettle();
      expect(chosen, WelcomeDestination.training);
    },
  );

  testWidgets(
    '320 px y texto doble conservan los accesos sin desbordamientos',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WelcomePage(onChoose: (_) async {}, onContinueForNow: (_) {}),
        ),
      );
      await tester.ensureVisible(find.text('Tengo una invitación'));
      await tester.ensureVisible(find.text('Omitir y no volver a mostrar'));
      expect(tester.takeException(), isNull);
    },
  );
}
