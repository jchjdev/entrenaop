import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/notifications/push_notifications.dart';
import 'package:entrenaop/features/notifications/push_notifications_scope.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_notification_settings.dart';
import 'package:trainer_access/trainer_notifications.dart';

import 'push_notifications_test.dart' as fixture;

class Channels extends fixture.Backend implements PushChannelBackend {
  bool personal = false, professional = false;
  @override
  Future<PushConfiguration> configuration(PushAccount account) async =>
      PushConfiguration(
        true,
        'push-fixture',
        personalEnabled: personal,
        professionalEnabled: professional,
      );
  @override
  Future<PushConfiguration> personalDelivery(
    PushAccount account,
    PushInstallation installation,
    bool enabled,
  ) async {
    personal = enabled;
    return configuration(account);
  }

  @override
  Future<PushConfiguration> deviceConfiguration(
    PushAccount account,
    PushInstallation installation,
  ) => configuration(account);
}

class Preferences extends CoachNotificationRepository {
  CoachPushPreferences value = const CoachPushPreferences(available: true);
  int saves = 0;
  @override
  Future<CoachPushPreferences> preferences() async => value;
  @override
  Future<CoachPushPreferences> save(CoachPushPreferences draft) async {
    saves++;
    return value = CoachPushPreferences(
      revision: draft.revision + 1,
      available: true,
      enabled: draft.enabled,
      messages: draft.messages,
      videos: draft.videos,
    );
  }

  @override
  Future<void> videoRead(String assetId) async {}
}

void main() {
  late Channels backend;
  late fixture.Transport transport;
  late PushNotificationCoordinator push;
  late fixture.Store store;
  void prepare() {
    backend = Channels();
    transport = fixture.Transport();
    store = fixture.Store();
    push = PushNotificationCoordinator(
      transport: transport,
      backend: backend,
      store: store,
      newId: () => 'binding',
    );
  }

  tearDown(() => push.dispose());
  test('activar solo profesional no suscribe a avisos personales y apagar estos conserva el canal profesional', () async {
    prepare();
    await push.setAccount(fixture.a);
    await push.enable(professionalOnly: true);
    expect(push.enabled, true);
    expect(push.personalEnabled, false);
    expect(backend.personal, false);
    backend.professional = true;
    await push.enable();
    expect(push.personalEnabled, true);
    await push.disable();
    expect(push.personalEnabled, false);
    expect(push.enabled, true);
    expect(backend.revoked, isEmpty);
  });
  test('reanudar una instalación propia con ambos canales apagados conserva sus consentimientos', () async {
    prepare();
    store.choices[fixture.a.id] = true;
    await push.setAccount(fixture.a);
    expect(backend.registrationKinds.single, isNull);
    expect(push.personalEnabled, false);
    expect(backend.personal, false);
  });
  for (final allowed in [true, false]) {
    testWidgets('consentimiento profesional con permiso del sistema $allowed', (
      tester,
    ) async {
      prepare();
      transport.allowed = allowed;
      await push.setAccount(fixture.a);
      final repo = Preferences();
      await tester.pumpWidget(
        MaterialApp(
          home: PushNotificationsScope(
            coordinator: push,
            child: Scaffold(
              body: SingleChildScrollView(
                child: CoachNotificationSettings(repository: repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.value.enabled, false);
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Recibir avisos en el teléfono',
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(repo.saves, allowed ? 1 : 0);
      expect(repo.value.enabled, allowed);
      expect(push.personalEnabled, false);
      expect(transport.requests, 1);
      if (allowed) {
        final messages = find.widgetWithText(
          CheckboxListTile,
          'Mensajes de alumnos',
        );
        await tester.ensureVisible(messages);
        await tester.tap(messages);
        await tester.pumpAndSettle();
        expect(repo.value.messages, false);
        expect(repo.value.videos, true);
      }
    });
  }
}
