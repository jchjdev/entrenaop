import 'package:device_health/device_health.dart';
import 'package:entrenaop/features/device_activities/data/supabase_running_history_repository.dart';
import 'package:entrenaop/features/device_activities/presentation/device_activities_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Composición por cuenta: un refresco de Auth no reinicia lecturas o selecciones.
class DeviceActivitiesRoute extends StatefulWidget {
  const DeviceActivitiesRoute({
    super.key,
    required this.ownerId,
    required this.client,
  });
  final String ownerId;
  final SupabaseClient client;

  @override
  State<DeviceActivitiesRoute> createState() => _DeviceActivitiesRouteState();
}

class _DeviceActivitiesRouteState extends State<DeviceActivitiesRoute> {
  late LocalRunningHealth _health;
  late SupabaseRunningHistoryRepository _history;

  void _compose() {
    _health = NativeRunningHealth.forCurrentPlatform(ownerId: widget.ownerId);
    _history = SupabaseRunningHistoryRepository(widget.client, widget.ownerId);
  }

  @override
  void initState() {
    super.initState();
    _compose();
  }

  @override
  void didUpdateWidget(covariant DeviceActivitiesRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.client != widget.client) {
      _compose();
    }
  }

  @override
  Widget build(BuildContext context) => DeviceActivitiesPage(
    key: ValueKey(widget.ownerId),
    ownerId: widget.ownerId,
    health: _health,
    history: _history,
  );
}
