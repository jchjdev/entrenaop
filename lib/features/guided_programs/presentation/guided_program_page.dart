import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';
import 'package:entrena_ui/entrena_ui.dart';

import '../../../core/presentation/images/editorial_cover_provider.dart';

import 'guided_program_cubits.dart';

class GuidedProgramPage extends StatefulWidget {
  const GuidedProgramPage({super.key});
  @override
  State<GuidedProgramPage> createState() => _GuidedProgramPageState();
}

class _GuidedProgramPageState extends State<GuidedProgramPage> {
  int? _selectedPhase;
  Future<void> _advance(GuidedDetailCubit cubit) async {
    final d = cubit.state.detail!;
    final last = d.currentPhase == d.program.phases.length - 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(last ? 'Completar programa' : 'Pasar a la siguiente fase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.program.phases[d.currentPhase].instructions),
              const SizedBox(height: 16),
              const Text(
                'Confirma que has revisado estas condiciones y quieres avanzar. El tiempo transcurrido no cambia la fase por sí solo.',
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar en esta fase'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(last ? 'Completar programa' : 'Confirmar avance'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _selectedPhase = null);
      await cubit.advance();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<GuidedDetailCubit, GuidedDetailState>(
    builder: (context, state) {
      final cubit = context.read<GuidedDetailCubit>(), d = state.detail;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Programa EntrenaOP'),
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/library');
              }
            },
          ),
        ),
        body: d == null
            ? Center(
                child: state.loading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.error ?? 'Programa no disponible.'),
                          TextButton(
                            onPressed: cubit.load,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      EntrenaCard(
                        coverImage: editorialCoverProvider(
                          d.program.cover?.headerUrl,
                        ),
                        focalX: d.program.cover?.headerFocalX ?? 0.5,
                        focalY: d.program.cover?.headerFocalY ?? 0.5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.program.modeLabel,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              d.program.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (d.program.description.isNotEmpty)
                        Text(d.program.description),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Información y material'),
                        children: [
                          ListTile(
                            title: const Text('Destinatarios y requisitos'),
                            subtitle: Text(
                              d.program.audience.isEmpty
                                  ? 'Consulta las indicaciones del programa.'
                                  : d.program.audience,
                            ),
                          ),
                          ListTile(
                            title: const Text('Material'),
                            subtitle: Text(
                              d.program.equipment.isEmpty
                                  ? 'Consulta cada sesión.'
                                  : d.program.equipment,
                            ),
                          ),
                          Text(
                            'Versión ${d.program.version}. Tus entrenamientos conservan la pauta utilizada.',
                          ),
                        ],
                      ),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(state.error!),
                        ),
                      if (d.follow == null)
                        FilledButton(
                          onPressed: state.busy ? null : cubit.follow,
                          child: Text(
                            state.busy ? 'Guardando…' : 'Iniciar programa',
                          ),
                        ),
                      if (d.follow?.completed == true) ...[
                        const ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('Programa completado'),
                          subtitle: Text(
                            'Tus entrenamientos siguen en el historial.',
                          ),
                        ),
                        if (d.program.status == 'published')
                          FilledButton(
                            onPressed: state.busy
                                ? null
                                : () async {
                                    setState(() => _selectedPhase = null);
                                    await cubit.follow();
                                  },
                            child: const Text('Repetir programa'),
                          ),
                      ],
                      if (d.program.mode == GuidedProgramMode.phased) ...[
                        const SizedBox(height: 18),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'phase-${_selectedPhase ?? d.currentPhase}',
                          ),
                          initialValue: _selectedPhase ?? d.currentPhase,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Fase'),
                          items: [
                            for (var i = 0; i < d.program.phases.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  '${i + 1}. ${d.program.phases[i].name}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _selectedPhase = v),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${d.program.phases[_selectedPhase ?? d.currentPhase].durationWeeks} semanas orientativas',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d
                              .program
                              .phases[_selectedPhase ?? d.currentPhase]
                              .instructions,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Sesiones',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (
                        var i = 0;
                        i <
                            d
                                .program
                                .phases[_selectedPhase ?? d.currentPhase]
                                .sessions
                                .length;
                        i++
                      )
                        Builder(
                          builder: (context) {
                            final phase = _selectedPhase ?? d.currentPhase;
                            final session = d.program.phases[phase].sessions[i];
                            final guided =
                                d.follow != null &&
                                d.follow?.completed == false &&
                                phase == d.currentPhase;
                            final recent = d.runs
                                .where(
                                  (r) =>
                                      r.phaseIndex == phase &&
                                      r.sessionIndex == i,
                                )
                                .firstOrNull;
                            final status = recent?.status == 'in_progress'
                                ? 'En curso'
                                : recent?.status == 'completed'
                                ? 'Realizada'
                                : null;
                            return Card(
                              child: ListTile(
                                title: Text(session.name),
                                subtitle: Text(
                                  [
                                    if (guided && i == d.nextSession)
                                      'Siguiente en la secuencia',
                                    ?status,
                                    if (session.warmupId != null)
                                      'Calentamiento opcional',
                                    if (!guided) 'Vista previa de la sesión',
                                  ].join(' · '),
                                ),
                                trailing: Icon(
                                  guided
                                      ? Icons.play_arrow_rounded
                                      : Icons.chevron_right,
                                ),
                                onTap: () async {
                                  final path =
                                      '/library/programs/${d.program.id}/session/$phase/$i';
                                  await context.push(path);
                                  if (mounted) await cubit.load();
                                },
                              ),
                            );
                          },
                        ),
                      if (d.follow != null &&
                          d.follow?.completed == false &&
                          d.program.mode == GuidedProgramMode.phased &&
                          (_selectedPhase == null ||
                              _selectedPhase == d.currentPhase)) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: state.busy ? null : () => _advance(cubit),
                          child: Text(
                            d.currentPhase == d.program.phases.length - 1
                                ? 'Completar programa'
                                : 'Revisar paso de fase',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
