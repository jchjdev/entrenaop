import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/preparation_goal/data/repositories/preparation_training_repository_impl.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Free consulta estados con GET sin ejecutar la RPC que avanza semanas',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <String>[];
      server.listen((request) async {
        requests.add('${request.method} ${request.uri.path}');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {
              'id': 'saved-goal',
              'preparation_programs': {'name': 'Preparación guardada'},
              'adaptive_program_states': {
                'status': 'training',
                'message': 'En curso',
                'last_generated_week': '2026-10-05',
                'next_generation_on': '2026-10-12',
              },
            },
            {
              'id': 'draft',
              'preparation_programs': {'name': 'Por configurar'},
              'adaptive_program_states': null,
            },
          ]),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'public-test-key',
      );
      addTearDown(client.dispose);
      final repository = SupabasePreparationTrainingRepository(
        client,
        readOnlyPreview: () => true,
      );
      final programs = await repository.refreshPrograms();
      expect(requests, ['GET /rest/v1/preparation_goals']);
      expect(programs.first.status, 'training');
      expect(programs.first.currentWeek, DateTime(2026, 10, 5));
      expect(programs.last.status, 'draft');
    },
  );

  test('la simulación Free rechaza calcular, activar y pausar antes de usar la red', () async {
    final client = SupabaseClient(
      'https://no-network.invalid',
      'public-test-key',
    );
    addTearDown(client.dispose);
    final repository = SupabasePreparationTrainingRepository(
      client,
      readOnlyPreview: () => true,
    );
    final denied = throwsA(isA<PreparationTrainingException>());
    await expectLater(
      repository.calculate('goal', DateTime(2026, 10, 5)),
      denied,
    );
    await expectLater(
      repository.activate('goal', DateTime(2026, 10, 5), {}),
      denied,
    );
    await expectLater(repository.pause('goal'), denied);
  });
}
