import 'package:flutter/material.dart';

import '../../domain/student_notice_repository.dart';

class ProfessionalResources extends StatelessWidget {
  const ProfessionalResources({
    super.key,
    required this.resources,
    required this.onOpen,
  });
  final StudentNoticeResources resources;
  final Future<void> Function(String) onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (resources.hasAssignedWorkouts)
        _link(
          Icons.calendar_month_outlined,
          'Sesiones de mi preparador',
          'Consulta tus pautas en la agenda',
          '/plan/week',
        ),
      if (resources.hasForms)
        _link(
          Icons.assignment_outlined,
          'Formularios',
          'Revisiones recibidas y respuestas',
          '/my-trainer/forms',
        ),
      if (resources.hasAssessments)
        _link(
          Icons.timer_outlined,
          'Pruebas',
          'Protocolos y marcas de tu preparador',
          '/my-trainer/assessments',
        ),
      if (resources.hasConversations)
        _link(
          Icons.chat_bubble_outline,
          'Conversación',
          'Mensajes con tu preparador',
          resources.conversationRelationId != null
              ? '/my-trainer/conversations/${Uri.encodeComponent(resources.conversationRelationId!)}'
              : '/profile/trainer',
        ),
      if (resources.hasTechnique)
        _link(
          Icons.video_library_outlined,
          'Técnica de mis sesiones',
          'Envía vídeos y consulta las respuestas',
          '/my-trainer/technique',
        ),
    ],
  );

  Widget _link(IconData icon, String title, String subtitle, String route) =>
      Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpen(route),
        ),
      );
}
