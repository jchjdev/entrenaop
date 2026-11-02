import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/directory/data.dart';
import 'package:trainer_access/directory/domain.dart';
import 'package:trainer_access/directory/locations.dart';

import 'trainer_directory_test.dart';

class _Transport extends http.BaseClient {
  final bodies = <Map<String, dynamic>>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    bodies.add(
      jsonDecode(utf8.decode(await request.finalize().toBytes()))
          as Map<String, dynamic>,
    );
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'items': [
              {
                'id': 'coach',
                'name': 'Ervi',
                'description': 'Carrera',
                'specialties': ['Carrera'],
                'services': ['Seguimiento'],
                'mode': 'ambas',
                'city': 'Telde',
                'province_code': '35',
                'island': 'Gran Canaria',
                'visibility': 'app',
                'email': 'coach@example.test',
                'website': '',
                'whatsapp': '',
                'price': '',
                'accepting': true,
              },
            ],
            'next': null,
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
  test('catálogo completo y provincias de ambos archipiélagos', () {
    expect(directoryProvinces.map((p) => p.code).toSet(), {
      for (var i = 1; i <= 52; i++) i.toString().padLeft(2, '0'),
    });
    expect(directoryProvince('51')!.name, 'Ceuta');
    expect(directoryProvince('52')!.name, 'Melilla');
    expect(directoryProvince('07')!.islands, contains('Mallorca'));
    expect(
      directoryProvince('35')!.islands,
      containsAll(['Gran Canaria', 'La Graciosa']),
    );
    expect(directoryProvince('38')!.islands, contains('Tenerife'));
  });

  test('localidad opcional y ninguna isla fuera de su provincia', () {
    final provinceOnly = sampleDirectoryProfile(
      provinceCode: '35',
      mode: DirectoryMode.presencial,
    );
    expect(provinceOnly.locationLabel, 'Las Palmas');
    expect(provinceOnly.validate(publishing: true, consent: true), isNull);
    expect(
      sampleDirectoryProfile(
        provinceCode: '35',
        island: 'Gran Canaria',
        city: 'Telde',
      ).locationLabel,
      'Telde · Gran Canaria · Las Palmas',
    );
    expect(
      sampleDirectoryProfile(
        provinceCode: '28',
        island: 'Gran Canaria',
      ).validate(publishing: false, consent: false),
      contains('isla'),
    );
    expect(
      sampleDirectoryProfile(provinceCode: '99')
          .validate(publishing: false, consent: false),
      contains('provincia'),
    );
    expect(sampleDirectoryProfile(city: 'Telde').locationLabel, 'Telde');
  });

  test(
    'adaptador conserva búsqueda libre y decodifica provincia e isla',
    () async {
      final transport = _Transport();
      final client = SupabaseClient(
        'https://example.test',
        'public-test-key',
        httpClient: transport,
      );
      addTearDown(client.dispose);
      final repository = SupabaseDirectoryRepository(client, owner: null);
      final page = await repository.search(city: '  gran CANARIA  ');
      expect(transport.bodies.single['p_city'], 'gran CANARIA');
      expect(page.items.single.provinceCode, '35');
      expect(
        page.items.single.locationLabel,
        'Telde · Gran Canaria · Las Palmas',
      );
    },
  );

  testWidgets(
    'buscador permite escribir provincia o isla sin elegir localidad',
    (tester) async {
      await tester.pumpWidget(directory(FakeDirectory()));
      await tester.pumpAndSettle();
      final location = find.widgetWithText(
        TextField,
        'Provincia, isla o localidad',
      );
      await tester.enterText(location, 'Gran Canaria');
      expect(find.text('Gran Canaria'), findsOneWidget);
      expect(
        find.text('Puedes buscar solo por provincia o por parte del nombre.'),
        findsOneWidget,
      );
    },
  );
}
