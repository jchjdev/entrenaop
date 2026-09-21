abstract class WorkoutRemoteDataSource {
  Future<Map<String, dynamic>?> getTemplateById(String id);

  Future<String> startExecution(String templateId);

  Future<Map<String, dynamic>?> getExecution(String executionId);

  Future<List<Map<String, dynamic>>> getExecutionHistory();

  Future<void> completeSet(String operationId, Map<String, dynamic> values);

  Future<void> correctSet(Map<String, dynamic> values);

  Future<void> skipSet(String operationId, String resultId);

  Future<void> finishExecution(
    String operationId,
    String executionId, {
    required int finalRpe,
    String? notes,
  });

  Future<void> abandonExecution(
    String operationId,
    String executionId,
    String reason,
  );
}
