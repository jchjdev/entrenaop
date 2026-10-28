enum StudentNoticeKind {
  message,
  form,
  assessment,
  techniqueFeedback,
  assignment,
  appointment,
}

enum StudentNoticeTargetKind {
  conversation,
  form,
  assessment,
  technique,
  workout,
  planning,
  appointment,
}

class StudentNotice {
  const StudentNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.readAt,
    this.groupGeneration,
    this.eventCount = 1,
    this.newCount = 1,
    this.trainerName,
  });
  final String id, title;
  final StudentNoticeKind kind;
  final DateTime createdAt;
  final DateTime? readAt;
  final int? groupGeneration;
  final int eventCount, newCount;
  final String? trainerName;
}

class StudentNoticeTarget {
  const StudentNoticeTarget({
    required this.kind,
    required this.targetId,
    this.scheduledDate,
  });
  final StudentNoticeTargetKind kind;
  final String targetId;
  final DateTime? scheduledDate;
}

class StudentConversationLink {
  const StudentConversationLink(this.relationId, this.trainerName);
  final String relationId, trainerName;
}

class StudentNoticeResources {
  const StudentNoticeResources({
    this.hasForms = false,
    this.hasAssessments = false,
    this.hasConversations = false,
    this.hasTechnique = false,
    this.hasAssignedWorkouts = false,
    this.hasAppointments = false,
    this.conversationRelationId,
    this.conversations = const [],
  });
  final bool hasForms, hasAssessments, hasConversations, hasTechnique;
  final bool hasAssignedWorkouts;
  final bool hasAppointments;
  final String? conversationRelationId;
  final List<StudentConversationLink> conversations;

  bool get hasContent =>
      hasForms ||
      hasAssessments ||
      hasConversations ||
      hasTechnique ||
      hasAssignedWorkouts ||
      hasAppointments;
}

class StudentNoticeSnapshot {
  const StudentNoticeSnapshot({
    required this.items,
    required this.hasMore,
    required this.unreadCount,
    required this.resources,
  });
  final List<StudentNotice> items;
  final bool hasMore;
  // El total procede del servidor; nunca se infiere de una página del feed.
  final int unreadCount;
  final StudentNoticeResources resources;
}

class TechniqueTarget {
  const TechniqueTarget({
    required this.executionId,
    required this.sessionName,
    required this.startedAt,
  });
  final String executionId, sessionName;
  final DateTime startedAt;
}

class TechniqueTargetPage {
  const TechniqueTargetPage({required this.items, required this.hasMore});
  final List<TechniqueTarget> items;
  final bool hasMore;
}

/// Lecturas propias del alumno y confirmación explícita de avisos.
/// Resolver comprueba de nuevo el destino; consultar o abrir no lo marca leído.
abstract class StudentNoticeRepository {
  Future<StudentNoticeSnapshot> snapshot({
    StudentNotice? before,
    StudentNoticeKind? kind,
  });
  Future<void> ack(String noticeId, {int? generation});
  Future<StudentNoticeTarget?> resolve(String noticeId, {int? generation});
  Future<TechniqueTargetPage> listTechnique({TechniqueTarget? before});
}
