import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/profile/domain/app_support.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> show(WidgetTester tester, Finder target) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<GoRouter> mount(
    WidgetTester tester, {
    String initial = '/profile/settings/support',
    AppSupportResources resources = const AppSupportResources(),
    OpenSupportLink? openLink,
    Future<String> Function()? diagnostic,
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/profile/settings',
          builder: (_, _) =>
              ProfileSettingsPage(resources: resources, openLink: openLink),
        ),
        GoRoute(
          path: '/profile/settings/support',
          builder: (_, _) => ProfileSupportPage(
            resources: resources,
            openLink: openLink ?? (_) async => true,
            loadDiagnostic: diagnostic ?? () async => 'Diagnóstico de pruebas',
          ),
        ),
        for (final route in [
          '/profile',
          '/pro/subscription',
          '/profile/settings/help',
          '/profile/settings/notifications',
          '/privacy',
          '/terms',
        ])
          GoRoute(
            path: route,
            builder: (_, _) => Scaffold(body: Text(route)),
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
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  test('reportUri preserva Unicode, saltos, signos y destinatario sin convertir espacios en +', () {
    const resources = AppSupportResources();
    const text =
        'Fallo al añadir: sesión + fuerza & carrera #1?\nOtra línea con ñ.';
    final uri = resources.reportUri(
      '  $text  ',
      diagnostic: 'v1.2.3\niOS + prueba',
    );
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'ayuda@entrenaop.es');
    expect(uri.queryParameters['subject'], 'Ayuda con EntrenaOP');
    expect(
      uri.queryParameters['body'],
      '$text\n\nDatos de la instalación:\nv1.2.3\niOS + prueba',
    );
    expect(uri.query, contains('%20'));
    expect(uri.query, contains('%2B'));
    expect(uri.query, isNot(contains('+')));
    expect(resources.reportUri(text).queryParameters['body'], text);
  });

  testWidgets(
    'el formulario valida vacío y sólo prepara borrador sin diagnóstico por defecto',
    (tester) async {
      final opened = <Uri>[];
      var diagnostics = 0;
      await mount(
        tester,
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
        diagnostic: () async {
          diagnostics++;
          return 'No debería leerse';
        },
      );
      expect(opened, isEmpty);
      expect(diagnostics, 0);
      await show(tester, find.text('Preparar correo'));
      await tester.tap(find.text('Preparar correo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Cuéntanos el problema antes de preparar el correo.'),
        findsOneWidget,
      );
      expect(opened, isEmpty);
      await show(tester, find.byType(TextFormField));
      await tester.enterText(
        find.byType(TextFormField),
        '  La semana no se abre & conserva + texto  ',
      );
      await show(tester, find.text('Preparar correo'));
      await tester.tap(find.text('Preparar correo'));
      await tester.pumpAndSettle();
      expect(
        opened.single.queryParameters['body'],
        'La semana no se abre & conserva + texto',
      );
      expect(diagnostics, 0);
      expect(
        find.text(
          'Revisa el borrador en tu aplicación de correo y envíalo cuando quieras.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        contains('conserva + texto'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'diagnósticos sólo con consentimiento y fallo del launcher conserva texto y copia',
    (tester) async {
      final opened = <Uri>[];
      String? copied;
      var diagnostics = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(
        tester,
        openLink: (uri) async {
          opened.add(uri);
          return false;
        },
        diagnostic: () async {
          diagnostics++;
          return 'Versión: prueba\nPlataforma: ios';
        },
      );
      const message = 'No puedo consultar la sesión del jueves.';
      await tester.enterText(find.byType(TextFormField), message);
      expect(diagnostics, 0);
      await show(tester, find.text('Incluir datos de la instalación'));
      await tester.tap(find.text('Incluir datos de la instalación'));
      await tester.pumpAndSettle();
      expect(diagnostics, 0);
      expect(opened, isEmpty);
      await show(tester, find.text('Preparar correo'));
      await tester.tap(find.text('Preparar correo'));
      await tester.pumpAndSettle();
      expect(diagnostics, 1);
      expect(
        opened.single.queryParameters['body'],
        contains('Versión: prueba\nPlataforma: ios'),
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        message,
      );
      expect(
        find.textContaining('No hemos podido abrir tu aplicación de correo.'),
        findsOneWidget,
      );
      await show(tester, find.text('Copiar contacto y mensaje'));
      await tester.tap(find.text('Copiar contacto y mensaje'));
      await tester.pumpAndSettle();
      expect(copied, 'ayuda@entrenaop.es\n\n$message');
      expect(opened, hasLength(1));
      expect(diagnostics, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'un error al abrir el correo permite reintentar el mismo mensaje',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        openLink: (_) async {
          if (++calls == 1) throw StateError('Sin cliente de correo');
          return true;
        },
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Mensaje que se conserva',
      );
      await show(tester, find.text('Preparar correo'));
      await tester.tap(find.text('Preparar correo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Conservamos tu mensaje'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Mensaje que se conserva',
      );
      await show(tester, find.text('Preparar correo'));
      await tester.tap(find.text('Preparar correo'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.text(
          'Revisa el borrador en tu aplicación de correo y envíalo cuando quieras.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ajustes agrupa los recorridos reales y oculta destinos no configurados a 320 px 2×',
    (tester) async {
      final router = await mount(tester, initial: '/profile/settings');
      for (final title in [
        'Cuenta y Pro',
        'Ayuda',
        'Información',
        'Mi suscripción',
        'Notificaciones',
        'Preguntas frecuentes',
        'Informar de un problema',
        'Condiciones de uso',
        'Privacidad',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      for (final title in [
        'Instagram',
        'Valorar EntrenaOP',
        'Canjear código promocional',
      ]) {
        expect(find.text(title), findsNothing);
      }
      await show(tester, find.text('Privacidad'));
      await tester.tap(find.text('Privacidad'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/privacy');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ajustes abre sólo tras pulsar los enlaces HTTPS configurados', (
    tester,
  ) async {
    final links = [
      Uri.parse('https://www.instagram.com/entrenaop.test/'),
      Uri.parse('https://apps.apple.com/app/id123456'),
      Uri.parse(
        'https://apps.apple.com/redeem?ctx=offercodes&id=123456&code=PRUEBA',
      ),
    ];
    final opened = <Uri>[];
    await mount(
      tester,
      initial: '/profile/settings',
      resources: AppSupportResources(
        instagram: links[0],
        rating: links[1],
        promotion: links[2],
      ),
      openLink: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    expect(opened, isEmpty);
    for (final entry in [
      ('Instagram', links[0]),
      ('Valorar EntrenaOP', links[1]),
      ('Canjear código promocional', links[2]),
    ]) {
      await show(tester, find.text(entry.$1));
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(opened.last, entry.$2);
    }
    expect(opened, hasLength(3));
    expect(tester.takeException(), isNull);
  });
}
