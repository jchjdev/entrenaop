import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/guided_program.dart';

import '../../../core/presentation/images/editorial_cover_provider.dart';

/// Adapta datos deportivos a la tarjeta editorial común; no define otro diseño.
class GuidedProgramCard extends StatelessWidget {
  const GuidedProgramCard({
    super.key,
    required this.onTap,
    this.program,
    this.phaseIndex,
  });
  final GuidedProgram? program;
  final int? phaseIndex;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = program;
    final phased = p?.mode == GuidedProgramMode.phased;
    return EntrenaProgramCard(
      square: true,
      title: p?.name ?? 'Añadir programa',
      label: p?.modeLabel ?? 'Programas',
      detail: p == null
          ? 'Elige un programa'
          : phased && phaseIndex != null
          ? 'Fase ${phaseIndex! + 1} de ${p.phases.length}'
          : '${p.sessionCount} ${p.sessionCount == 1 ? 'sesión' : 'sesiones'}${phased ? ' · ${p.phases.length} fases' : ''}',
      actionLabel: p == null ? 'Explorar →' : 'Ver programa →',
      icon: p == null
          ? Icons.add_circle_outline_rounded
          : phased
          ? Icons.trending_up_rounded
          : Icons.fitness_center_rounded,
      coverImage: editorialCoverProvider(p?.cover?.cardUrl),
      focalX: p?.cover?.focalX ?? 0.5,
      focalY: p?.cover?.focalY ?? 0.5,
      onTap: onTap,
    );
  }
}
