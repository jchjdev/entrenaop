import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/student_notice_repository.dart';

/// Resumen de navegación de una sola identidad; no concede acceso a recursos.
class StudentNavigationController extends ChangeNotifier {
  StudentNavigationController({
    required this.loadSnapshot,
    required this.loadHasRelationship,
  });

  final Future<StudentNoticeSnapshot> Function() loadSnapshot;
  final Future<bool> Function() loadHasRelationship;
  StudentNoticeSnapshot? snapshot;
  bool hasRelationship = false;
  int _generation = 0;
  int _snapshotRevision = 0;
  bool _disposed = false;
  Future<void>? _pending;

  int get unreadCount => snapshot?.unreadCount ?? 0;
  bool get hasTrainer =>
      hasRelationship ||
      snapshot?.resources.hasContent == true ||
      unreadCount > 0 ||
      snapshot?.items.isNotEmpty == true;

  Future<void> refresh() => _pending ??= _refresh().whenComplete(() {
    _pending = null;
  });

  Future<void> _refresh() async {
    final generation = ++_generation;
    final snapshotRevision = _snapshotRevision;
    StudentNoticeSnapshot? next;
    bool? relationship;
    // Los fallos se aíslan: perder conexión no borra un historial ya conocido.
    await Future.wait([
      () async {
        try {
          next = await loadSnapshot();
        } catch (_) {}
      }(),
      () async {
        try {
          relationship = await loadHasRelationship();
        } catch (_) {}
      }(),
    ]);
    if (_disposed || generation != _generation) return;
    if (next != null && snapshotRevision == _snapshotRevision) snapshot = next;
    if (relationship != null) hasRelationship = relationship!;
    notifyListeners();
  }

  void acceptSnapshot(StudentNoticeSnapshot value) {
    if (_disposed) return;
    // Una lectura posterior de la pantalla prevalece sobre una petición antigua.
    _snapshotRevision++;
    snapshot = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class StudentNavigationScope
    extends InheritedNotifier<StudentNavigationController> {
  const StudentNavigationScope({
    super.key,
    required StudentNavigationController controller,
    required super.child,
  }) : super(notifier: controller);

  static StudentNavigationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StudentNavigationScope>()
      ?.notifier;
}

/// Vive tanto como la sesión del shell; al cambiar de cuenta se crea de nuevo.
class StudentNavigationEntry extends StatefulWidget {
  const StudentNavigationEntry({
    super.key,
    required this.loadSnapshot,
    required this.loadHasRelationship,
    required this.child,
  });
  final Future<StudentNoticeSnapshot> Function() loadSnapshot;
  final Future<bool> Function() loadHasRelationship;
  final Widget child;

  @override
  State<StudentNavigationEntry> createState() => _StudentNavigationEntryState();
}

class _StudentNavigationEntryState extends State<StudentNavigationEntry>
    with WidgetsBindingObserver {
  late final controller = StudentNavigationController(
    loadSnapshot: widget.loadSnapshot,
    loadHasRelationship: widget.loadHasRelationship,
  );
  GoRouter? _router;
  String? _previousPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_routeChanged);
    _router = router;
    _previousPath = router?.state.uri.path;
    router?.routerDelegate.addListener(_routeChanged);
  }

  void _routeChanged() {
    final path = _router?.state.uri.path;
    final previous = _previousPath;
    _previousPath = path;
    if (previous == '/profile/trainer' && path != previous) {
      unawaited(controller.refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_routeChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StudentNavigationScope(controller: controller, child: widget.child);
}
