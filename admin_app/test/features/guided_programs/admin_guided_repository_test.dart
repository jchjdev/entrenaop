import 'dart:convert';
import 'dart:io';

import 'package:entrenaop_admin/features/guided_programs/data/supabase_admin_guided_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/guided_program.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseAdminGuidedRepository repository;
  final payloads = <Map<String, dynamic>>[];
  String? failCode;
  setUp(() async {
    payloads.clear();
    failCode = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'POST') {
        payloads.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        if (failCode != null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(
            jsonEncode({'code': failCode, 'message': 'Conflicto de catálogo'}),
          );
        } else {
          request.response.write(jsonEncode('saved-id'));
        }
      } else {
        request.response.write(
          jsonEncode({
            'id': 'saved-id',
            'name': 'Fuerza inicial',
            'is_active': false,
            'revision': 2,
          }),
        );
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = SupabaseAdminGuidedRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('guarda receta y clasificación en una sola llamada, fuera del JSON deportivo', () async {
    await repository.save(
      const GuidedProgram(
        name: 'Fuerza',
        mode: GuidedProgramMode.guide,
        categories: [GuidedProgramCategory(id: 'category', name: 'Fuerza')],
        primaryCategoryId: 'category',
        phases: [
          GuidedPhase(
            name: 'Trabajo',
            sessions: [GuidedSession(templateId: 'template', name: 'Trabajo')],
          ),
        ],
      ),
      id: 'original',
    );
    expect(payloads, hasLength(1));
    expect(payloads.single['p_id'], 'original');
    expect(payloads.single['p_category_ids'], ['category']);
    expect(payloads.single['p_primary_category_id'], 'category');
    expect(
      (payloads.single['p_content'] as Map).containsKey('categories'),
      isFalse,
    );
  });
  test('editar una categoría conserva identidad y exige su revisión', () async {
    final result = await repository.saveCategory(
      'Fuerza inicial',
      active: false,
      original: const GuidedProgramCategory(id: 'category', name: 'Fuerza'),
    );
    expect(payloads.single['p_id'], 'category');
    expect(payloads.single['p_expected_revision'], 1);
    expect(payloads.single['p_active'], isFalse);
    expect(result.name, 'Fuerza inicial');
    expect(result.revision, 2);
    expect(result.active, isFalse);
  });
  for (final code in ['23505', '40001']) {
    test(
      'traduce el conflicto $code en una corrección útil para el editor',
      () async {
        failCode = code;
        await expectLater(
          repository.saveCategory('FUERZA'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'mensaje',
              contains(code == '23505' ? 'Ya existe' : 'Recarga'),
            ),
          ),
        );
      },
    );
  }
}
