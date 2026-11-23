import 'package:flutter/services.dart';

import '../../domain/services/phone_running.dart';

class MethodChannelPhoneRunFeedback implements PhoneRunFeedback {
  const MethodChannelPhoneRunFeedback();

  static const _channel = MethodChannel('es.entrenaop/phone_run');

  @override
  Future<void> publish(
    String token, {
    required String phase,
    required String progress,
    required String pace,
    required String distance,
    required int seconds,
  }) => _channel.invokeMethod<void>('publishProgress', {
    'token': token,
    'phase': phase,
    'progress': progress,
    'pace': pace,
    'distance': distance,
    'seconds': seconds,
  });

  @override
  Future<void> end(String token) =>
      _channel.invokeMethod<void>('endProgress', token);

  @override
  Future<void> speak(String text) => _channel.invokeMethod<void>('speak', text);

  @override
  Future<void> silence() => _channel.invokeMethod<void>('silence');
}
