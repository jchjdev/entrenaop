import 'dart:async';

import 'package:flutter/foundation.dart';

class WorkoutSessionEntry extends ChangeNotifier {
  static final _executionId = RegExp(
    r'^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$',
  );

  StreamSubscription<Uri>? _links;
  String? _pending;

  void attach(Stream<Uri> links) {
    _links = links.listen(receive, onError: (Object _) {});
  }

  void receive(Uri uri) {
    if (uri.scheme != 'es.entrenaop' ||
        uri.host != 'workout-session' ||
        uri.pathSegments.length != 1 ||
        uri.hasQuery ||
        uri.hasFragment ||
        !_executionId.hasMatch(uri.pathSegments.single)) {
      return;
    }
    _pending = uri.pathSegments.single.toLowerCase();
    notifyListeners();
  }

  String? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    super.dispose();
  }
}
