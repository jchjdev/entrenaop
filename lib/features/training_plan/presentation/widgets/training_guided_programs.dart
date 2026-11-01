import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../../dashboard/presentation/widgets/home_section_heading.dart';
import '../../../guided_programs/domain/guided_program_repository.dart';
import '../../../guided_programs/presentation/guided_program_card.dart';
import '../../../guided_programs/presentation/guided_program_cubits.dart';

/// El destino de gestión consulta todos los programas seguidos, sin heredar
/// el límite de tres tarjetas del resumen de Inicio.
class TrainingGuidedPrograms extends StatefulWidget {
  const TrainingGuidedPrograms({
    required this.repository,
    required this.refreshVersion,
    super.key,
  });

  final GuidedProgramRepository repository;
  final int refreshVersion;

  @override
  State<TrainingGuidedPrograms> createState() => _TrainingGuidedProgramsState();
}

class _TrainingGuidedProgramsState extends State<TrainingGuidedPrograms> {
  late GuidedCatalogCubit _cubit;

  GuidedCatalogCubit _createCubit() => GuidedCatalogCubit(widget.repository)
    ..followed = true
    ..load();

  @override
  void initState() {
    super.initState();
    _cubit = _createCubit();
  }

  @override
  void didUpdateWidget(covariant TrainingGuidedPrograms oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository) {
      unawaited(_cubit.close());
      _cubit = _createCubit();
    } else if (widget.refreshVersion != oldWidget.refreshVersion) {
      unawaited(_cubit.load(keepItems: true));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<GuidedCatalogCubit, GuidedCatalogState>(
        bloc: _cubit,
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeSectionHeading(
              title: 'Tus programas guiados',
              action: TextButton.icon(
                onPressed: () => context.push('/library?tab=programs'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Añadir'),
              ),
            ),
            const SizedBox(height: 12),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            if (state.error != null) ...[
              EntrenaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(state.error!),
                    TextButton(
                      onPressed: () => _cubit.load(keepItems: true),
                      child: const Text('Reintentar programas'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!state.loading && state.error == null && state.items.isEmpty)
              const EntrenaCard(
                child: Text(
                  'Todavía no sigues ningún programa guiado. Puedes elegir uno en la biblioteca.',
                ),
              ),
            if (state.items.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 640 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final program in state.items)
                        GuidedProgramCard(
                          key: ValueKey('training-guided-${program.id}'),
                          width: width,
                          program: program,
                          onTap: () =>
                              context.push('/library/programs/${program.id}'),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      );
}
