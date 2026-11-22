import 'package:flutter/services.dart';

import '../../domain/services/phone_running.dart';

class MethodChannelPhoneRunLocation implements PhoneRunLocationSource {
  static const _methods = MethodChannel('es.entrenaop/phone_run');
  static const _locations = EventChannel('es.entrenaop/phone_run/locations');

  @override
  Stream<PhoneRunLocationEvent> get locations => _locations
      .receiveBroadcastStream()
      .map(_readEvent)
      .where((event) => event != null)
      .cast<PhoneRunLocationEvent>();

  @override
  Future<void> start(String token) async {
    try {
      await _methods.invokeMethod<void>('start', token);
    } on PlatformException catch (error) {
      throw PhoneRunLocationFailure(error.code);
    }
  }

  @override
  Future<void> stop(String token) => _methods.invokeMethod<void>('stop', token);

  PhoneRunLocationEvent? _readEvent(Object? raw) {
    if (raw is! Map || raw['token'] is! String) return null;
    final token = raw['token'] as String;
    if (raw['error'] case final String error) {
      return PhoneRunLocationEvent(token, error: error);
    }
    final lat = raw['lat'];
    final lon = raw['lon'];
    final accuracy = raw['accuracy'];
    final time = raw['time'];
    if (lat is! num || lon is! num || accuracy is! num || time is! int) {
      return null;
    }
    return PhoneRunLocationEvent(
      token,
      fix: PhoneRunFix(
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
        accuracyMeters: accuracy.toDouble(),
        at: DateTime.fromMillisecondsSinceEpoch(time),
      ),
    );
  }
}
