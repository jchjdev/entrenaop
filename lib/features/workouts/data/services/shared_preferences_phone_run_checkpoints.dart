import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/phone_running.dart';

class SharedPreferencesPhoneRunCheckpoints implements PhoneRunCheckpoints {
  SharedPreferencesPhoneRunCheckpoints(
    this.preferences, {
    required this.userId,
  });

  final SharedPreferences preferences;
  final String? userId;
  Future<void> _tail = Future.value();

  String _key(String executionId) {
    if (userId == null) throw StateError('Se requiere una cuenta para grabar.');
    return 'workout.phone-run.v1:$userId:$executionId';
  }

  @override
  Future<PhoneRunCheckpoint?> read(String executionId) async {
    await _tail;
    final encoded = preferences.getString(_key(executionId));
    if (encoded == null) return null;
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    return PhoneRunCheckpoint(
      PhoneRunTotals(
        elapsedMilliseconds: data['elapsed'] as int,
        distanceMeters: (data['distance'] as num).toDouble(),
        distanceReliable: data['reliable'] == true,
      ),
      recording: data['recording'] == true,
    );
  }

  // Se conserva solo el resultado agregado. Las coordenadas viven en memoria.
  @override
  Future<void> write(String executionId, PhoneRunCheckpoint value) =>
      _enqueue(() async {
        final saved = await preferences.setString(
          _key(executionId),
          jsonEncode({
            'elapsed': value.totals.elapsedMilliseconds,
            'distance': value.totals.distanceMeters,
            'reliable': value.totals.distanceReliable,
            'recording': value.recording,
          }),
        );
        if (!saved) throw StateError('No se ha guardado el rodaje.');
      });

  @override
  Future<void> clear(String executionId) => _enqueue(() async {
    await preferences.remove(_key(executionId));
  });

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}
