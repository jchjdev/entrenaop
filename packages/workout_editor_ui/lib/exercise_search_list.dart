import 'package:flutter/material.dart';

import 'catalog_search.dart';
import 'exercise_preferences_controller.dart';
import 'exercise_labels_dialog.dart';

enum _View { all, favorites, recent }

/// Lista compartida; cada aplicación decide qué ejercicios puede ofrecer.
class ExerciseSearchList<T> extends StatefulWidget {
  const ExerciseSearchList({
    super.key,
    required this.exercises,
    required this.nameOf,
    required this.searchTermsOf,
    required this.thumbnailOf,
    required this.onSelected,
    this.subtitleOf,
    this.muscleGroupsOf,
    this.equipmentOf,
    this.searchLabel = 'Buscar por nombre, músculo o material',
    this.searchHint,
    this.emptyMessage = 'No hay ejercicios que coincidan con esta búsqueda.',
    this.idOf,
    this.preferences,
  }) : assert(preferences == null || idOf != null);

  final List<T> exercises;
  final String Function(T) nameOf;
  final Iterable<String> Function(T) searchTermsOf;
  final String? Function(T) thumbnailOf;
  final String? Function(T)? subtitleOf;
  final Iterable<String> Function(T)? muscleGroupsOf, equipmentOf;
  final ValueChanged<T> onSelected;
  final String searchLabel;
  final String? searchHint;
  final String emptyMessage;
  final String Function(T)? idOf;
  final ExercisePreferencesController? preferences;

  @override
  State<ExerciseSearchList<T>> createState() => _ExerciseSearchListState<T>();
}

class _ExerciseSearchListState<T> extends State<ExerciseSearchList<T>> {
  final _search = TextEditingController();
  String? _muscle, _equipment;
  String? _label;
  bool _filtersOpen = false;
  _View _view = _View.all;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    widget.preferences?.addListener(_preferencesChanged);
    widget.preferences?.load();
  }

  void _preferencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ExerciseSearchList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.preferences, widget.preferences)) {
      oldWidget.preferences?.removeListener(_preferencesChanged);
      _search.clear();
      _muscle = _equipment = null;
      _label = null;
      _view = _View.all;
      _listen();
    }
  }

  Map<String, String> _options(Iterable<String> Function(T)? valuesOf) {
    final options = <String, String>{};
    if (valuesOf == null) return options;
    for (final exercise in widget.exercises) {
      for (final value in valuesOf(exercise)) {
        final key = normalizeCatalogSearch(value);
        if (key.isNotEmpty) options.putIfAbsent(key, () => value.trim());
      }
    }
    return Map.fromEntries(
      options.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  bool _matchesFilter(
    T exercise,
    String? selected,
    Iterable<String> Function(T)? valuesOf,
  ) =>
      selected == null ||
      valuesOf!(exercise).any((v) => normalizeCatalogSearch(v) == selected);

  Widget _filter(
    String label,
    Map<String, String> options,
    String? selected,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$selected'),
    isExpanded: true,
    initialValue: selected ?? '',
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('Todos')),
      for (final entry in options.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (value) => changed(value == '' ? null : value),
  );

  @override
  void dispose() {
    widget.preferences?.removeListener(_preferencesChanged);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muscles = _options(widget.muscleGroupsOf);
    final equipment = _options(widget.equipmentOf);
    // Si el consumidor cambia de catálogo, no se retienen filtros inexistentes.
    final muscle = muscles.containsKey(_muscle) ? _muscle : null;
    final material = equipment.containsKey(_equipment) ? _equipment : null;
    final preferences = widget.preferences;
    String idOf(T e) => widget.idOf!(e);
    final recent = preferences == null
        ? <T>[]
        : (widget.exercises
              .where((e) => preferences.selectedAt(idOf(e)) != null)
              .toList()
            ..sort(
              (a, b) => preferences
                  .selectedAt(idOf(b))!
                  .compareTo(preferences.selectedAt(idOf(a))!),
            ));
    final recentIds = recent
        .take(preferences?.recentLimit ?? 0)
        .map(idOf)
        .toSet();
    final matches = widget.exercises
        .where((exercise) {
          return (preferences == null ||
                  switch (_view) {
                    _View.all => true,
                    _View.favorites => preferences.favorite(idOf(exercise)),
                    _View.recent => recentIds.contains(idOf(exercise)),
                  }) &&
              matchesCatalogSearch(_search.text, [
                ...widget.searchTermsOf(exercise),
                ...?preferences?.labels(idOf(exercise)),
              ]) &&
              (_label == null ||
                  (preferences?.labels(idOf(exercise)).contains(_label) ??
                      false)) &&
              _matchesFilter(exercise, muscle, widget.muscleGroupsOf) &&
              _matchesFilter(exercise, material, widget.equipmentOf);
        })
        .toList(growable: false);
    if (_view == _View.recent && preferences != null) {
      matches.sort(
        (a, b) => preferences
            .selectedAt(idOf(b))!
            .compareTo(preferences.selectedAt(idOf(a))!),
      );
    }
    return Column(
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: widget.searchLabel,
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              '${matches.length} ${matches.length == 1 ? 'ejercicio' : 'ejercicios'}',
            ),
            if (preferences != null)
              PopupMenuButton<_View>(
                tooltip: 'Ver todos, favoritos o recientes',
                initialValue: _view,
                onSelected: (view) => setState(() => _view = view),
                itemBuilder: (_) => [
                  for (final view in _View.values)
                    PopupMenuItem(value: view, child: Text(_viewLabel(view))),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_viewLabel(_view)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            if (preferences?.supportsLabels == true &&
                preferences!.labelsLoaded)
              ExerciseLabelFilter(
                labels: widget.exercises.expand(
                  (e) => preferences.labels(idOf(e)),
                ),
                selected: _label,
                onChanged: (label) => setState(() => _label = label),
              ),
            if (muscles.isNotEmpty || equipment.isNotEmpty)
              IconButton(
                tooltip: _filtersOpen ? 'Ocultar filtros' : 'Mostrar filtros',
                icon: const Icon(Icons.tune),
                onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              ),
            if (_search.text.isNotEmpty ||
                muscle != null ||
                material != null ||
                _label != null)
              TextButton(
                onPressed: () => setState(() {
                  _search.clear();
                  _muscle = null;
                  _equipment = null;
                  _label = null;
                }),
                child: const Text('Limpiar'),
              ),
          ],
        ),
        if (_filtersOpen && (muscles.isNotEmpty || equipment.isNotEmpty)) ...[
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (muscles.isNotEmpty)
                  SizedBox(
                    width: constraints.maxWidth >= 440
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: _filter(
                      'Músculo',
                      muscles,
                      muscle,
                      (v) => setState(() => _muscle = v),
                    ),
                  ),
                if (equipment.isNotEmpty)
                  SizedBox(
                    width: constraints.maxWidth >= 440
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: _filter(
                      'Material',
                      equipment,
                      material,
                      (v) => setState(() => _equipment = v),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (preferences?.loading == true) const LinearProgressIndicator(),
        if (preferences?.labelsError case final error?) Text(error),
        if (preferences?.error case final error?)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(error),
              TextButton(
                onPressed: preferences!.retry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        Expanded(
          child: matches.isEmpty
              ? Center(
                  child: Text(widget.emptyMessage, textAlign: TextAlign.center),
                )
              : ListView.separated(
                  itemCount: matches.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exercise = matches[index];
                    return ListTile(
                      leading:
                          preferences != null &&
                              MediaQuery.textScalerOf(context).scale(14) > 20
                          ? null
                          : ExerciseThumbnail(
                              url: widget.thumbnailOf(exercise),
                            ),
                      title: Text(widget.nameOf(exercise)),
                      subtitle: Text(
                        [
                          ?widget.subtitleOf?.call(exercise),
                          ...?preferences?.labels(idOf(exercise)),
                        ].join(' · '),
                      ),
                      onTap: () => widget.onSelected(exercise),
                      trailing: preferences == null
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (preferences.supportsLabels)
                                  IconButton(
                                    tooltip:
                                        'Etiquetas: ${widget.nameOf(exercise)}',
                                    icon: const Icon(Icons.label_outline),
                                    onPressed: preferences.loading
                                        ? null
                                        : () => editExerciseLabels(
                                            context,
                                            preferences,
                                            idOf(exercise),
                                            widget.nameOf(exercise),
                                          ),
                                  ),
                                IconButton(
                                  tooltip:
                                      '${preferences.favorite(idOf(exercise)) ? 'Quitar de' : 'Añadir a'} favoritos: ${widget.nameOf(exercise)}',
                                  isSelected: preferences.favorite(
                                    idOf(exercise),
                                  ),
                                  selectedIcon: const Icon(Icons.star),
                                  icon: const Icon(Icons.star_border),
                                  onPressed:
                                      !preferences.loaded ||
                                          preferences.loading ||
                                          preferences.pending(idOf(exercise))
                                      ? null
                                      : () => preferences.toggleFavorite(
                                          idOf(exercise),
                                        ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _viewLabel(_View view) => switch (view) {
    _View.all => 'Todos',
    _View.favorites => 'Favoritos',
    _View.recent => 'Recientes',
  };
}

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final validUrl = url != null && Uri.tryParse(url!)?.scheme == 'https';
    if (!validUrl) {
      return SizedBox.square(
        dimension: size,
        child: const Icon(Icons.fitness_center_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox.square(
          dimension: size,
          child: const Icon(Icons.fitness_center_outlined),
        ),
      ),
    );
  }
}
