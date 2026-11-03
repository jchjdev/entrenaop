import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/apple_training.dart';
import '../domain/sync_apple_training.dart';

/// El envío depende del iPhone emparejado, no de abrir la pantalla Apple.
class AppleTrainingCoordinator extends ChangeNotifier {
  AppleTrainingCoordinator(
    this._serviceFor,
    this.preference, {
    required this.supported,
  });
  final AppleTrainingService Function(String) _serviceFor;
  final AppleTrainingSyncPreference preference;
  final bool supported;
  AppleTrainingService? service;
  String? _owner;
  int _generation = 0;
  bool _disposed = false, _foreground = true;
  bool enabled = false, configuring = false, busy = false;
  AppleCatalog? catalog;
  AppleTrainingSyncReport? report;
  String? error;
  DateTime? lastChecked;
  Future<void>? _pending;
  Timer? _timer;

  void setAccount(String? owner) {
    if (owner == _owner && (service?.repository.isCurrent ?? owner == null)) {
      return;
    }
    _owner = owner;
    final generation = ++_generation;
    _timer?.cancel();
    service = owner == null || !supported ? null : _serviceFor(owner);
    enabled = configuring = busy = false;
    catalog = null;
    report = null;
    error = null;
    lastChecked = null;
    _pending = null;
    _notify();
    if (service == null) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_foreground && enabled) unawaited(refresh());
    });
    unawaited(_restore(owner!, generation));
  }

  Future<void> _restore(String owner, int generation) async {
    try {
      final value = await preference.enabled(owner);
      if (!_valid(generation)) return;
      enabled = value;
      _notify();
      if (value) await refresh();
    } catch (_) {
      if (_valid(generation)) {
        error = 'No se pudo recuperar la sincronización automática.';
        _notify();
      }
    }
  }

  bool _valid(int generation) => !_disposed && generation == _generation;
  void foreground(bool value) {
    _foreground = value;
    if (value && enabled) unawaited(refresh());
  }

  Future<void> enable(bool value) async {
    final current = service;
    final owner = _owner;
    if (current == null || owner == null || configuring) return;
    final generation = ++_generation;
    configuring = true;
    error = null;
    // Desactivar interrumpe antes de la siguiente escritura o ACK.
    enabled = false;
    _notify();
    try {
      if (value &&
          await current.scheduler.authorize() !=
              AppleAuthorization.authorized) {
        throw const AppleTrainingFailure('permission_required');
      }
      if (!_valid(generation) || !current.repository.isCurrent) return;
      await preference.setEnabled(owner, value);
      if (!_valid(generation) || !current.repository.isCurrent) return;
      enabled = value;
    } catch (e) {
      if (_valid(generation)) error = _explain(e);
    } finally {
      if (_valid(generation)) {
        configuring = false;
        _notify();
      }
    }
    // La pantalla puede retirar una pauta tras desactivar: esperar al envío
    // anterior evita competir por el mismo canal nativo o arrendamiento.
    if (_pending case final pending?) await pending;
    if (_valid(generation) && enabled) await refresh();
  }

  Future<void> refresh() {
    if (_disposed || !enabled || service == null || !_foreground) {
      return Future.value();
    }
    if (_pending case final pending?) return pending;
    final complete = Completer<void>();
    _pending = complete.future;
    unawaited(
      _refreshOnce().whenComplete(() {
        if (identical(_pending, complete.future)) _pending = null;
        complete.complete();
      }),
    );
    return complete.future;
  }

  Future<void> _refreshOnce() async {
    final current = service!;
    final generation = _generation;
    busy = true;
    error = null;
    _notify();
    try {
      final next = await SyncAppleTraining(current)(
        () => _valid(generation) && enabled && _foreground,
      );
      if (!_valid(generation)) return;
      report = next;
      catalog = next.catalog;
      lastChecked = DateTime.now();
      if (next.failures.isNotEmpty) {
        error =
            '${next.failures.length} sesiones pendientes. ${_explain(AppleTrainingFailure(next.failures.values.first))}';
      }
    } catch (e) {
      if (_valid(generation) && enabled && _foreground) error = _explain(e);
    } finally {
      if (!_disposed && identical(current, service)) {
        busy = false;
        _notify();
      }
    }
  }

  static String _explain(Object e) => switch (e is AppleTrainingFailure
      ? e.code
      : '') {
    'permission_required' => 'Autoriza la programación en este iPhone.',
    'access_required' => 'Necesitas Pro o un servicio de entrenador vigente.',
    'capacity_reached' => 'El calendario de Apple está lleno.',
    'unsupported_prescription' =>
      'Apple no admite la receta completa de alguna sesión.',
    'account_changed' => 'La cuenta ha cambiado. Vuelve a entrar.',
    _ => 'Se reintentará al volver a la app o en la siguiente comprobación.',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
