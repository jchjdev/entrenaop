import 'dart:async';

import 'package:flutter/widgets.dart';

/// Agrupa pulsaciones y descarta respuestas de una búsqueda anterior.
class TrainerCatalogSearch {
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  int begin() {
    _timer?.cancel();
    return ++_generation;
  }

  bool current(int request) => !_disposed && request == _generation;

  void schedule(Future<void> Function() load) {
    ++_generation;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () => unawaited(load()));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

Widget trainerCatalogAutoPage({
  required Widget child,
  required bool active,
  required bool hasMore,
  required bool busy,
  required VoidCallback loadMore,
}) => NotificationListener<ScrollNotification>(
  onNotification: (notice) {
    if (active &&
        hasMore &&
        !busy &&
        notice.depth == 0 &&
        notice.metrics.pixels > 0 &&
        notice.metrics.extentAfter < 320) {
      loadMore();
    }
    return false;
  },
  child: child,
);
