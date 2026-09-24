import 'package:entrenaop/features/profile/domain/age_on_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileBirthDateRepository {
  const ProfileBirthDateRepository(this._client);

  final SupabaseClient _client;

  Future<DateTime?> get() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Inicia sesión para ver tu perfil.');
    final row = await _client
        .from('profiles')
        .select('fecha_nacimiento')
        .eq('id', userId)
        .single();
    final raw = row['fecha_nacimiento'] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  Future<void> save(DateTime birthDate) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Inicia sesión para editar tu perfil.');
    }
    final today = DateTime.now();
    final age = ageOnDate(birthDate, today);
    if (age < 17 || age > 120) {
      throw ArgumentError.value(birthDate, 'birthDate', 'Edad no válida.');
    }
    await confirmBirthDateWrite(
      chosen: birthDate,
      write: () async {
        await _client
            .from('profiles')
            .update({
              'fecha_nacimiento':
                  '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
            })
            .eq('id', userId);
      },
      read: get,
    );
  }
}

Future<void> confirmBirthDateWrite({
  required DateTime chosen,
  required Future<void> Function() write,
  required Future<DateTime?> Function() read,
}) async {
  try {
    await write();
  } catch (_) {
    // Una respuesta fallida no implica que la escritura se haya deshecho.
    // Confirmamos el estado real antes de decirle al usuario que falló.
    try {
      final stored = await read();
      if (stored != null &&
          stored.year == chosen.year &&
          stored.month == chosen.month &&
          stored.day == chosen.day) {
        return;
      }
    } catch (_) {
      // Sin lectura confirmada, conservamos el error original.
    }
    rethrow;
  }
}
