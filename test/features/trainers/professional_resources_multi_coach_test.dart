import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:entrenaop/features/trainers/presentation/widgets/professional_resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'abre la conversación del preparador elegido sin elegir el último por defecto',
    (tester) async {
      final paths = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalResources(
              resources: const StudentNoticeResources(
                hasConversations: true,
                conversations: [
                  StudentConversationLink('fuerza', 'Javier'),
                  StudentConversationLink('carrera', 'Ervi'),
                ],
              ),
              onOpen: (route) async => paths.add(route),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Conversación con Javier'));
      await tester.tap(find.text('Conversación con Ervi'));
      expect(paths, [
        '/my-trainer/conversations/fuerza',
        '/my-trainer/conversations/carrera',
      ]);
      expect(find.text('Conversación'), findsNothing);
    },
  );
}
