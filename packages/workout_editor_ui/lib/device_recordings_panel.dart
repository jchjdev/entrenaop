import 'package:flutter/material.dart';
import 'package:workout_core/device_activity_summary.dart';

import 'device_activity_summary_card.dart';

/// Una sesión puede tener varias grabaciones; sus mediciones no se mezclan.
class DeviceRecordingsPanel extends StatelessWidget {
  const DeviceRecordingsPanel({
    super.key,
    required this.recordings,
    this.detailsIncomplete = false,
  });
  final List<DeviceActivitySummary> recordings;
  final bool detailsIncomplete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (detailsIncomplete)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sesión realizada · Sin detalle por serie. El reloj acredita la actividad; no hay correspondencia segura entre todos los intervalos y la pauta. Las series no se consideran omitidas.',
            ),
          ),
        ),
      if (recordings.isNotEmpty) ...[
        Text(
          'Grabaciones del reloj',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final recording in recordings)
          DeviceActivitySummaryCard(result: recording),
      ],
    ],
  );
}
