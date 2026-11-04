import 'package:entrenaop_admin/features/programs/domain/pull_up_lab.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_pull_up_lab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'la primera marca estricta necesita un control y empieza en una válida',
    () {
      final weeks = simulatePullUps(
        startingMark: 0,
        gear: PullGear.bands,
        calendar: PullCalendar.combined,
        response: PullResponse.favorable,
        weeks: 52,
      );
      expect(weeks.first.sessions.single.dose!.variant, PullVariant.assisted);
      final firstMark = weeks.firstWhere((w) => w.mark! > 0);
      expect(firstMark.mark, 1);
      expect(
        firstMark.sessions.any((s) => s.decision == PullDecision.test),
        isTrue,
      );
      expect(
        weeks
            .take(firstMark.number - 1)
            .expand((w) => w.sessions)
            .every((s) => s.dose?.variant != PullVariant.strict),
        isTrue,
      );
    },
  );

  test('la agenda justa conserva las dos carreras y no cambia la práctica por un máximo', () {
    final weeks = simulatePullUps(
      startingMark: 18,
      gear: PullGear.bar,
      calendar: PullCalendar.tight,
      response: PullResponse.favorable,
      weeks: 26,
    );
    expect(weeks.every((w) => w.runs.length == 2), isTrue);
    expect(
      weeks
          .expand((w) => w.sessions)
          .any((s) => s.decision == PullDecision.test),
      isFalse,
    );
    expect(weeks.any((w) => w.unplaced > 0), isTrue);
    expect(weeks.last.mark, 18);
  });

  test(
    'tras perder las gomas se calibra el apoyo de pies sin heredar dosis',
    () {
      final weeks = simulatePullUps(
        startingMark: 0,
        gear: PullGear.bands,
        calendar: PullCalendar.combined,
        response: PullResponse.interrupted,
        weeks: 52,
      );
      expect(weeks.sublist(12, 15).every((w) => w.sessions.isEmpty), isTrue);
      final returnSession = weeks[15].sessions.single;
      expect(returnSession.decision, PullDecision.calibrate);
      expect(returnSession.dose!.setup, contains('apoyo de pies'));
      expect(returnSession.dose!.reps, [5]);
    },
  );

  testWidgets(
    'el laboratorio permite cambiar el horizonte y ver la semana 52',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AdminPullUpLab())),
        ),
      );
      expect(find.text('Dominadas estrictas · meta de 25'), findsOneWidget);
      await t.tap(find.text('6 meses · 26 semanas').hitTestable());
      await t.pumpAndSettle();
      await t.tap(find.text('12 meses · 52 semanas').last);
      await t.pumpAndSettle();
      expect(find.text('12 meses · 52 semanas'), findsOneWidget);
      await t.tap(find.text('Semana 1').hitTestable());
      await t.pumpAndSettle();
      final menu = find.byType(Scrollable).last;
      await t.scrollUntilVisible(find.text('Semana 52'), 280, scrollable: menu);
      await t.tap(find.text('Semana 52').last);
      await t.pumpAndSettle();
      expect(find.text('Semana 52'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
