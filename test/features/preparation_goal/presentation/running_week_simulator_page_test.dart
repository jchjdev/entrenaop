import 'package:entrenaop/features/preparation_goal/data/initial_week_draft_catalog.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_week_simulator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InitialWeekDraft draft;
  setUpAll(() async => draft = await InitialWeekDraftCatalog.load());

  testWidgets('sin historial ni marca explica por qué no propone semana', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RunningWeekSimulatorPage(draft: Future.value(draft))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simular semana'));
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no podemos proponer esta semana'),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.text('Todavía no podemos proponer esta semana'))
          .dy,
      lessThan(600),
    );
    expect(find.textContaining('historial reciente'), findsWidgets);
    expect(find.textContaining('marca válida de 2 km'), findsOneWidget);
    expect(find.text('Propuesta de prueba · no asignada'), findsNothing);
  });

  testWidgets('el ejemplo ficticio produce carrera y reserva fuerza', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RunningWeekSimulatorPage(draft: Future.value(draft))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Usar ejemplo ficticio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular semana'));
    await tester.pumpAndSettle();

    expect(find.text('Propuesta de prueba · no asignada'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Propuesta de prueba · no asignada')).dy,
      lessThan(600),
    );
    expect(find.text('Calidad controlada'), findsOneWidget);
    expect(find.text('Carrera fácil'), findsOneWidget);
    expect(find.textContaining('1 día reservado'), findsOneWidget);
    expect(
      find.textContaining('tropa_running_initial_week_v1'),
      findsOneWidget,
    );
  });

  testWidgets('dolor bloquea la propuesta aunque haya marca', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RunningWeekSimulatorPage(draft: Future.value(draft))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Usar ejemplo ficticio'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dolor o posible lesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular semana'));
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no podemos proponer esta semana'),
      findsOneWidget,
    );
    expect(
      find.textContaining('fisioterapia o medicina deportiva'),
      findsOneWidget,
    );
    expect(find.text('Propuesta de prueba · no asignada'), findsNothing);
  });
}
