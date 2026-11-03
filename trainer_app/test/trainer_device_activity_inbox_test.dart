import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:entrenaop_trainer/trainer_device_activity_inbox_panel.dart';
import 'package:entrenaop_trainer/trainer_device_activity_inbox_repository.dart';
import 'package:workout_core/device_activity_inbox.dart';
import 'package:workout_core/device_activity_summary.dart';

import 'trainer_program_work_repository_test.dart' show ProgramWorkServer;
import 'trainer_exercise_repository_test.dart' show owner;

class InboxFixture implements DeviceActivityInboxRepository {
  final pending = Completer<List<DeviceActivitySummary>>();
  int calls = 0;
  @override
  Future<List<DeviceActivitySummary>> load() {
    calls++;
    return pending.future;
  }
}

DeviceActivitySummary activity(String name) => DeviceActivitySummary(
  id: name,
  scheduledId: null,
  provider: 'garmin',
  state: 'unassigned',
  name: name,
  startedAt: DateTime.utc(2026, 10, 20),
  seconds: 120.125,
  meters: 420.25,
  intervalCount: 3,
);

void main() {
  testWidgets(
    'distingue pauta identificada de actividad sin asociar, sin inventar cierre',
    (tester) async {
      final repo = InboxFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrainerDeviceActivityInboxPanel(repository: repo),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mis actividades recibidas'));
      await tester.pump(const Duration(milliseconds: 350));
      repo.pending.complete([
        DeviceActivitySummary.fromJson({
          'id': 'linked',
          'scheduled_id': 'appointment',
          'scheduled_name': 'Series sintéticas',
          'provider': 'garmin',
          'state': 'review',
          'name': 'Carrera identificada',
          'started_at': '2026-10-20T08:00:00Z',
          'timer_seconds': 120,
        }),
        activity('Carrera sin pauta'),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Garmin · Pendiente de revisión'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Garmin · Pendiente de asociar'),
        findsOneWidget,
      );
      await tester.tap(find.text('Carrera identificada'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pauta identificada: Series sintéticas'),
        findsOneWidget,
      );
      expect(find.textContaining('Todavía no está asociada'), findsNothing);
      expect(find.text('Resultados incorporados a la sesión'), findsNothing);
    },
  );
  testWidgets(
    'una respuesta tardía de otra cuenta no reaparece en la bandeja',
    (tester) async {
      final first = InboxFixture(), second = InboxFixture();
      Widget page(DeviceActivityInboxRepository repo) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrainerDeviceActivityInboxPanel(repository: repo),
          ),
        ),
      );
      await tester.pumpWidget(page(first));
      await tester.tap(find.text('Mis actividades recibidas'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(page(second));
      expect(second.calls, 1);
      await tester.pump(const Duration(milliseconds: 350));
      first.pending.complete([activity('Resultado de otra cuenta')]);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Resultado de otra cuenta'), findsNothing);
      second.pending.complete([activity('Resultado propio')]);
      await tester.pumpAndSettle();
      expect(find.text('Resultado propio'), findsOneWidget);
    },
  );
  test(
    'la consulta fija identidad y no transmite un alumno o una pauta',
    () async {
      final server = ProgramWorkServer();
      addTearDown(server.client.dispose);
      await server.login();
      server.respond = (request, name, params) async {
        expect(name, 'my_unassigned_device_activities');
        expect(params, {'p_expected_owner': owner});
        return server.json(request, <dynamic>[]);
      };
      expect(
        await SupabaseDeviceActivityInboxRepository(
          server.client,
          owner,
        ).load(),
        isEmpty,
      );
      server.replaceTransportIdentity = true;
      server.respond = (_, _, _) async =>
          throw StateError('No debe consultar con otra identidad');
      await expectLater(
        SupabaseDeviceActivityInboxRepository(server.client, owner).load(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
    },
  );

  testWidgets(
    'carga al desplegar y descarta una respuesta de la cuenta anterior',
    (tester) async {
      final first = InboxFixture(), second = InboxFixture();
      Widget page(DeviceActivityInboxRepository repo) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrainerDeviceActivityInboxPanel(repository: repo),
          ),
        ),
      );
      await tester.pumpWidget(page(first));
      expect(first.calls, 0);
      await tester.tap(find.text('Mis actividades recibidas'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(first.calls, 1);
      first.pending.complete([activity('Carrera de la primera cuenta')]);
      await tester.pumpAndSettle();
      expect(find.text('Carrera de la primera cuenta'), findsOneWidget);
      await tester.pumpWidget(page(second));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Carrera de la primera cuenta'), findsNothing);
      expect(second.calls, 1);
      await tester.pump(const Duration(milliseconds: 350));
      second.pending.complete([activity('Carrera de la segunda cuenta')]);
      await tester.pumpAndSettle();
      expect(find.text('Carrera de la segunda cuenta'), findsOneWidget);
      expect(
        find.textContaining('Garmin · Pendiente de asociar'),
        findsOneWidget,
      );
      expect(find.textContaining('0.42 km'), findsOneWidget);
      expect(find.textContaining('FC media'), findsNothing);
    },
  );
}
