typedef AssignedProgramCursor = ({DateTime createdAt, String id});

class StudentAssignedProgram {
  const StudentAssignedProgram({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.trainerName,
    required this.total,
    required this.completed,
    this.description,
    this.note,
    this.phases = const [],
  });

  final String id, name, trainerName;
  final DateTime createdAt;
  final int total, completed;
  final String? description, note;
  final List<StudentAssignedPhase> phases;

  AssignedProgramCursor get cursor => (createdAt: createdAt, id: id);
}

class StudentAssignedPhase {
  const StudentAssignedPhase(this.name, this.instructions, this.sessions);
  final String name;
  final String? instructions;
  final List<StudentAssignedSession> sessions;

  int get completed =>
      sessions.where((session) => session.status == 'completed').length;
}

class StudentAssignedSession {
  const StudentAssignedSession(this.id, this.name, this.date, this.status);
  final String id, name, status;
  final DateTime date;
}

abstract interface class StudentAssignedProgramsRepository {
  Future<({List<StudentAssignedProgram> items, bool hasMore})> list({
    AssignedProgramCursor? before,
  });
  Future<StudentAssignedProgram?> get(String deliveryId);
}
