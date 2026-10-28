import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/trainers/presentation/trainer_invitation_entry.dart';
import 'package:trainer_access/trainer_invitation_link.dart';

void main() {
  final first = List.filled(64, 'a').join(),
      second = List.filled(64, 'b').join();
  test('separa invitaciones de Auth, deduplica arranque y no descarta otra llegada con un acuse antiguo', () {
    final entry = TrainerInvitationEntry();
    addTearDown(entry.dispose);
    var changes = 0;
    entry.addListener(() => changes++);
    entry.receive(
      Uri.parse('es.entrenaop://auth-callback/#access_token=private'),
    );
    expect(entry.pending, false);
    expect(changes, 0);
    final link = TrainerInvitationLink.openApp(first);
    entry.receive(link);
    final previous = entry.revision;
    entry.receive(link);
    expect(changes, 1);
    entry.receive(TrainerInvitationLink.openApp(second));
    entry.clear(previous);
    expect(entry.secret, second);
    expect(entry.pending, true);
    entry.clear(entry.revision);
    expect(entry.secret, isNull);
    expect(entry.pending, false);
  });
  test('una invitación malformada no reutiliza el secreto anterior y cancelar detiene la escucha', () async {
    final events = StreamController<Uri>();
    final entry = TrainerInvitationEntry();
    entry.attach(events.stream);
    entry.receive(TrainerInvitationLink.openApp(first));
    entry.receive(
      Uri.parse('es.entrenaop://trainer-invitation/#invitation=wrong'),
    );
    expect(entry.pending, true);
    expect(entry.secret, isNull);
    entry.dispose();
    await events.close();
  });
}
