import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:trainer_access/trainer_notifications.dart';
import 'package:trainer_access/trainer_security.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

import '../domain/coach_workspace_repository.dart';
import '../../notifications/push_notifications_scope.dart';
import 'coach_workspace_controller.dart';

class CoachWorkspaceScope extends InheritedNotifier<CoachWorkspaceController> {
  const CoachWorkspaceScope({
    super.key,
    required CoachWorkspaceController controller,
    required this.messages,
    this.notifications,
    required this.video,
    required super.child,
  }) : super(notifier: controller);
  final TrainerInboxMessageRepository messages;
  final CoachNotificationRepository? notifications;
  final ExerciseVideoSource video;
  static CoachWorkspaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoachWorkspaceScope>();
  static CoachWorkspaceScope of(BuildContext context) => maybeOf(context)!;
  CoachWorkspaceController get controller => notifier!;
}

class CoachWorkspaceEntry extends StatefulWidget {
  const CoachWorkspaceEntry({
    super.key,
    required this.repository,
    required this.security,
    required this.messages,
    this.notifications,
    required this.video,
    required this.child,
    this.noticeEvents,
  });
  final Stream<void>? noticeEvents;
  final CoachWorkspaceRepository repository;
  final TrainerSecurity security;
  final TrainerInboxMessageRepository messages;
  final CoachNotificationRepository? notifications;
  final ExerciseVideoSource video;
  final Widget child;
  @override
  State<CoachWorkspaceEntry> createState() => _CoachWorkspaceEntryState();
}

class _CoachWorkspaceEntryState extends State<CoachWorkspaceEntry>
    with WidgetsBindingObserver {
  late final controller = CoachWorkspaceController(
    repository: widget.repository,
    security: widget.security,
  );
  Timer? _timer;
  StreamSubscription<void>? _noticeSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.refresh());
    _noticeSubscription = widget.noticeEvents?.listen((_) {
      if (controller.enabled) unawaited(controller.refresh());
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!controller.enabled) return;
      if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(controller.refresh());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _noticeSubscription ??= PushNotificationsScope.readOf(context)?.notices
        .listen((_) {
          if (controller.enabled) unawaited(controller.refresh());
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_noticeSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoachWorkspaceScope(
    controller: controller,
    messages: widget.messages,
    notifications: widget.notifications,
    video: widget.video,
    child: widget.child,
  );
}
