import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/device_connections/data/supabase_garmin_connection_repository.dart';
import '../../features/device_connections/presentation/garmin_connection_page.dart';
import '../../features/device_training/data/supabase_training_delivery_repository.dart';
import '../../features/device_training/presentation/training_delivery_page.dart';
import '../../features/device_activity_results/data/supabase_activity_result_repository.dart';
import '../../features/device_activity_results/presentation/activity_result_page.dart';

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
    syncRepository: SupabaseTrainingDeliveryRepository(client, ownerId),
    openAuthorization: (uri) =>
        launchUrl(uri, mode: LaunchMode.externalApplication),
    onOpenPro: () => context.push('/pro/subscription'),
    onOpenTraining: () => context.push('/profile/garmin-training'),
    onOpenActivities: () => context.push('/profile/garmin-activities'),
  );
}

class GarminActivitiesRoute extends StatelessWidget {
  const GarminActivitiesRoute({
    super.key,
    required this.client,
    required this.ownerId,
  });
  final SupabaseClient client;
  final String ownerId;
  @override
  Widget build(BuildContext context) => ActivityResultPage(
    key: ValueKey(ownerId),
    repository: SupabaseActivityResultRepository(client, ownerId),
  );
}

class GarminTrainingRoute extends StatelessWidget {
  const GarminTrainingRoute({
    super.key,
    required this.client,
    required this.ownerId,
  });
  final SupabaseClient client;
  final String ownerId;
  @override
  Widget build(BuildContext context) => TrainingDeliveryPage(
    key: ValueKey(ownerId),
    repository: SupabaseTrainingDeliveryRepository(client, ownerId),
    onOpenActivities: () => context.push('/profile/garmin-activities'),
  );
}
