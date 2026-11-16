import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'permite saltar, reabrir y guardar la elección por cuenta y panel',
    (tester) async {
      final storage = <String, bool>{};
      ProfessionalGuideController create(
        String panel, [
        String account = 'a',
      ]) => ProfessionalGuideController(
        panel: panel,
        accountId: account,
        read: (key) => storage[key] ?? false,
        write: (key, hidden) => storage[key] = hidden,
      );
      final controller = create('trainer');
      String? destination;

      Widget app(ProfessionalGuideController controller, {bool home = true}) =>
          MaterialApp(
            home: ProfessionalGuideHost(
              controller: controller,
              offerOnEntry: home,
              currentPath: '/agenda',
              steps: const [
                ProfessionalGuideStep(
                  title: 'Invita a tu primer alumno',
                  text: 'Comparte el enlace.',
                  destination: 'Alumnos',
                  path: '/clients',
                  icon: Icons.people,
                ),
                ProfessionalGuideStep(
                  title: 'Pauta un entrenamiento',
                  topic: 'Agenda',
                  text: 'Elige una fecha.',
                  destination: 'Agenda',
                  path: '/agenda',
                  icon: Icons.calendar_month,
                ),
              ],
              onNavigate: (path) => destination = path,
              child: const Scaffold(
                body: Column(
                  children: [
                    ProfessionalGuideProgress(),
                    ProfessionalGuideButton(),
                  ],
                ),
              ),
            ),
          );

      await tester.pumpWidget(app(controller, home: false));
      await tester.pumpAndSettle();
      expect(find.text('Ver guía'), findsNothing);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(controller.hidden, isFalse);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      expect(find.text('Ver guía'), findsNothing);

      await tester.tap(find.text('Guía de uso'));
      await tester.pumpAndSettle();
      expect(find.text('Invita a tu primer alumno'), findsOneWidget);
      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Agenda')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.getSize(find.text('Agenda')).height,
        greaterThan(tester.getSize(find.text('Pauta un entrenamiento')).height),
      );
      await tester.tap(find.text('Pauta un entrenamiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No volver a mostrar al entrar'));
      await tester.tap(find.text('Ir a Agenda'));
      await tester.pumpAndSettle();
      expect(destination, '/agenda');
      expect(find.text('Elige una fecha.'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar recorrido'));
      await tester.pumpAndSettle();
      expect(find.text('Elige una fecha.'), findsNothing);

      final returning = create('trainer');
      await tester.pumpWidget(app(returning));
      await tester.pumpAndSettle();
      expect(find.text('Ver guía'), findsNothing);
      expect(create('admin').hidden, isFalse);
      expect(create('trainer', 'b').hidden, isFalse);
      await tester.tap(find.text('Guía de uso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No volver a mostrar al entrar'));
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(create('trainer').hidden, isFalse);
    },
  );
}
