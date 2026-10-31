import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/workout_template_model.dart';

import 'authenticated_rpc.dart';

/// Lee versiones publicadas. La autorización pertenece a la fachada SQL;
/// ningún consumidor adquiere permisos de ADMIN para reutilizar una receta.
class SupabasePublishedWarmupCatalog {
  const SupabasePublishedWarmupCatalog(this.client, this.owner);
  final SupabaseClient client;
  final String owner;

  Future<List<WorkoutTemplate>> load() async {
    final items = <WorkoutTemplate>[];
    String? after;
    while (true) {
      final result = Map<String, dynamic>.from(
        await authenticatedTrainerRpc(
          client,
          owner,
          'list_published_workout_warmups',
          params: {'p_expected_owner': owner, 'p_after_id': ?after},
        ) as Map,
      );
      final rows = (result['items'] as List)
          .map(
            (e) => WorkoutTemplateModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      if (rows.any((e) => after != null && e.id.compareTo(after) <= 0) ||
          (result['has_more'] == true && rows.isEmpty)) {
        throw const FormatException(
          'La página de calentamientos está incompleta.',
        );
      }
      items.addAll(rows);
      if (result['has_more'] != true) return items;
      after = rows.last.id;
    }
  }
}
