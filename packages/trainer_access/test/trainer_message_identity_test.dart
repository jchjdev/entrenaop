import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_messages.dart';

void main() {
  test('recupera el contador completo del alumno aunque la bandeja de etapas sea parcial', () {
    final inbox = TrainerMessageInbox.fromJson({
      'total_unread': 55,
      'conversations': [],
      'clients': {
        'student-a': {'unread_count': 55, 'relation_id': 'older-episode'},
      },
    });
    expect(inbox.clients['student-a']!.unreadCount, 55);
    expect(inbox.clients['student-a']!.relationId, 'older-episode');
    expect(inbox.clients.containsKey('student-b'), isFalse);
  });

  test(
    'bandeja y recibos rechazan una identidad retenida antes de enviar',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
      );
      addTearDown(client.dispose);
      final repository = SupabaseTrainerMessageRepository(
        client,
        'previous-account',
      );
      await expectLater(repository.inbox(), throwsStateError);
      await expectLater(repository.markRead(['message-a']), throwsStateError);
    },
  );
}
