import 'package:entrenaop/features/welcome/data/pending_trainer_invitation_store.dart';
import 'package:entrenaop/features/welcome/domain/entry_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retoma la invitación tras reiniciar durante el registro y permite limpiarla', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final time = DateTime.utc(2026, 10, 26, 12);
    final first = PendingTrainerInvitationStore(preferences, now: () => time);
    await first.save('a' * 64);
    final reopened = PendingTrainerInvitationStore(
      preferences,
      now: () => time.add(const Duration(hours: 2)),
    );
    final entry = EntryNavigation()
      ..restoreInvitation((await reopened.read())!);
    expect(
      entry.redirect(
        uri: Uri.parse('/'),
        authenticated: true,
        publicRoute: true,
        needsWelcome: true,
      ),
      invitationRoute('a' * 64),
    );
    await reopened.clear();
    expect(await reopened.read(), isNull);
  });

  test(
    'caduca el contexto y elimina contenido dañado sin aceptar rutas externas',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var time = DateTime.utc(2026, 10, 26, 12);
      final store = PendingTrainerInvitationStore(preferences, now: () => time);
      await store.save('a' * 64);
      time = time.add(const Duration(hours: 24));
      expect(await store.read(), isNull);
      expect(
        preferences.containsKey(PendingTrainerInvitationStore.storageKey),
        isFalse,
      );
      await preferences.setString(
        PendingTrainerInvitationStore.storageKey,
        'broken',
      );
      expect(await store.read(), isNull);
      await expectLater(
        store.save('https://example.com'),
        throwsFormatException,
      );
      expect(
        preferences.containsKey(PendingTrainerInvitationStore.storageKey),
        isFalse,
      );
    },
  );
}
