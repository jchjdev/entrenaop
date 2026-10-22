import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/device_connections/data/supabase_garmin_connection_repository.dart';
import '../../features/device_connections/presentation/garmin_connection_page.dart';

class GarminConnectionRoute extends StatelessWidget {
  const GarminConnectionRoute({
    super.key,
    required this.client,
    required this.ownerId,
  });
  final SupabaseClient client;
  final String ownerId;
  @override
  Widget build(BuildContext context) => GarminConnectionPage(
    key: ValueKey(ownerId),
    repository: SupabaseGarminConnectionRepository(client, ownerId),
    openAuthorization: (uri) =>
        launchUrl(uri, mode: LaunchMode.externalApplication),
    onOpenPro: () => context.push('/pro/subscription'),
  );
}
