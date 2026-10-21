import 'package:entrena_ui/conversation_view.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_messages.dart';

class TrainerStudentConversationPage extends StatelessWidget {
  const TrainerStudentConversationPage({
    super.key,
    required this.repository,
    required this.relationId,
  });
  final TrainerMessageRepository repository;
  final String relationId;
  @override
  Widget build(BuildContext context) => ConversationView(
    header: () async {
      final detail = await repository.context(relationId);
      return ConversationHeader(title: detail.name, canSend: detail.canSend);
    },
    load: (before) async =>
        (await repository.list(
              relationId,
              beforeAt: before?.createdAt,
              beforeId: before?.id,
            ))
            .map(
              (m) => ConversationEntry(
                id: m.id,
                body: m.body,
                createdAt: m.createdAt,
                mine: m.mine,
                contextLabel: m.assignmentId == null
                    ? null
                    : 'Sobre una pauta de tu preparación',
              ),
            )
            .toList(),
    send: (id, body) =>
        repository.send(operationId: id, relationId: relationId, body: body),
    newOperationId: trainerMessageOperationId,
    errorLabel: trainerError,
  );
}
