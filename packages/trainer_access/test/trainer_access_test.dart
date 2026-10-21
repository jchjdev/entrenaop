import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';

void main() {
  test('invitaciones con identidad estable y 256 bits de secreto seguro', () {
    final drafts = List.generate(100, (_) => TrainerInvitationDraft.secure());
    expect(drafts.map((v) => v.id).toSet(), hasLength(100));
    expect(drafts.map((v) => v.secret).toSet(), hasLength(100));
    for (final draft in drafts) {
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(draft.id),
        isTrue,
      );
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(draft.secret), isTrue);
    }
  });
  test(
    'no usa un repositorio retenido de otra identidad ni llama al servidor',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
      );
      addTearDown(client.dispose);
      final repository = SupabaseTrainerRepository(
        client,
        userId: 'previous-account',
      );
      await expectLater(repository.access(), throwsStateError);
      await expectLater(repository.preview('a' * 64), throwsStateError);
      await expectLater(repository.accept('a' * 64), throwsStateError);
      await expectLater(
        repository.createInvitation(TrainerInvitationDraft.secure()),
        throwsStateError,
      );
      await expectLater(
        repository.relations(asTrainer: true),
        throwsStateError,
      );
      await expectLater(repository.management('someone'), throwsStateError);
    },
  );
  test('un error desconocido nunca expone mensajes o secretos de servidor', () {
    expect(
      trainerError(const PostgrestException(message: 'sensitive-secret')),
      isNot(contains('sensitive')),
    );
  });
}
