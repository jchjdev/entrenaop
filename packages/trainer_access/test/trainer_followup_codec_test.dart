import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

void main() {
  test(
    'codec conserva claves y versiones de servidor sin introducir permisos',
    () {
      final form = TrainerFollowupFormVersion(
        formId: 'family',
        versionId: 'version',
        revision: 2,
        title: ' Revisión ',
        questions: [
          TrainerFollowupQuestion(
            id: 'scale',
            position: 0,
            prompt: 'Sensación',
            type: TrainerFollowupQuestionType.scale,
            required: true,
          ),
        ],
      );
      final payload = TrainerFollowupCodec.encode(form);
      expect(payload.keys, ['title', 'description', 'questions']);
      final decoded = TrainerFollowupCodec.decode({
        'id': 'version',
        'family_id': 'family',
        'version': 2,
        'content': payload,
      });
      expect(decoded.title, 'Revisión');
      expect(decoded.versionId, 'version');
      expect(decoded.formId, 'family');
      expect(decoded.questions.single.minimum, 1);
      expect(decoded.questions.single.maximum, 5);
      expect((payload['questions'] as List).single['type'], 'scale');
    },
  );
  test(
    'entrega conserva respuesta falsa y versión antigua aunque esté inactiva',
    () {
      final assignment = TrainerFormAssignment.fromJson({
        'id': 'assignment',
        'form_id': 'version-1',
        'family_id': 'family',
        'version': 1,
        'client_id': 'client',
        'relation_id': 'relation',
        'trainer_name': 'Preparador',
        'due_date': '2026-10-22',
        'created_at': '2026-10-21T12:00:00Z',
        'submitted_at': '2026-10-21T13:00:00Z',
        'can_respond': false,
        'answers': {'yes-no': false},
        'content': {
          'title': 'Original',
          'questions': [
            {
              'id': 'yes-no',
              'position': 0,
              'prompt': '¿Sí?',
              'type': 'yesNo',
              'required': true,
              'options': [],
            },
          ],
        },
      });
      expect(assignment.form.versionId, 'version-1');
      expect(assignment.answers, {'yes-no': false});
      expect(assignment.statusLabel, 'Respondido');
      expect(assignment.canRespond, isFalse);
    },
  );
}
