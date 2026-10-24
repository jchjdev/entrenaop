import 'dart:async';

import 'package:flutter/foundation.dart';

class PushAccount {
  const PushAccount(this.id, this.accessToken);
  final String id, accessToken;
}

class PushInstallation {
  const PushInstallation(this.id, this.secret);
  final String id, secret;
}

class PushConfiguration {
  const PushConfiguration(this.enabled, this.projectId);
  final bool enabled;
  final String? projectId;
}

class PushDeviceState {
  const PushDeviceState(this.bindingId, this.owned);
  final String bindingId;
  final bool owned;
}

abstract interface class PushTransport {
  bool get available;
  String get projectId;
  String get platform;
  Stream<void> get foregroundEvents;
  Stream<void> get openEvents;
  Stream<void> get tokenEvents;
  Future<void> initialize();
  Future<bool> permitted({bool request = false});
  Future<String?> token();
  Future<void> deleteToken();
  Future<void> dispose();
}

abstract interface class PushStore {
  Future<PushInstallation> installation();
  Future<bool> optedIn(String owner);
  Future<void> setOptedIn(String owner, bool enabled);
}

abstract interface class PushBackend {
  Future<PushConfiguration> configuration(PushAccount account);
  Future<PushDeviceState?> device(
    PushAccount account,
    PushInstallation installation,
  );
  Future<void> register(
    PushAccount account,
    PushInstallation installation, {
    required String bindingId,
    required String? previousBinding,
    required String token,
    required String platform,
  });

  /// Solo revoca la asociación propia. Puede fijar el token anterior al salir;
  /// nunca revoca una asociación posterior de otra cuenta.
  Future<void> revoke(PushAccount account, PushInstallation installation);
}

/// Coordina permisos y transporte; los avisos y permisos siguen en Supabase.
/// Cada transición se serializa y vuelve a comprobar su cuenta tras cada await.
class PushNotificationCoordinator extends ChangeNotifier {
  PushNotificationCoordinator({
    required this.transport,
    required this.backend,
    required this.store,
    required this.newId,
  });
  final PushTransport transport;
  final PushBackend backend;
  final PushStore store;
  final String Function() newId;
  final _notices = StreamController<void>.broadcast();
  final _opens = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<void>>[];
  Stream<void> get notices => _notices.stream;
  Stream<void> get opens => _opens.stream;
  Future<void> _tail = Future.value();
  PushAccount? _account, _transportOwner;
  int _epoch = 0;
  bool _initialized = false, _disposed = false;
  bool _pendingOpen = false;
  bool serverAvailable = false, enabled = false, busy = false, denied = false;
  String? error;
  bool get available => transport.available;
  bool _current(int epoch, PushAccount account) =>
      !_disposed && epoch == _epoch && _account?.id == account.id;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(int epoch, Future<void> Function() action) {
    final next = _tail.then((_) async {
      if (_disposed) return;
      if (epoch == _epoch) {
        busy = true;
        error = null;
        _notify();
      }
      try {
        await action();
      } catch (_) {
        if (epoch == _epoch && !_disposed) error = 'No se pudo confirmar el estado de los avisos. Reintenta con conexión.';
      } finally {
        if (epoch == _epoch && !_disposed) {
          busy = false;
          _notify();
        }
      }
    });
    _tail = next;
    return next;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    if (_subscriptions.isEmpty) {
      _subscriptions.add(
        transport.foregroundEvents.listen((_) {
          if (!_disposed && _account != null) _notices.add(null);
        }),
      );
      _subscriptions.add(
        transport.openEvents.listen((_) {
          _pendingOpen = true;
          _emitOpen();
        }),
      );
      _subscriptions.add(
        transport.tokenEvents.listen((_) {
          unawaited(refresh());
        }),
      );
    }
    await transport.initialize();
    _initialized = true;
  }

  Future<void> _revoke(PushAccount account) async {
    var stopped = false;
    try {
      await backend.revoke(account, await store.installation());
      stopped = true;
    } catch (_) {
      /* Se intenta invalidar también el token del proveedor. */
    }
    if (_initialized) {
      try {
        await transport.deleteToken();
        stopped = true;
      } catch (_) {
        /* La revocación propia de servidor sigue siendo suficiente. */
      }
    }
    if (stopped) _transportOwner = null;
    if (!stopped) throw StateError('No se confirmó la desactivación.');
  }

  void _emitOpen() {
    if (!_disposed && _account != null && _pendingOpen) {
      _pendingOpen = false;
      _notices.add(null);
      _opens.add(null);
    }
  }

  Future<bool> _configure(int epoch, PushAccount account) async {
    if (!available || !_current(epoch, account)) return false;
    await _initialize();
    if (!_current(epoch, account)) return false;
    final configuration = await backend.configuration(account);
    if (!_current(epoch, account)) return false;
    serverAvailable =
        configuration.enabled && configuration.projectId == transport.projectId;
    return serverAvailable;
  }

  Future<void> setAccount(PushAccount? account) {
    final changed = _account?.id != account?.id;
    _account = account;
    final epoch = ++_epoch;
    if (changed) {
      serverAvailable = false;
      enabled = false;
      denied = false;
    }
    error = null;
    _notify();
    return _run(epoch, () async {
      final previous = _transportOwner;
      if (previous != null && previous.id != _account?.id) {
        await _revoke(previous);
      }
      if (account == null) {
        if (epoch == _epoch && available) {
          await _initialize();
          await transport.deleteToken();
        }
        return;
      }
      if (!_current(epoch, account)) return;
      _emitOpen();
      if (!await _configure(epoch, account)) return;
      final optedIn = await store.optedIn(account.id);
      if (!_current(epoch, account)) return;
      if (!optedIn) {
        await _revoke(account);
        if (_current(epoch, account)) enabled = false;
        return;
      }
      final permitted = await transport.permitted();
      if (!_current(epoch, account)) return;
      if (!permitted) {
        denied = true;
        await _revoke(account);
        if (_current(epoch, account)) enabled = false;
        return;
      }
      await _bind(epoch, account);
    });
  }

  Future<void> refresh() {
    final account = _account;
    if (!available) return Future.value();
    return setAccount(account);
  }

  Future<void> _bind(int epoch, PushAccount account) async {
    final installation = await store.installation();
    if (!_current(epoch, account)) return;
    _transportOwner = account;
    final token = await transport.token();
    if (!_current(epoch, account)) return;
    if (token == null || token.isEmpty) {
      throw StateError('Token no disponible.');
    }
    final previous = await backend.device(account, installation);
    if (!_current(epoch, account)) return;
    await backend.register(
      account,
      installation,
      bindingId: newId(),
      previousBinding: previous?.bindingId,
      token: token,
      platform: transport.platform,
    );
    if (_current(epoch, account)) enabled = true;
  }

  Future<void> enable() {
    final account = _account;
    final epoch = _epoch;
    if (account == null || !available) return Future.value();
    return _run(epoch, () async {
      if (!await _configure(epoch, account)) return;
      final permitted = await transport.permitted(request: true);
      if (!_current(epoch, account)) return;
      denied = !permitted;
      if (!permitted) {
        await _revoke(account);
        if (_current(epoch, account)) enabled = false;
        return;
      }
      await store.setOptedIn(account.id, true);
      if (_current(epoch, account)) await _bind(epoch, account);
    });
  }

  Future<void> disable() {
    final account = _account;
    final epoch = _epoch;
    if (account == null) return Future.value();
    return _run(epoch, () async {
      if (!_current(epoch, account)) return;
      await store.setOptedIn(account.id, false);
      if (!_current(epoch, account)) return;
      await _revoke(account);
      if (_current(epoch, account)) enabled = false;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_notices.close());
    unawaited(_opens.close());
    unawaited(transport.dispose());
    super.dispose();
  }
}
