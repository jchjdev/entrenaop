import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_calendar.dart';

import 'student_notice_repository_test.dart' show NoticeServer, pupil, other;

void main() {
  late NoticeServer server;
  setUp(() async {
    server = NoticeServer();
    await server.login();
    server.requests.clear();
    server.responses['get_my_trainer_calendar_sharing'] = {
      'enabled': false,
      'revision': 0,
      'active_trainers': 2,
      'max_active_trainers': 2,
    };
    server.responses['set_my_trainer_calendar_sharing'] = {
      'enabled': true,
      'revision': 1,
      'active_trainers': 2,
      'max_active_trainers': 2,
    };
    server.responses['get_trainer_shared_calendar'] = {
      'shared': true,
      'has_more': false,
      'items': [],
      'coaches': [],
    };
  });
  tearDown(() async => server.client.dispose());
  test('consentimiento guarda versión e identidad; calendario se acota al alumno elegido', () async {
    final sharing = SupabaseTrainerCalendarSharingRepository(
      server.client,
      pupil,
    );
    expect((await sharing.get()).enabled, isFalse);
    expect((await sharing.set(true, 0)).revision, 1);
    final saved = jsonDecode(server.requests.last.body) as Map;
    expect(saved, {
      'p_expected_owner': pupil,
      'p_enabled': true,
      'p_expected_revision': 0,
    });
    final calendar = SupabaseTrainerSharedCalendarRepository(
      server.client,
      pupil,
    );
    await calendar.calendar(
      'isabel',
      DateTime(2026, 10, 24),
      DateTime(2026, 10, 30),
    );
    expect(jsonDecode(server.requests.last.body), {
      'p_expected_owner': pupil,
      'p_client_id': 'isabel',
      'p_from': '2026-10-24',
      'p_to': '2026-10-30',
    });
  });
  test(
    'respuesta tardía de otra cuenta se descarta también para este calendario',
    () async {
      final calendar = SupabaseTrainerSharedCalendarRepository(
        server.client,
        pupil,
      );
      server.started = Completer<void>();
      server.hold = Completer<void>();
      final result = calendar.calendar(
        'isabel',
        DateTime(2026),
        DateTime(2026, 1, 7),
      );
      final check = expectLater(result, throwsStateError);
      await server.started!.future;
      server.account = other;
      await server.login();
      server.hold!.complete();
      await check;
    },
  );
}
