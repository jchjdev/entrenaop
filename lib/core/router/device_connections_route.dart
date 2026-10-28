import 'package:device_health/device_health.dart';

import '../config/app_config.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/device_connections/data/supabase_garmin_connection_repository.dart';
import '../../features/device_connections/presentation/device_connections_page.dart';

class DeviceConnectionsRoute extends StatefulWidget {
  const DeviceConnectionsRoute({
    super.key,
    required this.client,
    required this.ownerId,
  });
  final SupabaseClient client;
  final String ownerId;

  @override
  State<DeviceConnectionsRoute> createState() => _DeviceConnectionsRouteState();
}

class _DeviceConnectionsRouteState extends State<DeviceConnectionsRoute> {
  late LocalRunningHealth _health;
  late SupabaseGarminConnectionRepository _garmin;

  void _compose() {
    _health = NativeRunningHealth.forCurrentPlatform(ownerId: widget.ownerId);
    _garmin = SupabaseGarminConnectionRepository(widget.client, widget.ownerId);
  }

  @override
  void initState() {
    super.initState();
    _compose();
  }

  @override
  void didUpdateWidget(covariant DeviceConnectionsRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.client != widget.client) {
      _compose();
    }
  }

  @override
  Widget build(BuildContext context) => DeviceConnectionsPage(
    key: ValueKey(widget.ownerId),
    ownerId: widget.ownerId,
    health: _health,
    garmin: _garmin,
    onOpenHealth: () async {
      await context.push('/profile/activities');
    },
    onOpenAppleWatch: AppConfig.environment == AppEnvironment.development
        ? () async {
            await context.push('/profile/apple-watch');
          }
        : null,
    onOpenGarmin: () async {
      await context.push('/profile/garmin');
    },
  );
}
