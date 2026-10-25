import 'professional_assessment.dart';
import 'professional_assessment_codec.dart';

/// Objetivo del servicio entre un preparador y un alumno; no cambia su
/// preparación personal ni constituye una calificación oficial.
class ProfessionalOppositionGoalTarget {
  const ProfessionalOppositionGoalTarget({
    required this.protocol,
    required this.value,
    this.best,
    this.recordedAt,
    this.latest,
    this.latestAt,
    this.previous,
    this.previousAt,
    this.hasLatestEvidence = false,
  });
  final ProfessionalAssessmentTest protocol;
  final double value;
  final double? best;
  final DateTime? recordedAt;
  final double? latest, previous;
  final DateTime? latestAt, previousAt;
  final bool hasLatestEvidence;

  /// Una mejor marca antigua no acredita el estado de la última evaluación.
  /// Clientes/API anteriores conservan best, pero no fabrican actualidad.
  bool? get reached => !hasLatestEvidence || latest == null
      ? null
      : protocol.direction == ProfessionalBetterDirection.higher
      ? latest! >= value
      : latest! <= value;

  double? get favorableChange =>
      !hasLatestEvidence || latest == null || previous == null
      ? null
      : protocol.direction == ProfessionalBetterDirection.higher
      ? latest! - previous!
      : previous! - latest!;
}

class ProfessionalOppositionGoalDraft {
  ProfessionalOppositionGoalDraft({
    required this.title,
    this.targetDate,
    Iterable<ProfessionalOppositionGoalTarget> targets = const [],
  }) : targets = List.unmodifiable(targets);
  final String title;
  final DateTime? targetDate;
  final List<ProfessionalOppositionGoalTarget> targets;

  ProfessionalOppositionGoalDraft normalized() {
    final name = title.trim();
    if (name.isEmpty ||
        name.length > 120 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name) ||
        targets.length > 40 ||
        targetDate != null &&
            (targetDate!.year < 2000 || targetDate!.year > 2200)) {
      throw const FormatException(
        'Indica un objetivo de hasta 120 caracteres, fecha válida y hasta 40 metas.',
      );
    }
    final ids = <String>{};
    final fingerprints = <String>{};
    for (final target in targets) {
      final protocol = target.protocol;
      if (protocol.protocolId == null ||
          protocol.protocolFingerprint == null ||
          protocol.protocolFingerprint!.isEmpty ||
          !ids.add(protocol.protocolId!) ||
          !fingerprints.add(protocol.protocolFingerprint!) ||
          !ProfessionalAssessmentValidator.validMark(target.value, protocol)) {
        throw const FormatException(
          'Revisa las metas y selecciona pruebas guardadas sin duplicarlas.',
        );
      }
    }
    return ProfessionalOppositionGoalDraft(
      title: name,
      targetDate: targetDate == null
          ? null
          : DateTime(targetDate!.year, targetDate!.month, targetDate!.day),
      targets: targets,
    );
  }

  Map<String, dynamic> toJson() {
    final draft = normalized();
    final date = draft.targetDate;
    return {
      'title': draft.title,
      'target_date': date == null ? null : goalCivilDate(date),
      'targets': [
        for (final t in draft.targets)
          {'protocol_id': t.protocol.protocolId, 'value': t.value},
      ],
    };
  }
}

class ProfessionalOppositionGoal {
  ProfessionalOppositionGoal({
    required this.revision,
    required this.title,
    this.targetDate,
    Iterable<ProfessionalOppositionGoalTarget> targets = const [],
    this.canEdit = true,
    this.historyComplete = true,
    this.evaluationsConsidered = 0,
  }) : targets = List.unmodifiable(targets);
  final int revision;
  final String title;
  final DateTime? targetDate;
  final List<ProfessionalOppositionGoalTarget> targets;
  final bool canEdit;
  final bool historyComplete;
  final int evaluationsConsidered;

  factory ProfessionalOppositionGoal.fromJson(Map<String, dynamic> row) =>
      ProfessionalOppositionGoal(
        revision: row['revision'] as int,
        title: row['title'] as String,
        targetDate: row['target_date'] == null
            ? null
            : DateTime.parse(row['target_date'] as String),
        canEdit: row['can_edit'] == true,
        historyComplete: row['history_complete'] == true,
        evaluationsConsidered: row['evaluations_considered'] as int? ?? 0,
        targets: (row['targets'] as List? ?? []).map((raw) {
          final t = Map<String, dynamic>.from(raw as Map);
          return ProfessionalOppositionGoalTarget(
            protocol: ProfessionalAssessmentCodec.test(
              Map<String, dynamic>.from(t['protocol'] as Map),
            ),
            value: (t['value'] as num).toDouble(),
            best: (t['best'] as num?)?.toDouble(),
            recordedAt: t['recorded_at'] == null
                ? null
                : DateTime.parse(t['recorded_at'] as String),
            latest: (t['latest'] as num?)?.toDouble(),
            latestAt: t['latest_at'] == null
                ? null
                : DateTime.parse(t['latest_at'] as String),
            previous: (t['previous'] as num?)?.toDouble(),
            previousAt: t['previous_at'] == null
                ? null
                : DateTime.parse(t['previous_at'] as String),
            hasLatestEvidence:
                t.containsKey('latest') && t.containsKey('latest_at'),
          );
        }),
      );

  ProfessionalOppositionGoalDraft get draft => ProfessionalOppositionGoalDraft(
    title: title,
    targetDate: targetDate,
    targets: targets,
  );
}

String goalCivilDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
