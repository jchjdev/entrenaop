import 'dart:convert';

import 'package:entrenaop_trainer/trainer_calendar_date.dart';
import 'package:entrenaop_trainer/trainer_groups_repository.dart';
import 'package:entrenaop_trainer/trainer_recurrence_page.dart';
import 'package:entrenaop_trainer/trainer_recurrence_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_groups_flow_test.dart' show access, app, tap;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

TrainerRecurrence series() => TrainerRecurrence.fromJson({
  'id': 'series',
  'template_name': 'Dominadas de preparación',
  'template_version': 3,
  'week_start': '2026-10-19',
  'weeks': 2,
  'weekdays': [1, 3],
  'created_at': '2026-10-21T10:00:00Z',
  'assignment_count': 8,
  'pending_count': 6,
});

class RecurrenceFixture extends TrainerRecurrenceRepository {
  bool failCreate = false, failWithdraw = false, staleWithdraw = false;
  int previews = 0, withdrawPreviews = 0;
  final requests = <TrainerRecurrenceRequest>[];
  final created =
      <({String op, String fingerprint, Map<String, dynamic> payload})>[];
  final withdrawn =
      <({String op, String series, DateTime date, String fingerprint})>[];
  @override
  Future<List<TrainerRecurrence>> series({TrainerRecurrence? before}) async =>
      [];
  @override
  Future<TrainerRecurrencePreview> preview(
    TrainerRecurrenceRequest request,
  ) async {
    previews++;
    requests.add(request);
    final dates = [
      for (var w = 0; w < request.weeks; w++)
        for (final d in request.weekdays)
          trainerCalendarDate(
            DateTime(
              request.weekStart.year,
              request.weekStart.month,
              request.weekStart.day + w * 7 + d - 1,
            ),
          ),
    ];
    return TrainerRecurrencePreview.fromJson({
      'fingerprint': 'plan-$previews',
      'assignment_count': request.recipients.length * dates.length,
      'preview': [
        for (final member in request.recipients)
          {
            'client_id': member.clientId,
            'client_name': member.name,
            'dates': dates,
            'coincidences': dates.isEmpty
                ? []
                : [
                    {'date': dates.first},
                  ],
          },
      ],
    });
  }

  @override
  Future<TrainerRecurrenceReceipt> create(
    String operationId,
    TrainerRecurrenceRequest request,
    String fingerprint,
  ) async {
    created.add((
      op: operationId,
      fingerprint: fingerprint,
      payload: Map<String, dynamic>.from(
        jsonDecode(jsonEncode(request.toParams())) as Map,
      ),
    ));
    if (failCreate) throw StateError('Incierto');
    final count = request.weeks * request.weekdays.length;
    return TrainerRecurrenceReceipt.fromJson({
      'series_id': 'series',
      'assignment_count': request.recipients.length * count,
      'recipients': [
        for (final member in request.recipients)
          {
            'client_id': member.clientId,
            'assignment_ids': [for (var i = 0; i < count; i++) 'assignment-$i'],
          },
      ],
    });
  }

  @override
  Future<TrainerRecurrenceWithdrawal> previewWithdrawal(
    String seriesId,
    DateTime fromDate,
  ) async {
    withdrawPreviews++;
    return TrainerRecurrenceWithdrawal.fromJson({
      'fingerprint': 'withdraw-$withdrawPreviews',
      'excluded_count': 1,
      'items': [
        {'id': 'one', 'client_name': 'Ana', 'date': '2026-10-26'},
        {'id': 'two', 'client_name': 'Luis', 'date': '2026-10-28'},
      ],
    });
  }

  @override
  Future<int> withdraw(
    String operationId,
    String seriesId,
    DateTime fromDate,
    String fingerprint,
  ) async {
    withdrawn.add((
      op: operationId,
      series: seriesId,
      date: fromDate,
      fingerprint: fingerprint,
    ));
    if (staleWithdraw) {
      throw const PostgrestException(message: 'Ha cambiado', code: '40001');
    }
    if (failWithdraw) throw StateError('Incierto');
    return 2;
  }
}

Widget openEditor(RecurrenceFixture repo, {double scale = 1}) => app(
  Builder(
    builder: (context) => Scaffold(
      body: FilledButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => TrainerRecurrenceEditorDialog(
            repository: repo,
            access: access(),
            workouts: WorkoutFixture(),
          ),
        ),
        child: const Text('Abrir serie'),
      ),
    ),
  ),
  scale: scale,
);
Widget openWithdrawal(RecurrenceFixture repo, {double scale = 1}) => app(
  Builder(
    builder: (context) => Scaffold(
      body: FilledButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => TrainerRecurrenceWithdrawalDialog(
            repository: repo,
            series: series(),
          ),
        ),
        child: const Text('Abrir retirada'),
      ),
    ),
  ),
  scale: scale,
);
Future<void> prepare(WidgetTester tester) async {
  await tap(tester, find.text('Ana'));
  await tap(tester, find.byKey(const ValueKey('recurrence-template')));
  await tester.tap(find.text('Fuerza para pruebas físicas · v3').last);
  await tester.pumpAndSettle();
  await tap(tester, find.byKey(const ValueKey('recurrence-monday')));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tap(tester, find.byKey(const ValueKey('recurrence-weeks')));
  await tester.tap(find.text('2 semanas').last);
  await tester.pumpAndSettle();
  await tap(tester, find.text('Lunes'));
  await tap(tester, find.text('Miércoles'));
  await tap(tester, find.text('Revisar todas las fechas'));
}

Future<void> previewWithdrawal(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('recurrence-withdraw-date')));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  test('días se ordenan y fechas siguen civiles sin mutar entrada', () {
    final days = [3, 1];
    final request = TrainerRecurrenceRequest(
      recipients: [
        const TrainerGroupMember(
          clientId: 'ana',
          name: 'Ana',
          relationId: 'relation',
        ),
      ],
      templateId: 't',
      weekStart: DateTime.utc(2026, 10, 19, 23),
      weeks: 2,
      weekdays: days,
    );
    days.clear();
    expect(request.weekdays, [1, 3]);
    expect(request.toParams()['p_week_start'], '2026-10-19');
    expect(() => request.weekdays.clear(), throwsUnsupportedError);
  });
  testWidgets('faltan campos no se calcula ni materializa serie', (
    tester,
  ) async {
    final repo = RecurrenceFixture();
    await tester.pumpWidget(openEditor(repo));
    await tap(tester, find.text('Abrir serie'));
    await tap(tester, find.text('Revisar todas las fechas'));
    expect(repo.requests, isEmpty);
    expect(repo.created, isEmpty);
    expect(find.textContaining('Elige alumnos activos'), findsOneWidget);
  });
  testWidgets('serie finita preview obligatorio y reintento idéntico', (
    tester,
  ) async {
    final repo = RecurrenceFixture()..failCreate = true;
    await tester.pumpWidget(openEditor(repo));
    await tap(tester, find.text('Abrir serie'));
    await prepare(tester);
    expect(repo.created, isEmpty);
    expect(repo.requests.single.weeks, 2);
    expect(repo.requests.single.weekdays, [1, 3]);
    expect(find.textContaining('Coincidencias:'), findsOneWidget);
    await tap(tester, find.text('Crear 4 citas'));
    expect(find.text('Volver a preparar'), findsNothing);
    repo.failCreate = false;
    await tap(tester, find.text('Reintentar misma serie'));
    expect(repo.created.length, 2);
    expect(repo.created[0].op, repo.created[1].op);
    expect(repo.created[0].fingerprint, repo.created[1].fingerprint);
    expect(repo.created[0].payload, repo.created[1].payload);
    expect(find.text('Ana: 4 citas confirmadas.'), findsOneWidget);
  });
  testWidgets('retirada exige fecha explícita y conserva orden incierta', (
    tester,
  ) async {
    final repo = RecurrenceFixture()..failWithdraw = true;
    await tester.pumpWidget(openWithdrawal(repo));
    await tap(tester, find.text('Abrir retirada'));
    expect(repo.withdrawPreviews, 0);
    expect(repo.withdrawn, isEmpty);
    expect(find.textContaining('no se da de baja'), findsOneWidget);
    await previewWithdrawal(tester);
    expect(repo.withdrawPreviews, 1);
    expect(find.textContaining('1 excluidas'), findsOneWidget);
    await tap(tester, find.text('Confirmar retirada de 2 pautas'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('recurrence-withdraw-date')),
          )
          .onPressed,
      isNull,
    );
    repo.failWithdraw = false;
    await tap(tester, find.text('Reintentar misma retirada'));
    expect(repo.withdrawn[0], repo.withdrawn[1]);
    expect(find.text('Retirada confirmada: 2 pautas.'), findsOneWidget);
  });
  testWidgets('retirada obsoleta vuelve a revisar y cambia orden', (
    tester,
  ) async {
    final repo = RecurrenceFixture()..staleWithdraw = true;
    await tester.pumpWidget(openWithdrawal(repo));
    await tap(tester, find.text('Abrir retirada'));
    await previewWithdrawal(tester);
    await tap(tester, find.text('Confirmar retirada de 2 pautas'));
    expect(find.text('Reintentar misma retirada'), findsNothing);
    repo.staleWithdraw = false;
    await tap(tester, find.text('Volver a revisar'));
    await tap(tester, find.text('Confirmar retirada de 2 pautas'));
    expect(repo.withdrawn[0].op, isNot(repo.withdrawn[1].op));
    expect(repo.withdrawn[0].fingerprint, 'withdraw-1');
    expect(repo.withdrawn[1].fingerprint, 'withdraw-2');
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('planificación y retirada caben a $width con texto doble', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = RecurrenceFixture();
      await tester.pumpWidget(
        app(
          TrainerRecurrencePage(
            repository: repo,
            access: access(),
            workouts: WorkoutFixture(),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Planificar serie finita'));
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Cerrar'));
      await tester.pumpWidget(openWithdrawal(repo, scale: 2));
      await tap(tester, find.text('Abrir retirada'));
      expect(tester.takeException(), isNull);
    });
  }
}
