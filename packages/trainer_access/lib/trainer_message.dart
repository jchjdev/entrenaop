/// Mensaje compartido por el primer contacto y el seguimiento de alumnos.
class TrainerMessage {
  TrainerMessage.fromJson(Map<String, dynamic> row, String userId)
    : id = row['id'] as String,
      body = row['body'] as String,
      mine = row['sender_id'] == userId,
      createdAt = DateTime.parse(row['created_at'] as String),
      assignmentId = row['assignment_id'] as String?;
  final String id, body;
  final bool mine;
  final DateTime createdAt;
  final String? assignmentId;
}
