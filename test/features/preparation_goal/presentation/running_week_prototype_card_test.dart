import 'package:entrenaop/features/preparation_goal/presentation/widgets/running_week_prototype_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'la maqueta se distingue de sesiones reales y muestra el detalle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RunningWeekPrototypeCard()),
          ),
        ),
      );

      expect(find.text('Laboratorio · semana de ejemplo'), findsOneWidget);
      expect(find.text('Calidad controlada'), findsOneWidget);
      expect(find.text('Fuerza'), findsOneWidget);
      expect(find.text('Carrera fácil'), findsOneWidget);
      expect(find.textContaining('no se añade a tu agenda'), findsOneWidget);
      expect(find.text('Registrar resultado'), findsNothing);

      await tester.tap(find.text('Calidad controlada'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 × 2 min'), findsOneWidget);
      expect(find.textContaining('umbral calculado'), findsOneWidget);
    },
  );
}
