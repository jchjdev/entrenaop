import 'dart:convert';

import 'package:entrenaop/features/preparation_goal/data/repositories/running_intake_context_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'lee la proyección observada y conserva procedencia y fecha de salud',
    () async {
      final client = SupabaseClient(
        'https://context.example.test',
        'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/rest/v1/rpc/get_running_intake_context_observed',
          );
          expect(jsonDecode(request.body), {'p_goal_id': 'goal'});
          return http.Response(
            jsonEncode({
              'available_minutes_by_weekday': {'1': 60, '4': 45},
              'reserved_strength_weekdays': [],
              'running_days_last_four_weeks': [3, 2, 1, 0],
              'running_minutes_last_four_weeks': [95, 60, 30, 0],
              'recent_weeks_end_on': '2026-10-11',
              'updated_at': '2026-09-15T08:00:00Z',
              'health_observed_at': '2026-09-15T08:00:00Z',
              'reports_pain': false,
              'requires_professional_review': false,
              'comfortable_continuous_minutes': 30,
              'recent_load_sources': [
                'observed',
                'observed_and_declared',
                'declared',
                'unknown',
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final context = await RunningIntakeContextRepository(client)
          .get(goalId: 'goal', programId: 'fas');
      expect(
        context!.recentRunningWeeks.first.weekStart,
        DateTime(2026, 10, 5),
      );
      expect(context.recentRunningWeeks.first.runningMinutes, 95);
      expect(context.recentLoadSources.last, 'unknown');
      expect(context.health!.observedAt, DateTime.utc(2026, 9, 15, 8));
      expect(context.availableMinutesByWeekday, {1: 60, 4: 45});
    },
  );
}
