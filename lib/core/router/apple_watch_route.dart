import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/apple_watch/data/apple_training_adapters.dart';
import '../../features/apple_watch/domain/apple_training.dart';
import '../../features/apple_watch/presentation/apple_watch_page.dart';

class AppleWatchRoute extends StatefulWidget {
  const AppleWatchRoute({
    super.key,
    required this.ownerId,
    required this.client,
  });
  final String ownerId;
  final SupabaseClient client;
  @override
  State<AppleWatchRoute> createState() => _AppleWatchRouteState();
}

class _AppleWatchRouteState extends State<AppleWatchRoute> {
  late AppleTrainingService _service;
  void _compose() {
    _service = AppleTrainingService(
      SupabaseAppleTrainingRepository(widget.client, widget.ownerId),
      const NativeAppleWorkoutScheduler(),
    );
  }

  @override
  void initState() {
    super.initState();
    _compose();
  }

  @override
  void didUpdateWidget(covariant AppleWatchRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.client != widget.client) {
      _compose();
    }
  }

  @override
  Widget build(BuildContext context) => AppleWatchPage(
    key: ObjectKey(_service),
    service: _service,
    onOpenHealth: () => context.push('/profile/activities'),
  );
}
