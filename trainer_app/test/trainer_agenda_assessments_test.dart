import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/professional_assessment.dart';

import 'trainer_agenda_edit_test.dart' show AgendaEditFixture, app, tapVisible;

ProfessionalAssessmentEvent event(String id) => ProfessionalAssessmentEvent(
  id: id,
  date: DateTime(2026, 10, 21),
  status: 'planned',
  revision: 0,
  title: 'Simulacro $id',
  clientId: 'ana',
  relationId: 'relation',
  personName: 'Ana de prueba',
);

class _Events implements ProfessionalAssessmentEventRepository {
  bool fail = false;
  final calls = <({DateTime start, DateTime end, String? before})>[];
  @override
  Future<List<ProfessionalAssessmentEvent>> listAssessmentEvents({
    required DateTime start,
    required DateTime endExclusive,
    ProfessionalAssessmentEvent? before,
  }) async {
    calls.add((start: start, end: endExclusive, before: before?.id));
    if (fail) throw StateError('sin respuesta');
    return before == null
        ? List.generate(200, (i) => event('$i'))
        : [event('last')];
  }
}

void main() {
  testWidgets(
    'pruebas tipadas conservan cursor, periodo civil y recuento parcial',
    (tester) async {
      final tests = _Events();
      await tester.pumpWidget(
        app(
          TrainerAgendaPage(
            repository: AgendaEditFixture(),
            assessments: tests,
            now: DateTime(2026, 10, 21),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tests.calls.single.start, DateTime(2026, 10, 1));
      expect(tests.calls.single.end, DateTime(2026, 11, 1));
      expect(find.text('Simulacro 0'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Cargar más pruebas del periodo'),
        800,
        maxScrolls: 60,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.text('Cargar más pruebas del periodo'));
      expect(tests.calls.last.before, '199');
      expect(find.text('Cargar más pruebas del periodo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fallo de pruebas no elimina las sesiones ni ofrece mover pruebas',
    (tester) async {
      final tests = _Events()..fail = true;
      await tester.pumpWidget(
        app(
          TrainerAgendaPage(
            repository: AgendaEditFixture(),
            assessments: tests,
            now: DateTime(2026, 10, 21),
            onMove: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sesión one'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sesión one'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Reintentar pruebas'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Las sesiones se muestran por separado'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
