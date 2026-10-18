import 'guided_program_card.dart';

import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) =>
      FutureBuilder<List<StartedGuidedProgram>>(
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
          if (!snapshot.hasData) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeSectionHeading(
                  title: 'Tus programas',
                  action: TextButton.icon(
                    onPressed: () => widget.onOpen('/library?tab=programs'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Añadir'),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  key: const PageStorageKey('home-guided-programs'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items.isEmpty)
                        GuidedProgramCard(
                          key: const ValueKey('home-guided-card-add'),
                          onTap: () => widget.onOpen('/library?tab=programs'),
                        ),
                      for (final (index, item) in items.indexed) ...[
                        if (index > 0) const SizedBox(width: 10),
                        GuidedProgramCard(
                          key: ValueKey('home-guided-card-${item.program.id}'),
                          program: item.program,
                          phaseIndex: item.phaseIndex,
                          onTap: () => widget.onOpen(
                            '/library/programs/${item.program.id}',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}
