import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProgram {
  const AdminProgram({
    required this.id,
    required this.name,
    required this.kind,
    required this.enabled,
  });

  final String id;
  final String name;
  final String kind;
  final bool enabled;

  factory AdminProgram.fromJson(Map<String, dynamic> json) => AdminProgram(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: json['kind'] as String,
    enabled: json['enabled'] as bool,
  );
}

abstract class AdminProgramRepository {
  Future<bool> hasAccess();
  Future<List<AdminProgram>> listPrograms();
  Future<void> createDraft({required String name, required String kind});
}

class SupabaseAdminProgramRepository implements AdminProgramRepository {
  SupabaseAdminProgramRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> hasAccess() async =>
      await _client.rpc('is_admin') as bool? ?? false;

  @override
  Future<List<AdminProgram>> listPrograms() async {
    final rows = await _client
        .from('preparation_programs')
        .select('id,name,kind,enabled')
        .order('name');
    return rows.map(AdminProgram.fromJson).toList();
  }

  @override
  Future<void> createDraft({required String name, required String kind}) async {
    await _client.rpc(
      'create_admin_preparation_program',
      params: {'p_name': name, 'p_kind': kind},
    );
  }
}
