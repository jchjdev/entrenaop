import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/pro_access.dart';

class SupabaseProAccessRepository implements ProAccessRepository {
  const SupabaseProAccessRepository(this.client);
  final SupabaseClient client;

  @override
  Future<ProAccess> load() async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw StateError('Inicia sesión para consultar tu acceso.');
    }
    final json = await client.rpc('get_my_pro_access');
    final access = ProAccess.fromJson(Map<String, dynamic>.from(json as Map));
    // Una respuesta anterior a un cambio de cuenta no pertenece a la nueva.
    if (owner != client.auth.currentUser?.id || access.userId != owner) {
      throw StateError('La cuenta ha cambiado. Vuelve a consultar tu acceso.');
    }
    return access;
  }
}
