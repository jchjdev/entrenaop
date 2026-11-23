abstract class WorkoutScheduleRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRange(String start, String end);
  Future<Map<String, dynamic>?> getByResult(String executionId);

  Future<String> schedule(String templateId, String date, {String? time});

  Future<void> reschedule(String scheduledId, String date, {String? time});

  Future<void> cancel(String scheduledId);

  Future<String> start(String scheduledId);

  Future<String> repeat(String scheduledId);
}
