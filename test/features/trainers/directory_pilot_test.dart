import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/directory/data.dart';
import 'package:trainer_access/directory/domain.dart';
import 'package:trainer_access/directory/policy.dart';

import 'trainer_directory_test.dart';

class _TwoCoaches extends FakeDirectory {
  String lastCity = '';
  @override
  Future<DirectoryPage> search({
    String query = '',
    DirectoryMode? mode,
    String city = '',
    bool favorites = false,
    String? after,
  }) async {
    lastCity = city;
    return DirectoryPage([
      for (final town in ['Zaragoza', 'Huesca'])
        if (city.isEmpty || city == town)
          DirectoryProfile(
            id: town,
            name: 'Preparador de $town',
            description: 'Carrera para oposiciones',
            specialties: const ['Carrera'],
            services: const ['Seguimiento'],
            mode: DirectoryMode.ambas,
            city: town,
            visibility: DirectoryVisibility.app,
          ),
    ], null);
  }
}

class _RpcCapture extends http.BaseClient {
  Map<String, dynamic>? body;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    body = jsonDecode(
      utf8.decode(await request.finalize().toBytes()),
    ) as Map<String, dynamic>;
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'profile': null,
            'revision': 2,
            'eligible': true,
            'published': true,
            'blocked': false,
            'consent': true,
            'enabled': true,
            'pilot_until': '2026-11-28T21:07:47Z',
            'web_allowed': false,
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  testWidgets('comparar preparadores y buscar por localidad desde la app', (
    tester,
  ) async {
    final repository = _TwoCoaches();
    await tester.pumpWidget(directory(repository));
    await tester.pumpAndSettle();
    expect(find.text('Preparador de Zaragoza'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Preparador de Huesca'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Preparador de Huesca'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Zona o localidad'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Zona o localidad'),
      'Zaragoza',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();
    expect(repository.lastCity, 'Zaragoza');
    expect(find.text('Preparador de Zaragoza'), findsOneWidget);
    expect(find.text('Preparador de Huesca'), findsNothing);
  });

  testWidgets('privacidad y condiciones accesibles a 320 píxeles y texto 2×', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: (directory(_TwoCoaches()) as MaterialApp).home,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacidad y condiciones del directorio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Responsable y contacto'), findsOneWidget);
    expect(
      find.textContaining('No se permiten suplantaciones'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  test(
    'publicar envía la versión aceptada y decodifica el permiso temporal',
    () async {
      final transport = _RpcCapture();
      final client = SupabaseClient(
        'https://pilot.invalid',
        'public-key',
        httpClient: transport,
      );
      addTearDown(client.dispose);
      final repository = SupabaseDirectoryRepository(client, owner: null);
      final result = await repository.save(
        sampleDirectoryProfile(),
        revision: 1,
        published: true,
        consent: true,
      );
      expect(
        (transport.body!['p_data'] as Map)['consent_version'],
        directoryConsentVersion,
      );
      expect(result.webAllowed, false);
      expect(result.pilotUntil, DateTime.utc(2026, 11, 28, 21, 7, 47));
    },
  );
}
