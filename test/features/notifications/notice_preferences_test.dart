import 'package:entrenaop/features/notifications/notice_preferences.dart';
import 'package:entrenaop/features/notifications/push_notifications.dart';
import 'package:entrenaop/features/notifications/push_notifications_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'push_notifications_test.dart' as fixtures;

void main() {
  test(
    'los recordatorios son optativos y respetan los límites del descanso',
    () {
      const value = NoticePreferences();
      expect(value.reminderMode, 'off');
      expect(value.validationError, isNull);
      expect(
        value
            .copyWith(reminderMode: 'sameDay', reminderMinute: 480)
            .validationError,
        isNull,
      );
      expect(
        value
            .copyWith(reminderMode: 'previousDay', reminderMinute: 1320)
            .validationError,
        isNotNull,
      );
      expect(
        value
            .copyWith(reminderMode: 'sameDay', reminderMinute: 0)
            .validationError,
        isNotNull,
      );
      expect(
        value
            .copyWith(
              reminderMode: 'sameDay',
              reminderMinute: 0,
              quietEnabled: false,
            )
            .validationError,
        isNull,
      );
      expect(
        value.copyWith(quietStart: 480, quietEnd: 480).validationError,
        isNotNull,
      );
    },
  );

  testWidgets(
    'elige día anterior y guarda una preferencia explícita a 320px con texto grande',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = fixtures.Fixture();
      addTearDown(f.coordinator.dispose);
      await f.coordinator.setAccount(fixtures.a);
      await tester.pumpWidget(
        MaterialApp(
          home: PushNotificationsScope(
            coordinator: f.coordinator,
            child: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: const SingleChildScrollView(
                  padding: EdgeInsets.all(12),
                  child: StudentPushSettings(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recordatorios y descanso'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('No recordarme').last);
      await tester.tap(find.text('No recordarme').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('El día anterior').last);
      await tester.pumpAndSettle();
      expect(f.coordinator.preferences.reminderMode, 'off');
      await tester.ensureVisible(find.text('Guardar preferencias'));
      await tester.tap(find.text('Guardar preferencias'));
      await tester.pumpAndSettle();
      expect(f.coordinator.preferences.reminderMode, 'previousDay');
      expect(f.coordinator.preferences.timezone, 'Europe/Madrid');
      expect(f.coordinator.preferences.revision, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cambiar de cuenta sustituye sus ajustes sin conservar el borrador anterior',
    (tester) async {
      final f = fixtures.Fixture();
      addTearDown(f.coordinator.dispose);
      f.backend.config = const PushConfiguration(
        true,
        'push-fixture',
        preferences: NoticePreferences(
          revision: 3,
          reminderMode: 'previousDay',
          reminderMinute: 1080,
        ),
      );
      await f.coordinator.setAccount(fixtures.a);
      await tester.pumpWidget(
        MaterialApp(
          home: PushNotificationsScope(
            coordinator: f.coordinator,
            child: const Scaffold(
              body: SingleChildScrollView(child: StudentPushSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('El día anterior · 18:00'), findsOneWidget);
      f.backend.config = const PushConfiguration(true, 'push-fixture');
      await f.coordinator.setAccount(fixtures.b);
      await tester.pumpAndSettle();
      expect(find.text('Sin recordatorios de entrenamiento'), findsOneWidget);
      expect(find.text('El día anterior · 18:00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
