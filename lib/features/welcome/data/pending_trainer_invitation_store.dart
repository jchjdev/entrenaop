import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Contexto temporal de entrada, nunca una sesión ni una aceptación del vínculo.
/// Se borra al retomar la invitación autenticada y caduca a las 24 horas.
class PendingTrainerInvitationStore {
  PendingTrainerInvitationStore(this.preferences, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const storageKey = 'pending_trainer_invitation_v1';
  final SharedPreferences preferences;
  final DateTime Function() _now;

  Future<void> save(String code) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(code)) {
      throw const FormatException('Invitación inválida.');
    }
    final stored = await preferences.setString(
      storageKey,
      jsonEncode({
        'code': code,
        'expires_at': _now()
            .toUtc()
            .add(const Duration(hours: 24))
            .toIso8601String(),
      }),
    );
    if (!stored) throw StateError('No se pudo conservar la invitación.');
  }

  Future<String?> read() async {
    final stored = preferences.getString(storageKey);
    if (stored == null) return null;
    try {
      final value = jsonDecode(stored) as Map<String, dynamic>;
      final expires = DateTime.parse(value['expires_at'] as String);
      final code = value['code'] as String;
      if (_now().toUtc().isBefore(expires) &&
          expires.difference(_now().toUtc()) <= const Duration(hours: 24) &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(code)) {
        return code;
      }
    } catch (_) {
      // Un contexto dañado no debe bloquear el acceso normal.
    }
    await clear();
    return null;
  }

  Future<void> clear() async {
    if (!await preferences.remove(storageKey)) {
      throw StateError('No se pudo limpiar la invitación pendiente.');
    }
  }
}
