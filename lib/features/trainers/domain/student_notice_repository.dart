enum StudentNoticeKind {
  message,
  form,
  assessment,
  techniqueFeedback,
  assignment,
}

enum StudentNoticeTargetKind {
  conversation,
  form,
  assessment,
  technique,
  workout,
}

class StudentNotice {
  const StudentNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.readAt,
  });
  final String id, title;
  final StudentNoticeKind kind;
  final DateTime createdAt;
  final DateTime? readAt;
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

class StudentNoticeResources {
  const StudentNoticeResources({
    this.hasForms = false,
    this.hasAssessments = false,
    this.hasConversations = false,
    this.hasTechnique = false,
    this.hasAssignedWorkouts = false,
    this.conversationRelationId,
  });
  final bool hasForms, hasAssessments, hasConversations, hasTechnique;
  final bool hasAssignedWorkouts;
  final String? conversationRelationId;

  bool get hasContent =>
      hasForms ||
      hasAssessments ||
      hasConversations ||
      hasTechnique ||
      hasAssignedWorkouts;
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
  Future<void> ack(String noticeId);
  Future<StudentNoticeTarget?> resolve(String noticeId);
  Future<TechniqueTargetPage> listTechnique({TechniqueTarget? before});
}
