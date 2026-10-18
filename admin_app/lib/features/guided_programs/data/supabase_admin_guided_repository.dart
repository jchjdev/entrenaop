import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_template.dart';

import '../domain/admin_guided_repository.dart';

class SupabaseAdminGuidedRepository implements AdminGuidedRepository {
  const SupabaseAdminGuidedRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<GuidedProgram>> programs() async =>
      (await client
              .from('guided_programs')
              .select(
                '*,category_links:guided_program_category_links(is_primary,guided_program_categories(*))',
              )
              .order('created_at', ascending: false))
          .map(guidedProgramFromJson)
          .toList();
  @override
  Future<GuidedProgram> program(String id) async => guidedProgramFromJson(
    await client
        .from('guided_programs')
        .select(
          '*,category_links:guided_program_category_links(is_primary,guided_program_categories(*))',
        )
        .eq('id', id)
        .single(),
  );
  @override
  Future<String> save(GuidedProgram program, {String? id}) async {
    validateGuidedProgram(program);
    return await client.rpc(
      'save_guided_program',
      params: {
        'p_content': guidedProgramToJson(program),
        'p_id': id,
        'p_category_ids': program.categories.map((c) => c.id).toList(),
        'p_primary_category_id': program.primaryCategoryId,
      },
    ) as String;
  }

  @override
  Future<List<GuidedProgramCategory>> categories() async =>
      (await client.from('guided_program_categories').select().order('name'))
          .map(guidedCategoryFromJson)
          .toList();

  @override
  Future<GuidedProgramCategory> saveCategory(
    String name, {
    GuidedProgramCategory? original,
    bool active = true,
  }) async {
    try {
      final id = await client.rpc(
        'save_guided_program_category',
        params: {
          'p_name': name,
          'p_id': original?.id,
          'p_active': active,
          'p_expected_revision': original?.revision,
        },
      ) as String;
      return guidedCategoryFromJson(
        await client
            .from('guided_program_categories')
            .select()
            .eq('id', id)
            .single(),
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const FormatException(
          'Ya existe una categoría con ese nombre, incluso sin tildes o con otras mayúsculas.',
        );
      }
      if (e.code == '40001') {
        throw const FormatException(
          'La categoría ha cambiado. Recarga la lista antes de editarla.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> setStatus(String id, String status) async {
    await client.rpc(
      'set_guided_program_status',
      params: {'p_id': id, 'p_status': status},
    );
  }

  @override
  Future<List<GuidedWarmup>> warmups() async =>
      (await client
              .from('guided_warmups')
              .select()
              .order('name')
              .order('version', ascending: false))
          .map(guidedWarmupFromJson)
          .toList();
  @override
  Future<String> saveWarmup(
    CreatePersonalWorkoutInput input, {
    String? previousId,
  }) async => await client.rpc(
    'save_guided_warmup',
    params: {
      'p_payload': workoutDraftToJson(input),
      'p_previous_id': previousId,
    },
  ) as String;
}
