import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:trainer_access/trainer_invitation_link.dart';

/// Intención entrante en memoria. No introduce el secreto en rutas, preferencias
/// ni logs, y no acepta el vínculo por recibirlo o iniciar sesión.
class TrainerInvitationEntry extends ChangeNotifier {
  StreamSubscription<Uri>? _subscription;
  String? _secret;
  String? get secret => _secret;
  bool pending = false;
  int revision = 0;
  bool _disposed = false;
  void attach(Stream<Uri> links) {
    _subscription = links.listen(receive, onError: (Object _) {});
  }

  void receive(Uri uri) {
    if (_disposed || !TrainerInvitationLink.isInvitation(uri)) return;
    final value = TrainerInvitationLink.parse(uri);
    if (pending && value == _secret) return;
    _secret = value;
    pending = true;
    revision++;
    notifyListeners();
  }

  void clear(int expectedRevision) {
    if (_disposed || revision != expectedRevision) return;
    _secret = null;
    pending = false;
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _secret = null;
    super.dispose();
  }
}
