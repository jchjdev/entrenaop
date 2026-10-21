import 'professional_assessment.dart';

abstract final class ProfessionalAssessmentCodec {
  static ProfessionalAssessmentEvent event(Map<String, dynamic> row) {
    if (row['kind'] != 'assessment') {
      throw const FormatException('El evento no es una prueba.');
    }
    return ProfessionalAssessmentEvent(
      id: row['id'] as String,
      date: DateTime.parse(row['date'] as String),
      status: row['status'] as String,
      revision: row['revision'] as int,
      title: row['title'] as String,
      clientId: row['client_id'] as String,
      relationId: row['relation_id'] as String,
      personName: row['person_name'] as String,
    );
  }

  static ProfessionalRetryPolicy retry(String value) => switch (value) {
    'none' => ProfessionalRetryPolicy.none,
    'always' => ProfessionalRetryPolicy.always,
    'invalid_only' => ProfessionalRetryPolicy.invalidOnly,
    _ => throw const FormatException('Política de intentos desconocida.'),
  };
  static String retryValue(ProfessionalRetryPolicy value) => switch (value) {
    ProfessionalRetryPolicy.none => 'none',
    ProfessionalRetryPolicy.always => 'always',
    ProfessionalRetryPolicy.invalidOnly => 'invalid_only',
  };
  static ProfessionalAssessmentTest test(Map<String, dynamic> row) =>
      ProfessionalAssessmentTest(
        id: row['id'] as String,
        name: row['name'] as String,
        unit: ProfessionalMarkUnit.values.byName(row['unit'] as String),
        direction: ProfessionalBetterDirection.values.byName(
          row['direction'] as String,
        ),
        resolution: (row['resolution'] as num).toDouble(),
        instructions: row['instructions'] as String,
        maximumAttempts: row['max_attempts'] as int,
        retryPolicy: retry(row['retry_policy'] as String),
        source: ProfessionalProtocolSource.values.byName(
          row['source'] as String,
        ),
        officialTestId: row['official_test_id'] as String?,
        protocolFingerprint: row['protocol_fingerprint'] as String?,
        definitionVersion: row['definition_version'] as int?,
        protocolId: row['protocol_id'] as String?,
        protocolVersion: row['protocol_version'] as int?,
      );
  static ProfessionalAssessmentVersion decode(Map<String, dynamic> row) {
    final c = Map<String, dynamic>.from(row['content'] as Map);
    return ProfessionalAssessmentValidator.normalize(
      ProfessionalAssessmentVersion(
        id: row['id'] as String,
        familyId: row['family_id'] as String,
        version: row['version'] as int,
        title: c['title'] as String,
        description: c['description'] as String?,
        tests: (c['tests'] as List).map(
          (t) => test(Map<String, dynamic>.from(t as Map)),
        ),
      ),
    );
  }

  static Map<String, Object?> encode(ProfessionalAssessmentVersion form) {
    final f = ProfessionalAssessmentValidator.normalize(form);
    return {
      'title': f.title,
      'description': f.description,
      'tests': f.tests
          .map(
            (t) => {
              'id': t.id,
              'source': t.source.name,
              if (t.source == ProfessionalProtocolSource.official)
                'official_test_id': t.officialTestId,
              if (t.source == ProfessionalProtocolSource.custom) ...{
                'name': t.name.trim(),
                'unit': t.unit.name,
                'direction': t.direction.name,
                'resolution': t.resolution,
                'instructions': t.instructions.trim(),
                'max_attempts': t.maximumAttempts,
                'retry_policy': retryValue(t.retryPolicy),
              },
            },
          )
          .toList(),
    };
  }

  static Map<String, List<ProfessionalAssessmentAttempt>> decodeAnswers(
    Map<String, dynamic> values,
  ) => {
    for (final e in values.entries)
      e.key: (e.value as List)
          .map(
            (a) => ProfessionalAssessmentAttempt(
              valid: (a as Map)['valid'] as bool,
              value: (a['value'] as num?)?.toDouble(),
            ),
          )
          .toList(),
  };
  static Map<String, Object> encodeAnswers(
    Map<String, List<ProfessionalAssessmentAttempt>> values,
  ) => {
    for (final e in values.entries)
      e.key: e.value
          .map((a) => {'valid': a.valid, if (a.valid) 'value': a.value})
          .toList(),
  };

  static ProfessionalAssessmentDelivery delivery(Map<String, dynamic> row) =>
      ProfessionalAssessmentDelivery(
        id: row['id'] as String,
        clientId: row['client_id'] as String,
        relationId: row['relation_id'] as String,
        trainerId: row['trainer_id'] as String,
        trainerName: row['trainer_name'] as String,
        clientName: row['client_name'] as String,
        status: row['status'] as String,
        revision: row['revision'] as int,
        scheduledDate: DateTime.parse(row['scheduled_date'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        battery: decode(Map<String, dynamic>.from(row['battery'] as Map)),
        startedAt: row['started_at'] == null
            ? null
            : DateTime.parse(row['started_at'] as String),
        completedAt: row['completed_at'] == null
            ? null
            : DateTime.parse(row['completed_at'] as String),
        canStart: row['can_start'] == true,
        canEdit: row['can_edit'] == true,
        answers: decodeAnswers(
          Map<String, dynamic>.from(row['answers'] as Map),
        ),
      );
}
