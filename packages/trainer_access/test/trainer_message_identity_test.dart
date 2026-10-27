import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_messages.dart';

void main() {
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
