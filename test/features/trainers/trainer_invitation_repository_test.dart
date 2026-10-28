import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../coach_workspace/coach_workspace_repository_test.dart' as fixture;

void main() {
  test('la creación destinada fija cuenta y email en cuerpo, sin incluir el secreto en URL', () async {
    final api = fixture.CoachServer();
    addTearDown(api.client.dispose);
    api.responses['create_trainer_invitation_for_email'] = {'id': 'invitation'};
    await api.login();
    final repo = SupabaseTrainerRepository(api.client, userId: fixture.owner);
    final draft = TrainerInvitationDraft.secure(
      recipientEmail: ' Alumno@Example.invalid ',
    );
    await repo.createInvitation(draft);
    expect(
      api.requests.last.url.pathSegments.last,
      'create_trainer_invitation_for_email',
    );
    expect(api.payload, {
      'p_expected_owner': fixture.owner,
      'p_id': draft.id,
      'p_secret': draft.secret,
      'p_recipient_email': 'alumno@example.invalid',
    });
    expect(api.requests.last.url.toString().contains(draft.secret), false);
    api.account = fixture.other;
    await api.login();
    final before = api.requests.length;
    await expectLater(repo.createInvitation(draft), throwsStateError);
    expect(api.requests.length, before);
  });
}
