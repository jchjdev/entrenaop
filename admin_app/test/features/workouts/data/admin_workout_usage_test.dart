import 'dart:convert';

import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final requests = <Uri>[];
  var failUsages = false;
  late SupabaseClient client;
  late SupabaseAdminWorkoutRepository repository;

  setUp(() {
    requests.clear();
    failUsages = false;
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        final table = request.url.pathSegments.last;
        Object rows = [];
        switch (table) {
          case 'program_workout_templates':
            rows = [
              {'template_id': 'used'},
              {'template_id': 'unused'},
            ];
          case 'workout_templates':
            rows = [
              for (final id in ['used', 'unused'])
                {'id': id, 'name': id, 'status': 'published', 'version': 1},
            ];
          case 'workout_blocks':
            rows = [
              {'template_id': 'used', 'format': 'warm_up'},
              {'template_id': 'used', 'format': 'straight_sets'},
              {'template_id': 'unused', 'format': 'running'},
            ];
          case 'guided_program_links':
            if (failUsages) {
              return http.Response(
                jsonEncode({'message': 'Sin acceso'}),
                403,
                request: request,
              );
            }
            rows = [
              for (final id in [
                'published-v1',
                'published-v1',
                'draft-v2',
                'old',
              ])
                {
                  'template_id': 'used',
                  'program': {
                    'id': id,
                    'name': 'Programa compartido',
                    'version': id == 'draft-v2' ? 2 : 1,
                    'status': id == 'draft-v2'
                        ? 'draft'
                        : id == 'old'
                        ? 'archived'
                        : 'published',
                  },
                },
            ];
        }
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabaseAdminWorkoutRepository(client);
  });
  tearDown(() => client.dispose());

  test(
    'las opciones de calentamiento y descanso se derivan de los bloques reales',
    () async {
      final sessions = await repository.listGeneral();
      expect(sessions.first.hasWarmup, isTrue);
      expect(sessions.first.supportsAdjustableRest, isTrue);
      expect(sessions.first.isRunning, isFalse);
      expect(sessions.last.hasWarmup, isFalse);
      expect(sessions.last.supportsAdjustableRest, isFalse);
      expect(sessions.last.isRunning, isTrue);
    },
  );

  test(
    'deduplica fases por versión sin ocultar borradores ni retirados',
    () async {
      final sessions = await repository.listGeneral();
      final usages = sessions.first.guidedPrograms;
      expect(usages, hasLength(3));
      expect(usages.map((p) => p.id).toSet(), {
        'published-v1',
        'draft-v2',
        'old',
      });
      expect(usages.first.version, 2);
      expect(usages.map((p) => p.status).toSet(), {
        'published',
        'draft',
        'archived',
      });
      expect(sessions.last.guidedPrograms, isEmpty);
      final query = requests
          .where((u) => u.path.endsWith('/guided_program_links'))
          .single;
      expect(query.queryParameters['template_id'], contains('used'));
      expect(query.queryParameters['template_id'], contains('unused'));
      expect(
        query.queryParameters['select'],
        contains('guided_programs!inner'),
      );
      expect(query.queryParameters['select'], contains('name:content->>name'));
    },
  );

  test('un fallo de usos no se interpreta como sesión sin programas', () async {
    failUsages = true;
    await expectLater(
      repository.listGeneral(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'las sesiones privadas de preparación no consultan programas guiados',
    () async {
      final sessions = await repository.listForProgram('preparation');
      expect(sessions.every((s) => s.guidedPrograms.isEmpty), isTrue);
      expect(
        requests.any((u) => u.path.endsWith('/guided_program_links')),
        isFalse,
      );
    },
  );
}
