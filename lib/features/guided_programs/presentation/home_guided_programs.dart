import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
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
                    children: [
                      if (items.isEmpty) _ProgramCard(onOpen: widget.onOpen),
                      for (final (index, item) in items.indexed) ...[
                        if (index > 0) const SizedBox(width: 10),
                        _ProgramCard(item: item, onOpen: widget.onOpen),
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

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({this.item, required this.onOpen});
  final StartedGuidedProgram? item;
  final Future<void> Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final program = item?.program;
    final phased = program?.mode == GuidedProgramMode.phased;
    final secondary = Theme.of(context).colorScheme.secondary;
    final detail = program == null
        ? 'Elige un programa'
        : phased
        ? 'Fase ${item!.phaseIndex + 1} de ${program.phases.length}'
        : '${program.sessionCount} ${program.sessionCount == 1 ? 'sesión' : 'sesiones'}';
    return SizedBox.square(
      key: ValueKey('home-guided-card-${program?.id ?? 'add'}'),
      dimension: 250,
      child: EntrenaCard(
        tone: EntrenaCardTone.progress,
        onTap: () => onOpen(
          program == null
              ? '/library?tab=programs'
              : '/library/programs/${program.id}',
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  program == null
                      ? Icons.add_circle_outline_rounded
                      : phased
                      ? Icons.trending_up_rounded
                      : Icons.fitness_center_rounded,
                  color: secondary,
                  size: 25,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    program?.modeLabel ?? 'Programas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.visuals.textMuted,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  program?.name ?? 'Añadir programa',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.visuals.textMuted,
                fontSize: 13,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              program == null ? 'Explorar →' : 'Ver programa →',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondary,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
