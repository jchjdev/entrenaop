import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/open_workout_session.dart';

Future<T> mapOpenWorkoutConflict<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on PostgrestException catch (error) {
    if (error.code == 'EO001' && error.details is String) {
      final details = jsonDecode(error.details as String);
      if (details case {
        'id': final String id,
        'template_name': final String name,
      }) {
        throw OpenWorkoutConflict(id, name);
      }
    }
    rethrow;
  }
}

Future<List<OpenWorkoutSession>> readOpenWorkoutSessions(
  SupabaseClient client,
) async {
  final owner = client.auth.currentUser?.id;
  if (owner == null) return const [];
  final rows = await client.rpc('get_my_open_workouts') as List;
  if (client.auth.currentUser?.id != owner) return const [];
  return [
    for (final row in rows)
      OpenWorkoutSession(
        id: row['id'] as String,
        name: row['template_name'] as String,
        startedAt: DateTime.parse(row['started_at'] as String),
      ),
  ];
}
