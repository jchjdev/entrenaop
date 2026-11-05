import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Conserva las pilas y posiciones de cada espacio y desplaza solo su portada
/// visible cuando se repite el destino activo.
class SectionNavigationController {
  SectionNavigationController({
    required this.rootLocations,
    required this.navigationShell,
  });

  final Set<String> rootLocations;
  final StatefulNavigationShell Function() navigationShell;
  final _scrollables = <ScrollableState, int>{};

  bool observeScroll(BuildContext context, Notification notification) {
    final data = switch (notification) {
      ScrollNotification n => (n.metrics, n.context, n.depth),
      ScrollMetricsNotification n => (n.metrics, n.context, n.depth),
      _ => null,
    };
    if (data == null) return false;
    final (metrics, source, depth) = data;
    if (metrics.axis != Axis.vertical ||
        source == null ||
        !TickerMode.valuesOf(source).enabled ||
        !rootLocations.contains(GoRouter.of(context).state.uri.path)) {
      return false;
    }
    final scrollable = Scrollable.maybeOf(source);
    if (scrollable != null) {
      _scrollables.removeWhere((scrollable, _) => !scrollable.mounted);
      _scrollables[scrollable] = depth;
    }
    return false;
  }

  void _scrollToTop(BuildContext context) {
    _scrollables.removeWhere((scrollable, _) => !scrollable.mounted);
    final shell = context.findRenderObject() as RenderBox;
    final bounds = Offset.zero & shell.size;
    // Las ramas y pestañas interiores conservan sus scrolls. Solo responde el
    // viewport vertical visible, priorizando el exterior si hay listas anidadas.
    final visible = _scrollables.entries.where((entry) {
      final scrollable = entry.key;
      final viewport = scrollable.context.findRenderObject();
      return TickerMode.valuesOf(scrollable.context).enabled &&
          ModalRoute.of(scrollable.context)?.isCurrent == true &&
          viewport is RenderBox &&
          viewport.attached &&
          bounds.contains(
            viewport.localToGlobal(
              viewport.size.center(Offset.zero),
              ancestor: shell,
            ),
          );
    }).toList()..sort((a, b) => a.value.compareTo(b.value));
    if (visible.isEmpty) return;
    final position = visible.first.key.position;
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(position.minScrollExtent);
    } else {
      unawaited(
        position.animateTo(
          position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void selectDestination(BuildContext context, int index) {
    final shell = navigationShell();
    if (index != shell.currentIndex) {
      shell.goBranch(index);
      return;
    }
    if (rootLocations.contains(GoRouter.of(context).state.uri.path)) {
      _scrollToTop(context);
      return;
    }
    shell.goBranch(index, initialLocation: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && navigationShell().currentIndex == index) {
        _scrollToTop(context);
      }
    });
  }
}
