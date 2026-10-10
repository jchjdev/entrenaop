enum ProRestriction { exercises, sessions, adaptiveProgram }

class ProAccessDenied implements Exception {
  const ProAccessDenied(this.restriction, this.message);
  final ProRestriction restriction;
  final String message;

  static ProAccessDenied? fromDetails(Object? details) => switch (details) {
    'free_exercise_limit' => const ProAccessDenied(
      ProRestriction.exercises,
      'Has alcanzado los 8 ejercicios propios incluidos en Free. Con Pro puedes crear más.',
    ),
    'free_session_limit' => const ProAccessDenied(
      ProRestriction.sessions,
      'Has alcanzado las 4 sesiones propias incluidas en Free. Con Pro puedes guardar más.',
    ),
    'pro_required' => const ProAccessDenied(
      ProRestriction.adaptiveProgram,
      'Los programas adaptativos requieren Pro.',
    ),
    _ => null,
  };
}

/// Instantánea del servidor. El rol administrativo no concede acceso comercial.
class ProAccess {
  const ProAccess({
    required this.userId,
    required this.isPro,
    required this.checkedAt,
    required this.personalExercises,
    required this.personalSessions,
    this.validUntil,
    this.source,
  });
  final String userId;
  final bool isPro;
  final DateTime checkedAt;
  final DateTime? validUntil;
  final String? source;
  final int personalExercises, personalSessions;
  int? get exerciseLimit => isPro ? null : 8;
  int? get sessionLimit => isPro ? null : 4;

  factory ProAccess.fromJson(Map<String, dynamic> json) {
    final tier = json['tier'];
    if (tier != 'free' && tier != 'pro') {
      throw const FormatException('Acceso no válido.');
    }
    final expiry = json['valid_until'] == null
        ? null
        : DateTime.parse(json['valid_until'] as String);
    final checked = DateTime.parse(json['checked_at'] as String);
    if (tier == 'pro' && (expiry == null || !expiry.isAfter(checked))) {
      throw const FormatException('Vigencia Pro no válida.');
    }
    return ProAccess(
      userId: json['user_id'] as String,
      isPro: tier == 'pro',
      checkedAt: checked,
      validUntil: expiry,
      source: json['source'] as String?,
      personalExercises: (json['personal_exercises'] as num).toInt(),
      personalSessions: (json['personal_sessions'] as num).toInt(),
    );
  }
}

abstract class ProAccessRepository {
  Future<ProAccess> load();
}
