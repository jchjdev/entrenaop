import 'package:entrenaop/features/trainers/presentation/trainer_conversation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_messages.dart';

class _Messages implements TrainerMessageRepository {
  int reads = 0;
  final relations = <String>[];
  @override
  Future<TrainerConversationContext> context(String id) async =>
      TrainerConversationContext.fromJson({
        'name': 'Preparador $id',
        'can_send': true,
      });
  @override
  Future<List<TrainerMessage>> list(
    String id, {
    DateTime? beforeAt,
    String? beforeId,
  }) async {
    reads++;
    relations.add(id);
    return [
      TrainerMessage.fromJson({
        'id': 'message-$reads',
        'body': 'Respuesta de $id número $reads',
        'sender_id': 'coach',
        'created_at': DateTime(2026, 10, 27, 10, reads).toIso8601String(),
      }, 'student'),
    ];
  }

  @override
  Future<void> send({
    required String operationId,
    required String relationId,
    required String body,
    String? assignmentId,
  }) async {}
}

void main() {
  testWidgets(
    'el chat del iPhone refresca, conserva el borrador y se pausa en segundo plano',
    (t) async {
      final repository = _Messages();
      await t.pumpWidget(
        MaterialApp(
          home: TrainerStudentConversationPage(
            repository: repository,
            relationId: 'strength',
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Tengo una duda de técnica');
      await t.pump(const Duration(seconds: 15));
      await t.pumpAndSettle();
      expect(repository.reads, 2);
      expect(find.text('Respuesta de strength número 2'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Tengo una duda de técnica',
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await t.pump(const Duration(seconds: 45));
      expect(repository.reads, 2);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(repository.reads, 3);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cambiar de preparador no conserva el historial de la otra conversación',
    (t) async {
      final repository = _Messages();
      Widget app(String id) => MaterialApp(
        home: TrainerStudentConversationPage(
          repository: repository,
          relationId: id,
        ),
      );
      await t.pumpWidget(app('strength'));
      await t.pumpAndSettle();
      expect(find.text('Respuesta de strength número 1'), findsOneWidget);
      await t.pumpWidget(app('running'));
      await t.pumpAndSettle();
      expect(find.textContaining('Respuesta de strength'), findsNothing);
      expect(find.text('Respuesta de running número 2'), findsOneWidget);
      await t.pump(const Duration(seconds: 15));
      await t.pumpAndSettle();
      expect(repository.relations, ['strength', 'running', 'running']);
      await t.pumpWidget(const SizedBox());
    },
  );
}
