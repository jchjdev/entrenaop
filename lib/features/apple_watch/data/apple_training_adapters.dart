import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../domain/apple_training.dart';

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

  Future<Map<String, dynamic>> _call(
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
    final d = await _call('list');
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
      _plan(await _call('preview', {'scheduled_id': id}));
  @override
  Future<ApplePlan> prepare(String id, String revision) async => _plan(
    await _call('prepare', {
      'scheduled_id': id,
      'revision': revision,
      'attempt_id': const Uuid().v4(),
    }),
  );
  @override
  Future<void> record(String id, ApplePlan plan) async {
    await _call('record', {
      'scheduled_id': id,
      'revision': plan.revision,
      'attempt_id': plan.attemptId,
    });
  }

  @override
  Future<AppleRemoval> removal(String id) async {
    final d = await _call('removal', {'scheduled_id': id});
    return AppleRemoval(
      d['plan_id'] as String,
      d['revision'] as String,
      d['attempt_id'] as String,
    );
  }

  @override
  Future<void> removed(String id, AppleRemoval removal) async {
    await _call('removed', {
      'scheduled_id': id,
      'revision': removal.revision,
      'attempt_id': removal.attemptId,
    });
  }
}

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
