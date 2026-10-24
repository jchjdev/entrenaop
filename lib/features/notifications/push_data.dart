import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:uuid/uuid.dart';

import 'push_notifications.dart';

class LocalPushStore implements PushStore {
  Future<PushInstallation>? _key;
  @override
  Future<PushInstallation> installation() async {
    final key = _key ??= _load();
    try {
      return await key;
    } catch (_) {
      if (identical(key, _key)) _key = null;
      rethrow;
    }
  }

  Future<PushInstallation> _load() async {
    final preferences = await SharedPreferences.getInstance();
    var id = preferences.getString('push.installation.id');
    var secret = preferences.getString('push.installation.secret');
    if (id == null || secret == null) {
      id = const Uuid().v4();
      final random = Random.secure();
      secret = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      if (!await preferences.setString('push.installation.id', id) ||
          !await preferences.setString('push.installation.secret', secret)) {
        throw StateError('No se pudo conservar la instalación.');
      }
    }
    return PushInstallation(id, secret);
  }

  @override
  Future<bool> optedIn(String owner) async =>
      (await SharedPreferences.getInstance()).getBool('push.opted-in.$owner') ??
      false;
  @override
  Future<void> setOptedIn(String owner, bool enabled) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      'push.opted-in.$owner',
      enabled,
    )) {
      throw StateError('No se pudo conservar la preferencia.');
    }
  }
}

class SupabasePushBackend implements PushBackend {
  const SupabasePushBackend(this.client);
  final SupabaseClient client;
  Future<dynamic> _rpc(
    PushAccount account,
    String name,
    Map<String, dynamic> parameters,
  ) => authenticatedTrainerRpc(
    client,
    account.id,
    name,
    params: {'p_expected_owner': account.id, ...parameters},
  );
  Map<String, dynamic> _key(PushInstallation installation) => {
    'p_id': installation.id,
    'p_secret': installation.secret,
  };
  @override
  Future<PushConfiguration> configuration(PushAccount account) async {
    final row = await _rpc(account, 'get_my_push_configuration', {}) as Map;
    return PushConfiguration(
      row['enabled'] == true,
      row['firebase_project_id'] as String?,
    );
  }

  @override
  Future<PushDeviceState?> device(
    PushAccount account,
    PushInstallation installation,
  ) async {
    final row =
        await _rpc(account, 'get_my_push_device', _key(installation)) as Map?;
    return row == null
        ? null
        : PushDeviceState(row['binding_id'] as String, row['owned'] == true);
  }

  @override
  Future<void> register(
    PushAccount account,
    PushInstallation installation, {
    required String bindingId,
    required String? previousBinding,
    required String token,
    required String platform,
  }) async {
    await _rpc(account, 'register_my_push_device', {
      ..._key(installation),
      'p_binding_id': bindingId,
      'p_previous_binding': previousBinding,
      'p_token': token,
      'p_platform': platform,
    });
  }

  Future<dynamic> _previous(
    PushAccount account,
    String name,
    Map<String, dynamic> parameters,
  ) async {
    // Revocación de la cuenta que acaba de salir: el bearer capturado y el CAS
    // de instalación evitan usar la sesión nueva o desactivar su asociación.
    var request = client.rpc(
      name,
      params: {'p_expected_owner': account.id, ...parameters},
    );
    for (final key in {
      ...client.rest.headers.keys.where(
        (k) => k.toLowerCase() == 'authorization',
      ),
      'Authorization',
    }) {
      request = request.setHeader(key, 'Bearer ${account.accessToken}');
    }
    return await request;
  }

  @override
  Future<void> revoke(
    PushAccount account,
    PushInstallation installation,
  ) async {
    final row = await _previous(
      account,
      'get_my_push_device',
      _key(installation),
    ) as Map?;
    if (row == null || row['owned'] != true) return;
    await _previous(account, 'unregister_my_push_device', {
      ..._key(installation),
      'p_binding_id': row['binding_id'],
    });
  }
}
