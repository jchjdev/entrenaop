import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RunningIntakeContextRepository {
  const RunningIntakeContextRepository(this._client);

  final SupabaseClient _client;

  Future<RunningInitialContext?> get({
    required String goalId,
    required String programId,
  }) async {
    final row = await _client
        .from('running_intake_contexts')
        .select()
        .eq('preparation_goal_id', goalId)
        .maybeSingle();
    if (row == null) return null;
    final availability = (row['available_minutes_by_weekday'] as Map).map(
      (key, value) =>
          MapEntry(int.parse(key as String), (value as num).toInt()),
    );
    final days = (row['running_days_last_four_weeks'] as List)
        .map((value) => (value as num).toInt())
        .toList();
    final minutes = (row['running_minutes_last_four_weeks'] as List)
        .map((value) => (value as num).toInt())
        .toList();
    final end = DateTime.parse(row['recent_weeks_end_on'] as String);
    return RunningInitialContext(
      goalId: goalId,
      programId: programId,
      collectedAt: DateTime.parse(row['updated_at'] as String),
      availableMinutesByWeekday: availability,
      reservedStrengthWeekdays: (row['reserved_strength_weekdays'] as List)
          .map((value) => (value as num).toInt())
          .toSet(),
      recentRunningWeeks: [
        for (var index = 0; index < days.length; index++)
          RecentRunningWeek(
            weekStart: end.subtract(Duration(days: 6 + index * 7)),
            runningDays: days[index],
            runningMinutes: minutes[index],
          ),
      ],
      health: RunningHealthCheck(
        observedAt: DateTime.parse(row['health_observed_at'] as String),
        reportsPain: row['reports_pain'] as bool,
        requiresProfessionalReview: row['requires_professional_review'] as bool,
      ),
      reference: null,
      targetTwoKilometreSeconds: (row['target_2k_seconds'] as num?)?.toInt(),
      officialMarginSeconds: (row['official_margin_seconds'] as num?)?.toInt(),
      comfortableContinuousMinutes:
          (row['comfortable_continuous_minutes'] as num?)?.toInt(),
      qualityWeeksLastFour:
          (row['quality_weeks_last_four'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> save(RunningInitialContext context) async {
    if (context.recentRunningWeeks.length != 4 || context.health == null) {
      throw ArgumentError('Faltan las cuatro semanas o la respuesta de salud.');
    }
    final issues = context.inspect(now: DateTime.now());
    if (issues.any(
      (issue) =>
          issue != RunningContextIssue.missingReference &&
          issue != RunningContextIssue.healthReview,
    )) {
      throw ArgumentError('El contexto de carrera contiene datos inválidos.');
    }
    await _client.from('running_intake_contexts').upsert({
      'preparation_goal_id': context.goalId,
      'target_2k_seconds': context.targetTwoKilometreSeconds,
      'goal_mode': context.officialMarginSeconds != null
          ? 'official_margin'
          : context.targetTwoKilometreSeconds != null
          ? 'time'
          : 'improve',
      'official_margin_seconds': context.officialMarginSeconds,
      'context_version': context.comfortableContinuousMinutes == null
          ? 'running_initial_context_v1'
          : RunningInitialContext.version,
      'comfortable_continuous_minutes': context.comfortableContinuousMinutes,
      'quality_weeks_last_four': context.qualityWeeksLastFour,
      'available_minutes_by_weekday': {
        for (final entry in context.availableMinutesByWeekday.entries)
          '${entry.key}': entry.value,
      },
      'reserved_strength_weekdays': context.reservedStrengthWeekdays.toList()
        ..sort(),
      'running_days_last_four_weeks': [
        for (final week in context.recentRunningWeeks) week.runningDays,
      ],
      'running_minutes_last_four_weeks': [
        for (final week in context.recentRunningWeeks) week.runningMinutes,
      ],
      'recent_weeks_end_on': context.recentRunningWeeks.first.weekStart
          .add(const Duration(days: 6))
          .toIso8601String()
          .substring(0, 10),
      'reports_pain': context.health!.reportsPain,
      'requires_professional_review':
          context.health!.requiresProfessionalReview,
      'health_observed_at': context.health!.observedAt
          .toUtc()
          .toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
