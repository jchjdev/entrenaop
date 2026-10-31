import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/apple_results.dart';
import '../domain/apple_training.dart';

/// El ciclo de vida solo dispara el caso de uso. No conoce HealthKit ni RPC.
class AppleResultsCoordinator extends ChangeNotifier {
  AppleResultsCoordinator(this._repositoryFor, this.reader);
  final AppleResultsRepository Function(String) _repositoryFor;
  final AppleResultsReader reader;
  SyncAppleResults? _sync;
  String? _owner;
  Timer? _timer;
  bool _foreground = true, _disposed = false;
  AppleResultCatalog? catalog;
  bool busy = false, configuring = false;
  String? error;
  DateTime? lastChecked;
  final ValueNotifier<int> resultsChanged = ValueNotifier(0);
  int _configuration = 0;

  void _catalog(AppleResultCatalog next) {
    final before = catalog?.results
        .map(
          (r) =>
              '${r.id}:${r.state}:${r.seconds}:${r.meters}:${r.averageHeartRate}:${r.maxHeartRate}',
        )
        .join('|');
    final after = next.results
        .map(
          (r) =>
              '${r.id}:${r.state}:${r.seconds}:${r.meters}:${r.averageHeartRate}:${r.maxHeartRate}',
        )
        .join('|');
    catalog = next;
    if (before != after) resultsChanged.value++;
  }

  void setAccount(String? owner) {
    if (owner == _owner && (_sync?.repository.isCurrent ?? owner == null)) {
      return;
    }
    _sync?.dispose();
    _owner = owner;
    _configuration++;
    catalog = null;
    error = null;
    lastChecked = null;
    busy = false;
    configuring = false;
    _sync = owner == null || !reader.supported
        ? null
        : SyncAppleResults(_repositoryFor(owner), reader);
    _timer?.cancel();
    _timer = _sync == null
        ? null
        : Timer.periodic(const Duration(minutes: 1), (_) {
            if (_foreground && catalog?.enabled != false) unawaited(refresh());
          });
    _notify();
    if (_sync != null) unawaited(refresh());
  }

  void foreground(bool value) {
    _foreground = value;
    if (value && _sync != null) unawaited(refresh());
  }

  Future<void> refresh() async {
    final sync = _sync;
    if (sync == null || busy || _disposed) return;
    busy = true;
    final configuration = _configuration;
    error = null;
    _notify();
    try {
      final result = await sync();
      if (_sync != sync || _disposed) return;
      if (result != null && configuration == _configuration) _catalog(result);
      lastChecked = DateTime.now();
    } catch (e) {
      if (_sync == sync && !_disposed) error = _message(e);
    } finally {
      if (_sync == sync && !_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> enable(bool enabled) async {
    final sync = _sync;
    if (sync == null || configuring || _disposed) return;
    configuring = true;
    _notify();
    final configuration = ++_configuration;
    try {
      // El apagado llega al servidor aunque exista una consulta nativa en curso.
      if (enabled) await reader.authorize();
      if (_disposed || _sync != sync || !sync.repository.isCurrent) return;
      await sync.repository.enable(enabled);
      if (_sync != sync || _disposed || configuration != _configuration) return;
      final next = await sync.repository.load();
      if (_sync != sync || _disposed || configuration != _configuration) return;
      _catalog(next);
      configuring = false;
      error = null;
      _notify();
      if (enabled) await refresh();
    } catch (e) {
      if (_sync == sync && !_disposed) {
        error = _message(e);
        _notify();
      }
    } finally {
      if (_sync == sync && !_disposed && configuration == _configuration) {
        configuring = false;
        _notify();
      }
    }
  }

  Future<void> classify(String id, bool isTest) async {
    final sync = _sync;
    if (sync == null) return;
    try {
      await sync.repository.classify(id, isTest);
      if (_sync != sync || _disposed) return;
      final next = await sync.repository.load();
      if (_sync != sync || _disposed) return;
      _catalog(next);
      _notify();
    } catch (e) {
      if (_sync == sync && !_disposed) {
        error = _message(e);
        _notify();
      }
    }
  }

  String _message(Object e) =>
      switch (e is AppleTrainingFailure ? e.code : '') {
        'account_changed' =>
          'La cuenta ha cambiado. Vuelve a entrar para sincronizar.',
        'access_required' => 'El retorno de Apple Watch requiere Pro o un servicio de entrenador vigente.',
        'update_required' => 'Actualiza EntrenaOP en el iPhone para recibir los resultados de Apple Watch.',
        'results_disabled' => 'La recogida automática está desactivada.',
        _ => 'No se pudo consultar Apple Watch. Se reintentará al volver a la app; también puedes actualizar aquí.',
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sync?.dispose();
    resultsChanged.dispose();
    super.dispose();
  }
}
