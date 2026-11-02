import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/notifications/notice_preferences.dart';
import 'package:entrenaop/features/notifications/push_notifications.dart';
import 'package:entrenaop/features/notifications/push_notifications_scope.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_help_page.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../notifications/push_notifications_test.dart' as fixture;

void main() {
  Future<GoRouter> mount(
    WidgetTester tester, {
    String initial = '/profile/settings/help',
    PushNotificationCoordinator? push,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/profile/settings/help',
          builder: (_, _) => const ProfileHelpPage(),
        ),
        GoRoute(
          path: '/profile/settings/notifications',
          builder: (_, _) => const ProfileNotificationsPage(),
        ),
        for (final route in [
          '/profile/settings',
          '/plan',
          '/library',
          '/profile/connections',
          '/pro/subscription',
          '/profile/settings/support',
        ])
          GoRoute(
            path: route,
            builder: (_, _) => Scaffold(body: Text('Destino $route')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: EntrenaTheme.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: PushNotificationsScope(coordinator: push, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  for (final topic in [
    (
      '¿Qué son la preparación y el plan adaptativo?',
      'Ver mi preparación',
      '/plan',
    ),
    ('¿Qué son los Programas?', 'Explorar Programas', '/library'),
    ('¿Puedo ver una sesión sin empezarla?', 'Ir a Entrenar', '/plan'),
    (
      '¿Qué ocurre si dejo de tener Pro?',
      'Ver EntrenaOP Pro',
      '/pro/subscription',
    ),
    ('¿Necesito un preparador?', 'Consultar mi preparación', '/plan'),
    (
      '¿Cómo conecto mis dispositivos?',
      'Ver dispositivos y conexiones',
      '/profile/connections',
    ),
  ]) {
    testWidgets(
      'la ayuda abre y regresa del destino ${topic.$2} a 320 px y texto 2×',
      (tester) async {
        final router = await mount(tester, scale: 2);
        await show(tester, find.text(topic.$1));
        await tester.tap(find.text(topic.$1));
        await tester.pumpAndSettle();
        await show(tester, find.text(topic.$2));
        expect(find.text(topic.$2).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(topic.$2));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, topic.$3);
        router.pop();
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/profile/settings/help');
      },
    );
  }

  testWidgets(
    'la ayuda abre soporte y permite volver a Ajustes desde entrada directa',
    (tester) async {
      final router = await mount(tester, scale: 2);
      await show(tester, find.text('Informar de un problema'));
      await tester.tap(find.text('Informar de un problema'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/settings/support');
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/settings');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sin servicio no se inventan interruptores de avisos y se explica a texto 2×',
    (tester) async {
      final router = await mount(
        tester,
        initial: '/profile/settings/notifications',
        scale: 2,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      await show(
        tester,
        find.text(
          'Los avisos del teléfono no están disponibles en esta instalación.',
        ),
      );
      expect(
        find.text(
          'Puedes seguir consultando tus sesiones y mensajes en la app.',
        ),
        findsOneWidget,
      );
      expect(find.text('Comprobar avisos'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/settings');
    },
  );

  testWidgets(
    'comprobar disponibilidad recupera el mismo coordinador de avisos',
    (tester) async {
      final backend = _Backend()..config = const PushConfiguration(false, null);
      final push = PushNotificationCoordinator(
        transport: fixture.Transport(),
        backend: backend,
        store: fixture.Store(),
        newId: () => 'binding',
      );
      addTearDown(push.dispose);
      await push.setAccount(fixture.a);
      await mount(
        tester,
        initial: '/profile/settings/notifications',
        push: push,
      );
      expect(
        find.text(
          'Los avisos del teléfono no están disponibles en este momento.',
        ),
        findsOneWidget,
      );
      backend.config = const PushConfiguration(true, 'push-fixture');
      await show(tester, find.text('Comprobar avisos'));
      await tester.tap(find.text('Comprobar avisos'));
      await tester.pumpAndSettle();
      expect(find.text('Avisos del preparador'), findsOneWidget);
      expect(find.byType(StudentPushSettings), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'los ajustes existentes activan y guardan recordatorios en el coordinador compartido',
    (tester) async {
      final backend = _Backend();
      final transport = fixture.Transport();
      final push = PushNotificationCoordinator(
        transport: transport,
        backend: backend,
        store: fixture.Store(),
        newId: () => 'binding',
      );
      addTearDown(push.dispose);
      await push.setAccount(fixture.a);
      await mount(
        tester,
        initial: '/profile/settings/notifications',
        push: push,
        scale: 2,
      );
      await show(tester, find.text('Avisos del preparador'));
      await tester.tap(find.text('Avisos del preparador'));
      await tester.pumpAndSettle();
      expect(push.enabled, isTrue);
      expect(transport.requests, 1);
      await show(tester, find.text('Recordatorios y descanso'));
      await tester.tap(find.text('Recordatorios y descanso'));
      await tester.pumpAndSettle();
      await show(tester, find.byType(DropdownButtonFormField<String>).first);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('El mismo día').last);
      await tester.pumpAndSettle();
      await show(tester, find.text('Guardar preferencias'));
      await tester.tap(find.text('Guardar preferencias'));
      await tester.pumpAndSettle();
      expect(backend.saved?.reminderMode, 'sameDay');
      expect(backend.saved?.timezone, 'Europe/Madrid');
      expect(push.preferences.reminderMode, 'sameDay');
      expect(tester.takeException(), isNull);
    },
  );
}

class _Backend extends fixture.Backend {
  NoticePreferences? saved;
  @override
  Future<NoticePreferences> savePreferences(
    PushAccount account,
    NoticePreferences value,
  ) async {
    saved = value;
    return value.copyWith(revision: value.revision + 1);
  }
}
