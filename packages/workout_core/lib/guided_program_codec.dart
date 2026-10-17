import 'guided_program.dart';

Map<String, dynamic> guidedProgramToJson(GuidedProgram program) => {
  'name': program.name.trim(),
  'mode': program.mode.name,
  'description': program.description.trim(),
  'audience': program.audience.trim(),
  'equipment': program.equipment.trim(),
  'phases': [
    for (final p in program.phases)
      {
        'name': p.name.trim(),
        'duration_weeks': p.durationWeeks,
        'instructions': p.instructions.trim(),
        'sessions': [
          for (final s in p.sessions)
            {
              'template_id': s.templateId,
              'name': s.name.trim(),
              'warmup_id': s.warmupId,
              'rest': {
                'min_seconds': s.restPolicy.minimumSeconds,
                'max_seconds': s.restPolicy.maximumSeconds,
              },
            },
        ],
      },
  ],
};

GuidedProgram guidedProgramFromJson(Map<String, dynamic> row) {
  final data = Map<String, dynamic>.from(row['content'] as Map);
  return GuidedProgram(
    id: row['id'] as String,
    familyId: row['family_id'] as String,
    version: row['version'] as int,
    status: row['status'] as String,
    name: data['name'] as String,
    mode: GuidedProgramMode.values.byName(data['mode'] as String),
    description: data['description'] as String? ?? '',
    audience: data['audience'] as String? ?? '',
    equipment: data['equipment'] as String? ?? '',
    phases: [
      for (final raw in data['phases'] as List)
        _phase(Map<String, dynamic>.from(raw as Map)),
    ],
  );
}

GuidedPhase _phase(Map<String, dynamic> p) => GuidedPhase(
  name: p['name'] as String,
  durationWeeks: p['duration_weeks'] as int?,
  instructions: p['instructions'] as String? ?? '',
  sessions: [
    for (final raw in p['sessions'] as List)
      _session(Map<String, dynamic>.from(raw as Map)),
  ],
);
GuidedSession _session(Map<String, dynamic> s) {
  final rest = Map<String, dynamic>.from(s['rest'] as Map? ?? const {});
  return GuidedSession(
    templateId: s['template_id'] as String,
    name: s['name'] as String,
    warmupId: s['warmup_id'] as String?,
    restPolicy: GuidedRestPolicy(
      minimumSeconds: rest['min_seconds'] as int?,
      maximumSeconds: rest['max_seconds'] as int?,
    ),
  );
}

GuidedWarmup guidedWarmupFromJson(Map<String, dynamic> row) => GuidedWarmup(
  id: row['id'] as String,
  templateId: row['template_id'] as String,
  name: row['name'] as String,
  version: row['version'] as int,
  status: row['status'] as String,
);
