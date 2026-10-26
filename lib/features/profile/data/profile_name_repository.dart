import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

String normalizeProfileName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String? validateProfileName(String value) {
  final name = normalizeProfileName(value);
  if (name.isEmpty ||
      name.runes.length > 100 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    return 'Escribe un nombre de entre 1 y 100 caracteres, sin saltos de línea.';
  }
  return null;
}

class ProfileNameRepository {
  const ProfileNameRepository(this.client);
  final SupabaseClient client;

  Future<String> save(String ownerId, String name) async {
    final error = validateProfileName(name);
    if (error != null) throw FormatException(error);
    return await authenticatedTrainerRpc(
      client,
      ownerId,
      'update_my_profile_name',
      params: {
        'p_expected_owner': ownerId,
        'p_name': normalizeProfileName(name),
      },
    ) as String;
  }
}
