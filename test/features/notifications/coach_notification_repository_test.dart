import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_notifications.dart';
import 'package:entrenaop/features/notifications/push_data.dart';
import 'package:entrenaop/features/notifications/push_notifications.dart';

import '../coach_workspace/coach_workspace_repository_test.dart' as fixture;

void main() {
  test('preferencias fijan cuenta, revisión y categorías sin permiso editable local', () async {
    final api = fixture.CoachServer();
    addTearDown(api.client.dispose);
    api.responses['get_my_coach_push_preferences'] = {
      'revision': 4,
      'enabled': false,
      'messages': true,
      'videos': false,
      'available': true,
    };
    api.responses['save_my_coach_push_preferences'] = {
      'revision': 5,
      'enabled': true,
      'messages': true,
      'videos': false,
      'available': true,
    };
    await api.login();
    final repo = SupabaseCoachNotificationRepository(api.client, fixture.owner);
    final value = await repo.preferences();
    expect(value.enabled, false);
    expect(value.videos, false);
    final saved = await repo.save(value.copyWith(enabled: true));
    expect(saved.revision, 5);
    expect(api.payload, {
      'p_expected_owner': fixture.owner,
      'p_revision': 4,
      'p_enabled': true,
      'p_messages': true,
      'p_videos': false,
    });
    api.account = fixture.other;
    await api.login();
    final calls = api.requests.length;
    await expectLater(repo.videoRead('clip'), throwsStateError);
    expect(api.requests.length, calls);
  });
  test(
    'el clic resuelve el destino autorizado y nunca acepta rutas del proveedor',
    () async {
      final api = fixture.CoachServer();
      addTearDown(api.client.dispose);
      await api.login();
      final backend = SupabasePushBackend(api.client);
      const account = PushAccount(fixture.owner, 'fixture');
      api.responses['resolve_my_coach_notice'] = {
        'kind': 'conversation',
        'target_id': fixture.other,
      };
      expect(
        await backend.professionalRoute(account, 'coachMessage'),
        '/coach/messages/${fixture.other}',
      );
      api.responses['resolve_my_coach_notice'] = {
        'kind': 'technique',
        'target_id': 'https://evil.invalid',
      };
      expect(await backend.professionalRoute(account, 'coachVideo'), isNull);
      api.responses['resolve_my_coach_notice'] = {
        'kind': 'unknown',
        'target_id': fixture.other,
      };
      expect(await backend.professionalRoute(account, 'coachVideo'), isNull);
    },
  );
  test(
    'descarta el recibo de vídeo si cambia la cuenta durante la respuesta',
    () async {
      final api = fixture.CoachServer();
      addTearDown(api.client.dispose);
      await api.login();
      api.responses['read_my_coach_video'] = null;
      api.hold = Completer<void>();
      api.started = Completer<void>();
      final repo = SupabaseCoachNotificationRepository(
        api.client,
        fixture.owner,
      );
      final read = repo.videoRead('clip');
      final assertion = expectLater(read, throwsStateError);
      await api.started!.future;
      api.account = fixture.other;
      await api.login();
      api.hold!.complete();
      await assertion;
    },
  );
}
