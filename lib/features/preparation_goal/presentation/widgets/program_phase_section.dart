import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/adaptive_program_path.dart';

/// Estado real y previsión se presentan separados, sin decidir reglas deportivas.
class ProgramPhaseSection extends StatefulWidget {
  const ProgramPhaseSection({required this.path, super.key});
  final AdaptiveProgramPath path;
  @override
  State<ProgramPhaseSection> createState() => _ProgramPhaseSectionState();
}

class _ProgramPhaseSectionState extends State<ProgramPhaseSection> {
  bool _showPhases = false;
  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (path.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Esta semana'),
              icon: Icon(Icons.today_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Mis fases'),
              icon: Icon(Icons.route_outlined),
            ),
          ],
          selected: {_showPhases},
          onSelectionChanged: (value) =>
              setState(() => _showPhases = value.single),
        ),
        const SizedBox(height: 16),
        if (!_showPhases) ...[
          Text(
            'Qué estamos trabajando',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final objective in path.objectives)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      objective.exerciseName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      objective.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(objective.purpose),
                  ],
                ),
              ),
            ),
        ] else ...[
          Text(
            'Fuerza y rendimiento · recorrido previsto',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(path.note),
          const SizedBox(height: 8),
          for (final stage in path.stages)
            Card(
              child: ExpansionTile(
                leading: Icon(
                  path.objectives.any((o) => o.code == stage.code)
                      ? Icons.my_location
                      : Icons.radio_button_unchecked,
                ),
                title: Text(stage.name),
                subtitle: Text(_dates(stage)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(stage.purpose),
                  if (path.objectives.any((o) => o.code == stage.code)) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Ahora: ${path.objectives.where((o) => o.code == stage.code).map((o) => o.exerciseName).join(', ')}',
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'La dosis se adapta con tus resultados. Cambiar de fase no exige un máximo ni cambiar todos los ejercicios.',
          ),
        ],
      ],
    );
  }

  String _dates(ProgramStage stage) {
    if (stage.startsOn == null || stage.endsOn == null) {
      return 'Previsión revisable';
    }
    final format = DateFormat('dd/MM');
    return '${format.format(stage.startsOn!)} – ${format.format(stage.endsOn!)} · orientativo';
  }
}
