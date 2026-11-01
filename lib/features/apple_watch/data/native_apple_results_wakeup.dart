import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../domain/apple_results_wakeup.dart';

class NativeAppleResultsWakeup implements AppleResultsWakeup {
  static const _channel = MethodChannel(
    'es.entrenaop.device_health/background',
  );
  bool _disposed = false;
  int _generation = 0;

  bool get _supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      AppConfig.environment == AppEnvironment.development;

  @override
  Future<bool> configure(
    String? owner,
    Future<bool> Function() synchronize,
  ) async {
    final generation = ++_generation;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || _disposed) {
      return false;
    }
    if (!_supported) owner = null;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'changed' ||
          _disposed ||
          generation != _generation ||
          owner == null) {
        return false;
      }
      final saved = await synchronize();
      return saved && !_disposed && generation == _generation;
    });
    try {
      final enabled = await _channel
          .invokeMethod<bool>('configure', {'enabled': owner != null})
          .timeout(const Duration(seconds: 10));
      return !_disposed && generation == _generation && enabled == true;
    } on TimeoutException {
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    if (!_supported) return;
    _channel.setMethodCallHandler(null);
    try {
      // Destruir el motor no revoca la preferencia del usuario: el observador
      // permanece preparado para el siguiente arranque por HealthKit.
      await _channel.invokeMethod<void>('detach');
    } on PlatformException {
      // La siguiente apertura conserva el reintento desde Salud.
    } on MissingPluginException {
      // Una instalación antigua mantiene su lectura en primer plano.
    }
  }
}
