abstract class WorkoutScheduleRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRange(String start, String end);

  Future<String> schedule(
    String templateId,
    String date, {
    String? time,
  });

  Future<void> reschedule(
    String scheduledId,
    String date, {
    String? time,
  });

  Future<void> cancel(String scheduledId);

  Future<String> start(String scheduledId);
}
