import 'guided_program_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

import '../domain/guided_program_repository.dart';
import 'guided_program_cubits.dart';

class GuidedCatalogPanel extends StatelessWidget {
  const GuidedCatalogPanel({super.key, required this.repository});
  final GuidedProgramRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GuidedCatalogCubit(repository)..load(),
    child: _Catalog(repository: repository),
  );
}

class _Catalog extends StatefulWidget {
  const _Catalog({required this.repository});
  final GuidedProgramRepository repository;
  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String _filter = 'all';
  bool _filtersExpanded = false;
  final _search = TextEditingController();
  late Future<List<GuidedProgramCategory>> _categories;
  @override
  void initState() {
    super.initState();
    _categories = widget.repository.categories();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cubit = context.read<GuidedCatalogCubit>();
    return BlocBuilder<GuidedCatalogCubit, GuidedCatalogState>(
      builder: (context, state) => ListView(
        key: const PageStorageKey('guided-program-catalog'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar',
                    prefixIcon: const Icon(Icons.search),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40),
                    suffixIconConstraints: const BoxConstraints(minWidth: 40),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            onPressed: () {
                              _search.clear();
                              cubit.search('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) {
                    cubit.search(value);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                expanded: _filtersExpanded,
                child: MediaQuery.textScalerOf(context).scale(14) > 21
                    ? IconButton.outlined(
                        tooltip: _filter == 'all'
                            ? 'Filtros'
                            : 'Filtros activos',
                        isSelected: _filter != 'all',
                        onPressed: () => setState(
                          () => _filtersExpanded = !_filtersExpanded,
                        ),
                        icon: const Icon(Icons.tune),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _filtersExpanded = !_filtersExpanded,
                        ),
                        icon: Icon(
                          _filtersExpanded ? Icons.expand_less : Icons.tune,
                        ),
                        label: Text(
                          _filter == 'all' ? 'Filtros' : 'Filtros (1)',
                        ),
                      ),
              ),
            ],
          ),
          if (_filtersExpanded) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _filter,
              isExpanded: true,
              isDense: false,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Mostrar'),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('Todos los programas'),
                ),
                DropdownMenuItem(value: 'guide', child: Text('Rutinas')),
                DropdownMenuItem(value: 'phased', child: Text('Por fases')),
                DropdownMenuItem(
                  value: 'following',
                  child: Text('Programas iniciados'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _filter = v);
                  cubit.filter(v);
                }
              },
            ),
          ],
          const SizedBox(height: 10),
          FutureBuilder<List<GuidedProgramCategory>>(
            future: _categories,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton.icon(
                  onPressed: () => setState(() {
                    _categories = widget.repository.categories();
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar categorías'),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.isEmpty) return const SizedBox.shrink();
              return SingleChildScrollView(
                key: const PageStorageKey('guided-category-strip'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      showCheckmark: false,
                      label: const Text('Todos'),
                      selected: cubit.categoryId == null,
                      onSelected: (_) => cubit.filterCategory(null),
                    ),
                    for (final c in snapshot.data!) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        showCheckmark: false,
                        key: ValueKey('guided-category-${c.id}'),
                        label: Text(c.name),
                        selected: cubit.categoryId == c.id,
                        onSelected: (_) => cubit.filterCategory(c.id),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (state.loading && state.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.error != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(state.error!),
            ),
            TextButton(onPressed: cubit.load, child: const Text('Reintentar')),
          ],
          if (!state.loading && state.error == null && state.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('No hay programas con estos criterios.'),
            ),
          if (state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 640 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final p in state.items)
                        GuidedProgramCard(
                          width: width,
                          program: p,
                          onTap: () async {
                            await context.push('/library/programs/${p.id}');
                            if (mounted) await cubit.load(keepItems: true);
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
