import 'package:flutter/foundation.dart';
import 'package:trainer_access/trainer_security.dart';
import 'package:trainer_access/trainer_messages.dart';

import '../domain/coach_workspace_repository.dart';

/// Estado efímero por cuenta. Un fallo nunca se interpreta como permiso vigente.
class CoachWorkspaceController extends ChangeNotifier {
  CoachWorkspaceController({required this.repository, required this.security});
  final CoachWorkspaceRepository repository;
  final TrainerSecurity security;
  bool enabled = false, assured = false, loading = true;
  bool _disposed = false;
  int _generation = 0;
  String? error;
  TrainerMessageInbox? inbox;
  int athleteIndex = 0;
  bool get canRead => enabled && assured && !loading && error == null;
  int get unread => inbox?.totalUnread ?? 0;

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    try {
      final account = await repository.account();
      if (_disposed || generation != _generation) return;
      final verified = account.enabled && await security.assured();
      if (_disposed || generation != _generation) return;
      final nextInbox = verified ? await repository.inbox() : null;
      if (_disposed || generation != _generation) return;
      enabled = account.enabled;
      assured = verified;
      inbox = nextInbox;
      loading = false;
      error = null;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      assured = false;
      inbox = null;
      loading = false;
      error = 'No se pudo verificar el acceso profesional. Reintenta.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    inbox = null;
    super.dispose();
  }
}
