import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program.dart';

void main() {
  const session = GuidedSession(templateId: 'official', name: 'Empuje');
  test('una guía conserva una estructura repetible, sin exigir semanas', () {
    const guide = GuidedProgram(
      name: 'Hipertrofia',
      mode: GuidedProgramMode.guide,
      phases: [
        GuidedPhase(name: 'Entrenamiento', sessions: [session]),
      ],
    );
    expect(() => validateGuidedProgram(guide), returnsNormally);
    expect(guide.phases.single.durationWeeks, isNull);
  });
  test('una guía no admite varias fases ocultas', () {
    const guide = GuidedProgram(
      name: 'Hipertrofia',
      mode: GuidedProgramMode.guide,
      phases: [
        GuidedPhase(name: 'A', sessions: [session]),
        GuidedPhase(name: 'B', sessions: [session]),
      ],
    );
    expect(() => validateGuidedProgram(guide), throwsFormatException);
  });
  test('un recorrido requiere duración y condiciones para cada fase', () {
    const program = GuidedProgram(
      name: 'Fuerza',
      mode: GuidedProgramMode.phased,
      phases: [
        GuidedPhase(name: 'Preparación', sessions: [session], durationWeeks: 2),
      ],
    );
    expect(() => validateGuidedProgram(program), throwsFormatException);
  });
  test('rechaza rangos incompletos, negativos o invertidos de descanso', () {
    for (final policy in [
      const GuidedRestPolicy(minimumSeconds: 60),
      const GuidedRestPolicy(minimumSeconds: -1, maximumSeconds: 90),
      const GuidedRestPolicy(minimumSeconds: 120, maximumSeconds: 60),
    ]) {
      final program = GuidedProgram(
        name: 'Fuerza',
        mode: GuidedProgramMode.guide,
        phases: [
          GuidedPhase(
            name: 'A',
            sessions: [
              GuidedSession(
                templateId: 'official',
                name: 'A',
                restPolicy: policy,
              ),
            ],
          ),
        ],
      );
      expect(() => validateGuidedProgram(program), throwsFormatException);
    }
  });
}
