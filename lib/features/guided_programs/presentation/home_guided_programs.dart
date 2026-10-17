import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/guided_program.dart';

import '../domain/guided_program_repository.dart';

class HomeGuidedPrograms extends StatefulWidget {
  const HomeGuidedPrograms({
    super.key,
    required this.repository,
    required this.refreshVersion,
    required this.onOpen,
  });
  final GuidedProgramRepository repository;
  final int refreshVersion;
  final Future<void> Function(String route) onOpen;

  @override
  State<HomeGuidedPrograms> createState() => _HomeGuidedProgramsState();
}

class _HomeGuidedProgramsState extends State<HomeGuidedPrograms> {
  late Future<List<StartedGuidedProgram>> _programs;

  @override
  void initState() {
    super.initState();
    _programs = widget.repository.startedPrograms();
  }

  @override
  void didUpdateWidget(covariant HomeGuidedPrograms oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository ||
        widget.refreshVersion != oldWidget.refreshVersion) {
      _programs = widget.repository.startedPrograms();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<StartedGuidedProgram>>(
    future: _programs,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: EntrenaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('No hemos podido cargar tus programas.'),
                TextButton(
                  onPressed: () => setState(() {
                    _programs = widget.repository.startedPrograms();
                  }),
                  child: const Text('Reintentar programas'),
                ),
              ],
            ),
          ),
        );
      }
      final items = snapshot.data ?? const <StartedGuidedProgram>[];
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeSectionHeading(title: 'Tus programas'),
            const SizedBox(height: 6),
            const Text('Accede a tus últimos programas iniciados.'),
            for (final item in items) ...[
              const SizedBox(height: 12),
              EntrenaCard(
                padding: const EdgeInsets.all(16),
                child: InkWell(
                  onTap: () =>
                      widget.onOpen('/library/programs/${item.program.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.program.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.program.mode == GuidedProgramMode.phased
                                  ? 'Fase ${item.phaseIndex + 1} de ${item.program.phases.length} · ${item.program.phases[item.phaseIndex].name}'
                                  : '${item.program.modeLabel} · ${item.program.sessionCount} ${item.program.sessionCount == 1 ? 'sesión' : 'sesiones'}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
