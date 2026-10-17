/// Contenido editorial; las fases no dependen del calendario del dispositivo.
enum GuidedProgramMode { guide, phased }

class GuidedRestPolicy {
  const GuidedRestPolicy({this.minimumSeconds, this.maximumSeconds});
  final int? minimumSeconds;
  final int? maximumSeconds;
  bool get adjustable => minimumSeconds != null && maximumSeconds != null;
}

class GuidedSession {
  const GuidedSession({
    required this.templateId,
    required this.name,
    this.warmupId,
    this.restPolicy = const GuidedRestPolicy(),
  });
  final String templateId;
  final String name;
  final String? warmupId;
  final GuidedRestPolicy restPolicy;
}

class GuidedPhase {
  const GuidedPhase({
    required this.name,
    required this.sessions,
    this.durationWeeks,
    this.instructions = '',
  });
  final String name;
  final List<GuidedSession> sessions;
  final int? durationWeeks;
  final String instructions;
}

class GuidedProgram {
  const GuidedProgram({
    this.id,
    this.familyId,
    this.version = 1,
    this.status = 'draft',
    required this.name,
    required this.mode,
    required this.phases,
    this.description = '',
    this.audience = '',
    this.equipment = '',
  });
  final String? id;
  final String? familyId;
  final int version;
  final String status;
  final String name;
  final GuidedProgramMode mode;
  final List<GuidedPhase> phases;
  final String description;
  final String audience;
  final String equipment;
  int get sessionCount => phases.fold(0, (n, p) => n + p.sessions.length);
  String get modeLabel =>
      mode == GuidedProgramMode.guide ? 'Guía repetible' : 'Por fases';
}

class GuidedWarmup {
  const GuidedWarmup({
    required this.id,
    required this.templateId,
    required this.name,
    required this.version,
    required this.status,
  });
  final String id;
  final String templateId;
  final String name;
  final int version;
  final String status;
}

void validateGuidedProgram(GuidedProgram program) {
  if (program.name.trim().isEmpty || program.name.length > 80) {
    throw const FormatException('Escribe un nombre de hasta 80 caracteres.');
  }
  if (program.phases.isEmpty ||
      program.phases.length > 24 ||
      (program.mode == GuidedProgramMode.guide && program.phases.length != 1)) {
    throw const FormatException('Revisa las fases del programa.');
  }
  for (final phase in program.phases) {
    if (phase.name.trim().isEmpty ||
        phase.sessions.isEmpty ||
        phase.sessions.length > 64) {
      throw const FormatException('Cada fase necesita nombre y sesiones.');
    }
    if (program.mode == GuidedProgramMode.phased &&
        (phase.durationWeeks == null ||
            phase.durationWeeks! < 1 ||
            phase.durationWeeks! > 104 ||
            phase.instructions.trim().isEmpty)) {
      throw const FormatException(
        'Indica duración y condiciones de avance en cada fase.',
      );
    }
    for (final session in phase.sessions) {
      final rest = session.restPolicy;
      if (session.templateId.isEmpty ||
          session.name.trim().isEmpty ||
          ((rest.minimumSeconds == null) != (rest.maximumSeconds == null)) ||
          (rest.adjustable &&
              (rest.minimumSeconds! < 0 ||
                  rest.maximumSeconds! > 3600 ||
                  rest.minimumSeconds! > rest.maximumSeconds!))) {
        throw const FormatException('Revisa las sesiones y sus descansos.');
      }
    }
  }
}
