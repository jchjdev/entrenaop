import 'dart:convert';

import 'package:entrenaop_admin/features/programs/data/admin_builtin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_builtin_program_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Repository extends Fake implements AdminBuiltinProgramRepository {
  Repository({this.secondObjective = false});
  final bool secondObjective;
  int calls = 0;
  bool fail = false;
  @override
  Future<AdminBuiltinProgramData> load(String id) async {
    calls++;
    if (fail) throw StateError('network');
    return AdminBuiltinProgramData(
      programId: id,
      version: 'reference_v1',
      name: 'Catálogo oficial de ejemplo',
      sourceUrl: 'https://www.boe.es/referencia',
      effectiveFrom: '2027-01-01',
      standards: [
        const AdminBuiltinStandard(
          testId: 'run_2000_m',
          name: 'Carrera 2 km',
          unit: 'milliseconds',
          direction: 'lower',
          category: 'men',
          group: '17_25',
          threshold: 706000,
        ),
      ],
      objectives: [
        {
          'objective_key': 'circuit',
          'name': 'Circuito con condiciones',
          'instructions':
              'Mantener las condiciones oficiales al ejecutar el circuito.',
          'max_age_exclusive': 45,
          'profile_code': 'slalom_ball_course_16m',
          'profile_version': 1,
          'protocol_key': 'def_15_2026_agility',
          'protocol_version': 1,
          'parameters': {
            'condition': 'un_valor_largo_para_comprobar_el_ajuste_de_condiciones_sin_solapamientos',
          },
        },
        if (secondObjective)
          {
            'objective_key': 'plank',
            'name': 'Plancha abdominal',
            'instructions': 'Mantener la postura.',
            'profile_code': 'front_plank',
            'profile_version': 1,
            'protocol_key': 'plank_protocol',
            'protocol_version': 2,
            'parameters': <String, dynamic>{},
          },
      ],
    );
  }
}

void main() {
  test('milisegundos se presentan sin convertirlos en segundos enteros', () {
    AdminBuiltinStandard row(int n) => AdminBuiltinStandard(
      testId: 't',
      name: 't',
      unit: 'milliseconds',
      direction: 'lower',
      category: 'men',
      group: 'entry',
      threshold: n,
    );
    expect(row(40000).formattedThreshold, '40 s');
    expect(row(706000).formattedThreshold, '11:46 min');
    expect(row(65250).formattedThreshold, '1:05.25 min');
    expect(row(1200).formattedThreshold, '1.2 s');
  });
  testWidgets(
    'FAS consulta mínimos, distingue puntos completos y permite reintentar',
    (t) async {
      final repo = Repository()..fail = true;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              key: const PageStorageKey('program-sections-regression'),
              child: AdminBuiltinProgramPanel(
                programId: 'fas_periodic_assessment',
                repository: repo,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('no significa que la preparación esté vacía'),
        findsOneWidget,
      );
      repo.fail = false;
      await t.tap(find.text('Reintentar catálogo oficial'));
      await t.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.textContaining('no es la tabla completa'), findsOneWidget);
      expect(find.textContaining('reference_v1'), findsOneWidget);
      await t.tap(find.text('Carrera 2 km'));
      await t.pumpAndSettle();
      expect(
        find.text('Hombres · 17–25 años: hasta 11:46 min'),
        findsOneWidget,
      );
    },
  );
  testWidgets('consulta oficial cabe en 320 px con texto doble', (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            key: const PageStorageKey('program-sections-regression'),
            child: AdminBuiltinProgramPanel(
              programId: 'armed_forces_troop_entry',
              repository: Repository(),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Circuito con condiciones'));
    await t.tap(find.text('Circuito con condiciones'));
    await t.pumpAndSettle();
    expect(find.text('Aplicable antes de 45 años.'), findsOneWidget);
    expect(t.takeException(), isNull);
    expect(
      find.textContaining('Mínimos por prueba, sexo e hito'),
      findsOneWidget,
    );
  });
  for (final id in ['armed_forces_troop_entry', 'fas_periodic_assessment']) {
    testWidgets(
      '$id despliega condiciones con scroll persistente sin mezclar estados',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                key: PageStorageKey('program-sections-$id'),
                child: AdminBuiltinProgramPanel(
                  programId: id,
                  repository: Repository(secondObjective: true),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        Future<void> toggle(String title) async {
          await t.ensureVisible(find.text(title));
          await t.tap(find.text(title));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }

        await toggle('Circuito con condiciones');
        expect(find.text('Perfil slalom_ball_course_16m · v1'), findsOneWidget);
        expect(find.text('Perfil front_plank · v1'), findsNothing);
        await toggle('Plancha abdominal');
        expect(find.text('Perfil front_plank · v1'), findsOneWidget);
        expect(find.text('Perfil slalom_ball_course_16m · v1'), findsOneWidget);
        await toggle('Circuito con condiciones');
        expect(find.text('Perfil slalom_ball_course_16m · v1'), findsNothing);
        expect(find.text('Perfil front_plank · v1'), findsOneWidget);
        await toggle('Circuito con condiciones');
        expect(find.text('Protocolo def_15_2026_agility · v1'), findsOneWidget);
        expect(find.text('Protocolo plank_protocol · v2'), findsOneWidget);
        expect(find.textContaining('un_valor_largo'), findsOneWidget);
      },
    );
  }
  for (final fas in [false, true]) {
    test('repo consulta catálogo propio y pagina con orden estable, FAS $fas', () async {
      final reads = <Uri>[];
      final methods = <String>[];
      final client = SupabaseClient(
        'http://localhost',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          reads.add(request.url);
          methods.add(request.method);
          final path = request.url.path;
          Object value;
          if (path.endsWith('preparation_program_catalogs')) {
            value = {
              'catalog_version': 'catalog_v1',
              'assessment_catalogs': {
                'version': 'catalog_v1',
                'name': 'Oficial',
                'source_url': 'https://www.boe.es/test',
                'effective_from': '2027-01-01',
              },
            };
          } else if (path.endsWith('performance_legacy_objectives')) {
            value = [];
          } else {
            final offset = int.parse(
              request.url.queryParameters['offset'] ?? '0',
            );
            value = [
              for (var i = offset; i < (offset == 0 ? 500 : 501); i++)
                {
                  'test_id': 'test_$i',
                  'category': 'men',
                  fas ? 'age_band' : 'milestone': fas ? '17_25' : 'entry',
                  'threshold': 40000,
                  'physical_test_definitions': {
                    'id': 'test_$i',
                    'name': 'Prueba $i',
                    'unit': 'milliseconds',
                    'better_direction': 'higher',
                  },
                },
            ];
          }
          return http.Response(
            jsonEncode(value),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final id = fas ? 'fas_periodic_assessment' : 'armed_forces_troop_entry';
      final data = await SupabaseAdminBuiltinProgramRepository(client).load(id);
      expect(data.standards.length, 501);
      expect(methods.every((m) => m == 'GET'), isTrue);
      final standards = reads
          .where(
            (u) => u.path.endsWith(
              fas ? 'fas_periodic_standards' : 'assessment_standards',
            ),
          )
          .toList();
      expect(standards.length, 2);
      expect(standards.last.queryParameters['offset'], '500');
      expect(
        standards.first.queryParameters['order'],
        'test_id.asc.nullslast,category.asc.nullslast,${fas ? 'age_band' : 'milestone'}.asc.nullslast',
      );
      expect(
        standards.first.queryParameters['catalog_version'],
        'eq.catalog_v1',
      );
      expect(reads.first.queryParameters['program_id'], 'eq.$id');
    });
  }
}
