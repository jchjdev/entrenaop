import 'guided_program_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/guided_program_repository.dart';
import 'guided_program_cubits.dart';

class GuidedCatalogPanel extends StatelessWidget {
  const GuidedCatalogPanel({super.key, required this.repository});
  final GuidedProgramRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GuidedCatalogCubit(repository)..load(),
    child: const _Catalog(),
  );
}

class _Catalog extends StatefulWidget {
  const _Catalog();
  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String _filter = 'all';
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cubit = context.read<GuidedCatalogCubit>();
    return BlocBuilder<GuidedCatalogCubit, GuidedCatalogState>(
      builder: (context, state) => ListView(
        key: const PageStorageKey('guided-program-catalog'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar programas',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: cubit.search,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _filter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mostrar'),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text(
                  'Todos los programas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'guide',
                child: Text(
                  'Rutinas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'phased',
                child: Text(
                  'Por fases',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'following',
                child: Text(
                  'Programas iniciados',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _filter = v);
                cubit.filter(v);
              }
            },
          ),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.error != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(state.error!),
            ),
            TextButton(
              onPressed: () => cubit.load(page: state.page),
              child: const Text('Reintentar'),
            ),
          ],
          if (!state.loading && state.error == null && state.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('No hay programas con estos criterios.'),
            ),
          if (!state.loading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in state.items)
                    GuidedProgramCard(
                      program: p,
                      onTap: () async {
                        await context.push('/library/programs/${p.id}');
                        if (mounted) await cubit.load(page: state.page);
                      },
                    ),
                ],
              ),
            ),
          if (state.error == null && (state.page > 0 || state.hasMore))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: state.loading || state.page == 0
                        ? null
                        : () => cubit.load(page: state.page - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      'Página ${state.page + 1}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Página siguiente',
                    onPressed: state.loading || !state.hasMore
                        ? null
                        : () => cubit.load(page: state.page + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
