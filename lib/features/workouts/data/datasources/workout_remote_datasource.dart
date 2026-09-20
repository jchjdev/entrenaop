abstract class WorkoutRemoteDataSource {
  Future<Map<String, dynamic>?> getTemplateById(String id);

  Future<String> startExecution(String templateId);

  Future<Map<String, dynamic>?> getExecution(String executionId);

  Future<List<Map<String, dynamic>>> getExecutionHistory();

  Future<void> completeSet(Map<String, dynamic> values);

  Future<void> correctSet(Map<String, dynamic> values);

  Future<void> skipSet(String resultId);

  Future<void> finishExecution(
    String executionId, {
    required int finalRpe,
    String? notes,
  });

  Future<void> abandonExecution(String executionId, String reason);
}
