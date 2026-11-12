import 'package:entrenaop_trainer/trainer_program_repository.dart';
import 'package:entrenaop_trainer/trainer_program_updates_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Updates implements TrainerProgramUpdates {
  final attempts = <({String id, List<String> sessions})>[];

  TrainerProgramUpdate _row(String id, String student, String reason) =>
      TrainerProgramUpdate.fromJson({
        'id': id,
        'client_id': student,
        'client_name': student,
        'scheduled_date': '2026-11-12',
        'session_name': id,
        'revision': 0,
        'from_version': 1,
        'template_id': 'new-recipe',
        'to_version': 2,
        'reason': reason,
      });

  @override
  Future<List<TrainerProgramUpdate>> previewUpdates(String programId) async => [
    _row('Fuerza', 'Isabel', 'eligible'),
    _row('Carrera', 'Isabel', 'adapted'),
    _row('Movilidad', 'Nuria', 'eligible'),
    _row('Circuito', 'Nuria', 'started'),
  ];

  @override
  Future<({int updated, int skipped})> applyUpdates(
    String operationId,
    String programId,
    List<TrainerProgramUpdate> sessions,
  ) async {
    attempts.add((
      id: operationId,
      sessions: sessions.map((s) => s.id).toList(),
    ));
    if (attempts.length == 1) throw StateError('Respuesta perdida');
    return (updated: 1, skipped: 0);
  }
}

void main() {
  testWidgets(
    'selecciona por alumno y por sesión y conserva el mismo lote al reintentar',
    (tester) async {
      final repository = _Updates();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainerProgramUpdatesDialog(
              repository: repository,
              programId: 'programa',
              openSession: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sesiones seleccionadas · 0'), findsOneWidget);

      await tester.tap(find.text('Seleccionar a todos'));
      await tester.pumpAndSettle();
      expect(find.text('Sesiones seleccionadas · 2'), findsOneWidget);
      await tester.tap(find.text('Isabel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Adaptada a mano'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Fuerza'),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sesiones seleccionadas · 1'), findsOneWidget);

      await tester.tap(find.text('Confirmar actualización'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar actualización'));
      await tester.pumpAndSettle();
      expect(repository.attempts.map((a) => a.id).toSet(), hasLength(1));
      expect(repository.attempts.map((a) => a.sessions), [
        ['Movilidad'],
        ['Movilidad'],
      ]);
      expect(
        find.text('Actualizadas · 1\nOmitidas al confirmar · 0'),
        findsOneWidget,
      );
    },
  );
}
