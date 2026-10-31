import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_core/device_activity_summary.dart';

import '../../../core/config/app_config.dart';
import '../domain/apple_training.dart';
import '../domain/apple_results.dart';

class SupabaseAppleTrainingRepository implements AppleTrainingRepository {
  SupabaseAppleTrainingRepository(this.client, this.ownerId)
    : _session = client.auth.currentSession?.accessToken;
  final SupabaseClient client;
  @override
  final String ownerId;
  final String? _session;
  @override
  bool get isCurrent =>
      _session != null &&
      _identity(_session) != null &&
      client.auth.currentUser?.id == ownerId &&
      _identity(client.auth.currentSession?.accessToken) == _identity(_session);
  String? _identity(String? token) {
    try {
      return (jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token!.split('.')[1])),
            ),
          ) as Map)['session_id']
          as String?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, Object?> input = const {},
  ]) async {
    if (!isCurrent) throw const AppleTrainingFailure('account_changed');
    final token = client.auth.currentSession!.accessToken;
    try {
      final r = await client.functions.invoke(
        'apple-training',
        headers: {'Authorization': 'Bearer $token'},
        body: {'owner': ownerId, 'action': action, 'input': input},
      );
      if (!isCurrent) throw const AppleTrainingFailure('account_changed');
      if (r.status != 200 || r.data is! Map) {
        throw const AppleTrainingFailure('apple_unavailable');
      }
      return Map<String, dynamic>.from(r.data as Map);
    } on FunctionException catch (e) {
      if (!isCurrent) throw const AppleTrainingFailure('account_changed');
      final code = e.details is Map ? (e.details as Map)['code'] : null;
      throw AppleTrainingFailure(code is String ? code : 'apple_unavailable');
    }
  }

  @override
  Future<AppleCatalog> load() async {
    final d = await call('list');
    return AppleCatalog(
      d['allowed'] == true,
      [
        for (final v in d['candidates'] as List)
          AppleCandidate(
            v['id'] as String,
            v['name'] as String,
            v['date'] as String,
          ),
      ],
      [
        for (final v in d['deliveries'] as List)
          AppleReceipt(
            v['id'] as String,
            v['name'] as String,
            v['date'] as String,
            v['revision'] as String,
            v['status'] as String,
            v['needs_removal'] == true,
            v['started'] == true,
          ),
      ],
    );
  }

  ApplePlan _plan(Map<String, dynamic> d) {
    final p = d['prescription'] as Map;
    return ApplePlan(
      ApplePrescription(p['name'] as String, p['date'] as String, [
        for (final s in p['steps'] as List)
          AppleStep(
            s['kind'] as String,
            s['measure'] as String,
            s['value'] as num?,
            s['description'] as String,
            (s['pace'] as Map?)?['fast'] as num?,
            (s['pace'] as Map?)?['slow'] as num?,
          ),
      ]),
      d['revision'] as String,
      d['plan_id'] as String?,
      d['attempt_id'] as String?,
    );
  }

  @override
  Future<ApplePlan> preview(String id) async =>
      _plan(await call('preview', {'scheduled_id': id}));
  @override
  Future<ApplePlan> prepare(String id, String revision) async => _plan(
    await call('prepare', {
      'scheduled_id': id,
      'revision': revision,
      'attempt_id': const Uuid().v4(),
    }),
  );
  @override
  Future<void> record(String id, ApplePlan plan) async {
    await call('record', {
      'scheduled_id': id,
      'revision': plan.revision,
      'attempt_id': plan.attemptId,
    });
  }

  @override
  Future<AppleRemoval> removal(String id) async {
    final d = await call('removal', {'scheduled_id': id});
    return AppleRemoval(
      d['plan_id'] as String,
      d['revision'] as String,
      d['attempt_id'] as String,
    );
  }

  @override
  Future<void> removed(String id, AppleRemoval removal) async {
    await call('removed', {
      'scheduled_id': id,
      'revision': removal.revision,
      'attempt_id': removal.attemptId,
    });
  }
}

class SupabaseAppleResultsRepository implements AppleResultsRepository {
  SupabaseAppleResultsRepository(SupabaseClient client, String owner)
    : _training = SupabaseAppleTrainingRepository(client, owner);
  final SupabaseAppleTrainingRepository _training;
  @override
  bool get isCurrent => _training.isCurrent;
  @override
  Future<AppleResultCatalog> load() async {
    final d = await _training.call('results.catalog');
    return AppleResultCatalog(
      d['enabled'] == true,
      [
        for (final plan in d['plans'] as List)
          _training._plan(Map<String, dynamic>.from(plan as Map)),
      ],
      [
        for (final row in d['results'] as List)
          DeviceActivitySummary.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
    );
  }

  @override
  Future<void> enable(bool enabled) async {
    await _training.call('results.enable', {'enabled': enabled});
  }

  @override
  Future<void> classify(String id, bool isTest) async {
    await _training.call('results.classify', {'id': id, 'is_test': isTest});
  }

  @override
  Future<void> ingest(List<AppleResultObservation> observations) async {
    await _training.call('results.ingest', {
      'observations': [
        for (final r in observations)
          {
            'workout_id': r.workoutId,
            'plan_id': r.planId,
            'revision': r.revision,
            'matches_prescription': r.matchesPrescription,
            'started_at': r.startedAt.toUtc().toIso8601String(),
            'ended_at': r.endedAt.toUtc().toIso8601String(),
            'timer_seconds': r.seconds,
            if (r.meters != null) 'distance_meters': r.meters,
            if (r.averageHeartRate != null)
              'average_heart_rate': r.averageHeartRate,
            if (r.maxHeartRate != null) 'max_heart_rate': r.maxHeartRate,
            if (r.effortScore != null) 'effort_score': r.effortScore,
            if (r.offsetMinutes != null) 'offset_minutes': r.offsetMinutes,
            if (r.intervals.isNotEmpty)
              'intervals': [
                for (final s in r.intervals)
                  {
                    'id': s.id,
                    'started_at': s.startedAt.toUtc().toIso8601String(),
                    'ended_at': s.endedAt.toUtc().toIso8601String(),
                    'timer_seconds': s.seconds,
                    if (s.meters != null) 'distance_meters': s.meters,
                    if (s.averageHeartRate != null)
                      'average_heart_rate': s.averageHeartRate,
                    if (s.maxHeartRate != null)
                      'max_heart_rate': s.maxHeartRate,
                  },
              ],
            if (r.markers.isNotEmpty)
              'markers': [
                for (final m in r.markers)
                  {
                    'kind': m.kind,
                    'started_at': m.startedAt.toUtc().toIso8601String(),
                    'ended_at': m.endedAt.toUtc().toIso8601String(),
                  },
              ],
          },
      ],
    });
  }
}

class NativeAppleResultsReader implements AppleResultsReader {
  const NativeAppleResultsReader();
  @override
  bool get supported => const NativeAppleWorkoutScheduler()._supported;
  @override
  Future<void> authorize() async {
    final data = await const NativeAppleWorkoutScheduler()._call(
      'results.authorize',
    );
    if (data['requested'] != true) {
      throw const AppleTrainingFailure('health_unavailable');
    }
  }

  @override
  Future<List<AppleResultObservation>> read(List<ApplePlan> plans) async {
    final data = await const NativeAppleWorkoutScheduler()._call(
      'results.read',
      {
        'plans': [
          for (final plan in plans)
            {
              'plan_id': plan.planId,
              'revision': plan.revision,
              'prescription': _applePrescription(plan.prescription),
            },
        ],
      },
    );
    final rows = data['observations'];
    if (rows is! List || rows.length > 200) {
      throw const AppleTrainingFailure('health_unavailable');
    }
    return [
      for (final row in rows)
        AppleResultObservation(
          workoutId: row['workout_id'] as String,
          planId: row['plan_id'] as String,
          revision: row['revision'] as String,
          matchesPrescription: row['matches_prescription'] == true,
          startedAt: DateTime.parse(row['started_at'] as String),
          endedAt: DateTime.parse(row['ended_at'] as String),
          seconds: (row['timer_seconds'] as num).toDouble(),
          meters: (row['distance_meters'] as num?)?.toDouble(),
          averageHeartRate: (row['average_heart_rate'] as num?)?.toDouble(),
          maxHeartRate: (row['max_heart_rate'] as num?)?.toDouble(),
          effortScore: (row['effort_score'] as num?)?.toDouble(),
          offsetMinutes: row['offset_minutes'] as int?,
          intervals: [
            for (final s in row['intervals'] as List? ?? [])
              AppleResultInterval(
                s['id'] as String,
                DateTime.parse(s['started_at'] as String),
                DateTime.parse(s['ended_at'] as String),
                (s['timer_seconds'] as num).toDouble(),
                meters: (s['distance_meters'] as num?)?.toDouble(),
                averageHeartRate: (s['average_heart_rate'] as num?)?.toDouble(),
                maxHeartRate: (s['max_heart_rate'] as num?)?.toDouble(),
              ),
          ],
          markers: [
            for (final m in row['markers'] as List? ?? [])
              AppleResultMarker(
                m['kind'] as String,
                DateTime.parse(m['started_at'] as String),
                DateTime.parse(m['ended_at'] as String),
              ),
          ],
        ),
    ];
  }
}

Map<String, Object?> _applePrescription(ApplePrescription p) => {
  'name': p.name,
  'date': p.date,
  'steps': [
    for (final s in p.steps)
      {
        'kind': s.kind,
        'measure': s.measure,
        'value': s.value,
        'description': s.description,
        if (s.fast != null && s.slow != null)
          'pace': {'fast': s.fast, 'slow': s.slow},
      },
  ],
};

class NativeAppleWorkoutScheduler implements AppleWorkoutScheduler {
  const NativeAppleWorkoutScheduler();
  static const _channel = MethodChannel('es.entrenaop.device_health/reader');
  bool get _supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      AppConfig.environment == AppEnvironment.development;
  Future<Map<Object?, Object?>> _call(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    if (!_supported) throw const AppleTrainingFailure('unsupported');
    try {
      return (await _channel.invokeMapMethod<Object?, Object?>(
            'apple.$method',
            args,
          )) ??
          {};
    } on PlatformException catch (e) {
      throw AppleTrainingFailure(e.code);
    } on MissingPluginException {
      throw const AppleTrainingFailure('update_required');
    }
  }

  Future<AppleAuthorization> _authorization(String method) async {
    if (!_supported) return AppleAuthorization.unsupported;
    final d = await _call(method);
    return AppleAuthorization.values.firstWhere(
      (v) => v.name == d['state'],
      orElse: () => AppleAuthorization.unsupported,
    );
  }

  @override
  Future<AppleAuthorization> status() => _authorization('status');
  @override
  Future<AppleAuthorization> authorize() => _authorization('authorize');
  String _scope(String owner) => sha256.convert(utf8.encode(owner)).toString();
  @override
  Future<void> schedule(String owner, ApplePlan plan) async {
    final p = plan.prescription;
    final result = await _call('schedule', {
      'owner': _scope(owner),
      'plan_id': plan.planId,
      'prescription': {
        'name': p.name,
        'date': p.date,
        'steps': [
          for (final s in p.steps)
            {
              'kind': s.kind,
              'measure': s.measure,
              'value': s.value,
              'description': s.description,
              if (s.fast != null && s.slow != null)
                'pace': {'fast': s.fast, 'slow': s.slow},
            },
        ],
      },
    });
    if (result['submitted'] != true) {
      throw const AppleTrainingFailure('delivery_uncertain');
    }
  }

  @override
  Future<void> remove(String owner, String planId) async {
    final result = await _call('remove', {
      'owner': _scope(owner),
      'plan_id': planId,
    });
    if (result['removed'] != true) {
      throw const AppleTrainingFailure('delivery_uncertain');
    }
  }
}
