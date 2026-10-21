import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_activity_core/device_activity_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/local_running_health.dart';

final class NativeRunningHealth implements LocalRunningHealth {
  NativeRunningHealth({
    required this.ownerId,
    required this.platform,
    this.nativeIntegrationEnabled = true,
    this.channel = const MethodChannel('es.entrenaop.device_health/reader'),
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError('Se necesita un ámbito local de titular');
    }
  }

  /// Android conserva su ensayo propio; no eleva el mínimo de la app anfitriona.
  factory NativeRunningHealth.forCurrentPlatform({required String ownerId}) =>
      NativeRunningHealth(
        ownerId: ownerId,
        platform: kIsWeb
            ? LocalHealthPlatform.unsupported
            : switch (defaultTargetPlatform) {
                TargetPlatform.iOS => LocalHealthPlatform.appleHealth,
                TargetPlatform.android => LocalHealthPlatform.healthConnect,
                _ => LocalHealthPlatform.unsupported,
              },
        nativeIntegrationEnabled:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      );

  final String ownerId;
  final bool nativeIntegrationEnabled;

  @override
  final LocalHealthPlatform platform;
  final MethodChannel channel;
  final DateTime Function() _nowUtc;

  @override
  Future<HealthStoreAvailability> availability() async {
    if (platform == LocalHealthPlatform.unsupported) {
      return HealthStoreAvailability.unsupported;
    }
    if (!nativeIntegrationEnabled) return HealthStoreAvailability.notIntegrated;
    return switch (await _invoke('status')) {
      'available' => HealthStoreAvailability.available,
      'updateRequired' => HealthStoreAvailability.updateRequired,
      'unavailable' => HealthStoreAvailability.unavailable,
      _ => throw const HealthReadException(HealthReadProblem.invalidResponse),
    };
  }

  @override
  Future<HealthReadConsent> requestReadAccess() async =>
      switch (await _invoke('requestReadAccess')) {
        'granted' when platform == LocalHealthPlatform.healthConnect =>
          HealthReadConsent.granted,
        'queryAllowedUnknown'
            when platform == LocalHealthPlatform.appleHealth =>
          HealthReadConsent.queryAllowedUnknown,
        'denied' => HealthReadConsent.denied,
        _ => throw const HealthReadException(HealthReadProblem.invalidResponse),
      };

  @override
  Future<LocalHealthRead> read({
    required HealthReadWindow window,
    required String localSessionScope,
  }) async {
    if (platform == LocalHealthPlatform.unsupported ||
        !nativeIntegrationEnabled) {
      throw const HealthReadException(HealthReadProblem.unavailable);
    }
    final raw = await _invoke('readRuns', {
      'startMicros': window.startUtc.microsecondsSinceEpoch,
      'endMicros': window.endUtc.microsecondsSinceEpoch,
    });
    if (raw is! Map ||
        raw['runs'] is! List ||
        raw['truncated'] is! bool ||
        (raw['runs'] as List).length > 200) {
      throw const HealthReadException(HealthReadProblem.invalidResponse);
    }
    final received = _nowUtc();
    final activities = <ExternalActivity>[];
    final seen = <ActivityIdentity>{};
    var rejected = 0;
    for (final item in raw['runs'] as List) {
      try {
        if (item is! Map) throw const FormatException();
        final activity = _normalize(item, localSessionScope, received);
        if (activity.startedAtUtc!.isBefore(window.startUtc) ||
            activity.endedAtUtc!.isAfter(window.endUtc) ||
            activity.issues.isNotEmpty ||
            !seen.add(activity.identity)) {
          rejected++;
        } else {
          activities.add(activity);
        }
      } on FormatException {
        rejected++;
      } on ArgumentError {
        rejected++;
      }
    }
    return LocalHealthRead(
      activities: activities,
      rejectedRecords: rejected,
      truncated: raw['truncated'] as bool,
    );
  }

  ExternalActivity _normalize(Map raw, String scope, DateTime received) {
    if (raw['kind'] != 'running') throw const FormatException();
    final id = _string(raw['id']);
    final start = _date(raw['startMicros']);
    final end = _date(raw['endMicros']);
    final source = _optionalString(raw['writerApplication']);
    final startOffset = _offset(raw['startOffsetSeconds']);
    final endOffset = _offset(raw['endOffsetSeconds']);
    final zone = _optionalString(raw['timeZoneId']);
    final brand = _optionalString(raw['deviceBrand']);
    final modified = raw['modifiedMicros'] == null
        ? null
        : _date(raw['modifiedMicros']);
    final double? distance;
    final Duration? timer;
    if (platform == LocalHealthPlatform.appleHealth) {
      distance = _optionalNumber(raw['distanceMeters']);
      timer = raw['timerMicros'] == null
          ? null
          : Duration(microseconds: _integer(raw['timerMicros']));
    } else {
      // ExerciseSessionRecord no atribuye un total de distancia o pausas.
      distance = null;
      timer = null;
    }
    final signature = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              'native-probe-v1',
              id,
              start.microsecondsSinceEpoch,
              end.microsecondsSinceEpoch,
              source,
              startOffset?.inSeconds,
              endOffset?.inSeconds,
              zone,
              brand,
              modified?.microsecondsSinceEpoch,
              distance,
              timer?.inMicroseconds,
            ]),
          ),
        )
        .toString();
    return ExternalActivity(
      identity: ActivityIdentity(
        ownerId: ownerId,
        channel: platform == LocalHealthPlatform.appleHealth
            ? ActivityChannel.appleHealth
            : ActivityChannel.healthConnect,
        accountScope: scope,
        externalId: id,
      ),
      revision: ActivityRevision(
        'native-probe-v1:$signature',
        modifiedAtUtc: modified,
      ),
      receivedAtUtc: received,
      sport: ActivitySport.running,
      startedAtUtc: start,
      endedAtUtc: end,
      startUtcOffset: startOffset,
      endUtcOffset: endOffset,
      timeZoneId: zone,
      deviceBrand: brand,
      writerApplication: source,
      metrics: ActivityMetrics(
        elapsed: end.difference(start),
        timer: timer,
        distanceMeters: distance,
      ),
    );
  }

  Future<Object?> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (platform == LocalHealthPlatform.unsupported ||
        !nativeIntegrationEnabled) {
      throw const HealthReadException(HealthReadProblem.unavailable);
    }
    try {
      return await channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      throw const HealthReadException(HealthReadProblem.unavailable);
    } on PlatformException catch (error) {
      throw HealthReadException(switch (error.code) {
        'permissionRequired' => HealthReadProblem.permissionRequired,
        'unavailable' => HealthReadProblem.unavailable,
        _ => HealthReadProblem.readFailed,
      });
    }
  }
}

int _integer(Object? value) {
  if (value is! int) throw const FormatException();
  return value;
}

DateTime _date(Object? value) =>
    DateTime.fromMicrosecondsSinceEpoch(_integer(value), isUtc: true);

String _string(Object? value) {
  if (value is! String || value.trim().isEmpty) throw const FormatException();
  return value;
}

String? _optionalString(Object? value) => value == null ? null : _string(value);

Duration? _offset(Object? value) {
  if (value == null) return null;
  final seconds = _integer(value);
  if (seconds.abs() >= 86400) throw const FormatException();
  return Duration(seconds: seconds);
}

double? _optionalNumber(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0) {
    throw const FormatException();
  }
  return value.toDouble();
}
