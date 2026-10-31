import '../../device_activity_results/data/activity_result_codec.dart';
import '../../device_activity_results/domain/activity_result.dart';
import 'apple_training_adapters.dart';
import '../domain/apple_training.dart';

/// El cierre utiliza el contrato de revisión común; nunca depende de Garmin.
class AppleActivityResultRepository implements ActivityResultRepository {
  const AppleActivityResultRepository(this.transport);
  final SupabaseAppleTrainingRepository transport;
  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, Object?> fields = const {},
  ]) async {
    try {
      return await transport.call(action, fields);
    } on AppleTrainingFailure catch (e) {
      throw ActivityResultException(e.code);
    }
  }

  @override
  Future<ActivityResultCatalog> load() async {
    final data = await _call('results.catalog');
    final rows = (data['results'] as List).cast<Map>();
    return ActivityResultCatalog(
      [
        for (final r in rows)
          ReceivedRun(
            r['id'] as String,
            '',
            r['name'] as String,
            DateTime.parse(r['started_at'] as String),
            (r['timer_seconds'] as num).toDouble(),
            (r['distance_meters'] as num?)?.toDouble(),
            r['execution_id'] as String?,
            scheduledId: r['scheduled_id'] as String,
          ),
      ],
      {
        for (final r in rows)
          r['scheduled_id'] as String: RunAppointment(
            r['scheduled_id'] as String,
            r['name'] as String,
            r['scheduled_date'] as String,
          ),
      }.values.toList(),
      [],
    );
  }

  @override
  Future<ActivityResultReview> preview(
    String activityId,
    String scheduledId,
  ) async => decodeActivityReview(
    await _call('results.preview', {
      'activity_id': activityId,
      'scheduled_id': scheduledId,
    }),
  );
  @override
  Future<String> confirm(ConfirmActivityResult request) async {
    final data = await _call('results.confirm', {
      'operation_id': request.operationId,
      'activity_id': request.review.activityId,
      'scheduled_id': request.review.scheduledId,
      'activity_revision': request.review.activityRevision,
      'source_revision': request.review.sourceRevision,
      'rpe': request.rpe,
      'utc_offset_minutes': request.offsetMinutes,
      'mapping': [
        for (final row in request.rows)
          {
            'block_order': row.block,
            'item_order': row.item,
            'set_order': row.set,
            'skipped': row.skipped,
            'lap_indices': row.skipped ? <int>[] : row.laps,
            'recovery_lap_indices': row.skipped ? <int>[] : row.recoveryLaps,
          },
      ],
    });
    return data['execution_id'] as String;
  }
}
