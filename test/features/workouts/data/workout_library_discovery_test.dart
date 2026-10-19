import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource_impl.dart';
import 'package:entrenaop/features/workouts/presentation/workout_library_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/workout_template_model.dart';

void main() {
  test(
    'el listado filtra la elección editorial y busca los ejercicios anidados',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <Uri>[];
      server.listen((request) async {
        requests.add(request.uri);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {
              'id': 'session',
              'name': 'Festival',
              'description': null,
              'estimated_duration_minutes': 30,
              'origin': 'system',
              'version': 1,
              'workout_blocks': [
                {
                  'format': 'amrap',
                  'workout_items': [
                    {
                      'exercises': {'name': 'Dominadas'},
                    },
                    {
                      'exercises': {'name': 'Elevación de glúteos'},
                    },
                    {
                      'exercises': {'name': 'Dominadas'},
                    },
                    {'exercises': null},
                  ],
                },
              ],
            },
          ]),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'anon-test',
      );
      addTearDown(client.dispose);
      final rows = await WorkoutRemoteDataSourceImpl(supabaseClient: client)
          .getPublicTemplates();
      expect(requests.single.queryParameters['show_in_library'], 'eq.true');
      expect(requests.single.queryParameters['status'], 'eq.published');
      expect(
        requests.single.queryParameters['select'],
        contains('workout_items(exercises(name))'),
      );
      final summary = WorkoutTemplateSummaryModel.fromJson(rows.single);
      expect(summary.exerciseNames, ['Dominadas', 'Elevación de glúteos']);
      expect(
        const WorkoutLibraryFilter(query: 'DOMINADAS gluteos festival')
            .matches(summary),
        isTrue,
      );
      expect(
        const WorkoutLibraryFilter(query: 'sentadilla').matches(summary),
        isFalse,
      );
      expect(
        const WorkoutLibraryFilter(
          query: 'dominadas',
          duration: LibrarySessionDuration.short,
        ).matches(summary),
        isFalse,
      );
    },
  );

  test(
    'los resúmenes antiguos siguen siendo legibles sin nombres de ejercicios',
    () {
      final summary = WorkoutTemplateSummaryModel.fromJson({
        'id': 'old',
        'name': 'Antigua',
        'description': null,
        'estimated_duration_minutes': null,
        'origin': 'user',
        'version': 1,
      });
      expect(summary.exerciseNames, isEmpty);
      expect(
        const WorkoutLibraryFilter(query: 'antigua').matches(summary),
        isTrue,
      );
    },
  );
}
