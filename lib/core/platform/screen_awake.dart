import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// El bloqueo automático se restablece cuando la última pantalla lo libera.
abstract final class ScreenAwake {
  static const _channel = MethodChannel('es.entrenaop/clock_screen');
  static final _owners = <Object>{};

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> setEnabled(Object owner, bool enabled) async {
    if (!supported) return;
    final wasAwake = _owners.isNotEmpty;
    if (enabled) {
      _owners.add(owner);
    } else {
      _owners.remove(owner);
    }
    if (wasAwake == _owners.isNotEmpty) return;
    try {
      await _channel.invokeMethod<void>('setEnabled', _owners.isNotEmpty);
    } on MissingPluginException {
      // La pantalla sigue funcionando en compilaciones sin este adaptador.
    } on PlatformException catch (error) {
      debugPrint(
        'No se ha podido ajustar el bloqueo automático: ${error.code}',
      );
    }
  }
}
