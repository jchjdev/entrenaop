import 'trainer_followup.dart';

abstract final class TrainerFollowupCodec {
  static Map<String, Object?> encode(TrainerFollowupFormVersion form) {
    final normalized = TrainerFollowupValidator.normalizeForm(form);
    return {
      'title': normalized.title,
      'description': normalized.description,
      'questions': normalized.questions
          .map(
            (q) => {
              'id': q.id,
              'position': q.position,
              'prompt': q.prompt,
              'type': q.type.name,
              'required': q.required,
              'help': q.help,
              'options': q.options
                  .map((o) => {'id': o.id, 'label': o.label})
                  .toList(),
              'minimum': q.minimum,
              'maximum': q.maximum,
              'maximum_selections': q.maximumSelections,
            },
          )
          .toList(),
    };
  }

  static TrainerFollowupFormVersion decode(Map<String, dynamic> row) {
    final content = Map<String, dynamic>.from(row['content'] as Map);
    return TrainerFollowupValidator.normalizeForm(
      TrainerFollowupFormVersion(
        formId: row['family_id'] as String,
        versionId: (row['form_id'] ?? row['id']) as String,
        revision: row['version'] as int,
        title: content['title'] as String,
        description: content['description'] as String?,
        questions: (content['questions'] as List).map((raw) {
          final q = Map<String, dynamic>.from(raw as Map);
          return TrainerFollowupQuestion(
            id: q['id'] as String,
            position: q['position'] as int,
            prompt: q['prompt'] as String,
            type: TrainerFollowupQuestionType.values.byName(
              q['type'] as String,
            ),
            required: q['required'] as bool,
            help: q['help'] as String?,
            minimum: (q['minimum'] as num?)?.toDouble(),
            maximum: (q['maximum'] as num?)?.toDouble(),
            maximumSelections: q['maximum_selections'] as int?,
            options: (q['options'] as List).map(
              (o) => TrainerFollowupOption(
                id: (o as Map)['id'] as String,
                label: o['label'] as String,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class TrainerFormAssignment {
  TrainerFormAssignment.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      clientId = row['client_id'] as String,
      relationId = row['relation_id'] as String,
      trainerName = row['trainer_name'] as String? ?? 'Tu preparador',
      form = TrainerFollowupCodec.decode(row),
      dueDate = DateTime.parse(row['due_date'] as String),
      createdAt = DateTime.parse(row['created_at'] as String),
      submittedAt = row['submitted_at'] == null
          ? null
          : DateTime.parse(row['submitted_at'] as String),
      canRespond = row['can_respond'] == true,
      answers = row['answers'] == null
          ? null
          : TrainerFollowupValidator.normalizeSubmission(
              form: TrainerFollowupCodec.decode(row),
              versionId: row['form_id'] as String,
              answers: Map<String, Object?>.from(row['answers'] as Map),
            ).answers;
  final String id, clientId, relationId, trainerName;
  final TrainerFollowupFormVersion form;
  final DateTime dueDate, createdAt;
  final DateTime? submittedAt;
  final bool canRespond;
  final Map<String, Object>? answers;
  String get statusLabel => submittedAt != null
      ? 'Respondido'
      : canRespond
      ? 'Pendiente'
      : 'Servicio inactivo';
}

abstract class TrainerStudentFormRepository {
  Future<List<TrainerFormAssignment>> mine({TrainerFormAssignment? before});
  Future<TrainerFormAssignment> assignment(String id);
  Future<void> submit(
    String operationId,
    TrainerFormAssignment assignment,
    Map<String, Object?> answers,
  );
}
