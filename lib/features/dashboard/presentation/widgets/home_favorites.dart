import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension HomeShortcutPresentation on HomeShortcut {
  String get label => switch (this) {
    HomeShortcut.personalSessions => 'Mis sesiones',
    HomeShortcut.personalExercises => 'Mis ejercicios',
    HomeShortcut.availability => 'Disponibilidad',
  };

  String get route => switch (this) {
    HomeShortcut.personalSessions => '/plan/library?tab=personal',
    HomeShortcut.personalExercises => '/library/exercises?tab=personal',
    HomeShortcut.availability => '/profile/preferences',
  };

  IconData get icon => switch (this) {
    HomeShortcut.personalSessions => Icons.fitness_center_rounded,
    HomeShortcut.personalExercises => Icons.sports_gymnastics_outlined,
    HomeShortcut.availability => Icons.schedule_outlined,
  };
}

class HomeFavorites extends StatefulWidget {
  const HomeFavorites({
    super.key,
    required this.repository,
    required this.userId,
    required this.onOpen,
  });

  final HomeFavoritesRepository repository;
  final String userId;
  final Future<void> Function(String route) onOpen;

  @override
  State<HomeFavorites> createState() => _HomeFavoritesState();
}

class _HomeFavoritesState extends State<HomeFavorites> {
  List<HomeShortcut> _favorites = List.of(defaultHomeFavorites);
  bool _loading = true;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final favorites = await widget.repository.load(widget.userId);
      if (mounted) setState(() => _favorites = favorites);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final chosen = await showModalBottomSheet<List<HomeShortcut>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FavoritesEditor(initial: _favorites),
    );
    if (chosen == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.save(widget.userId, chosen);
      if (mounted) setState(() => _favorites = chosen);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron guardar los favoritos. Se conservan los anteriores.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HomeSectionHeading(
        title: 'Tus favoritos',
        action: TextButton.icon(
          onPressed: _loading || _saving || _failed ? null : _edit,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(_saving ? 'Guardando…' : 'Editar'),
        ),
      ),
      const SizedBox(height: 8),
      if (_loading)
        const LinearProgressIndicator()
      else if (_failed)
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('No pudimos cargar tus favoritos. Reintentar'),
        )
      else if (_favorites.isEmpty)
        const Text('Elige los accesos que quieras tener a mano.')
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680
                ? _favorites.length
                : constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(14) > 23
                ? 1
                : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in _favorites)
                  SizedBox(
                    width: width,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 76),
                      child: EntrenaCard(
                        tone: EntrenaCardTone.quiet,
                        padding: const EdgeInsets.all(14),
                        onTap: () => widget.onOpen(item.route),
                        child: Row(
                          children: [
                            Icon(item.icon, size: 21),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
    ],
  );
}

class _FavoritesEditor extends StatefulWidget {
  const _FavoritesEditor({required this.initial});
  final List<HomeShortcut> initial;
  @override
  State<_FavoritesEditor> createState() => _FavoritesEditorState();
}

class _FavoritesEditorState extends State<_FavoritesEditor> {
  late final List<HomeShortcut> _selected = List.of(widget.initial);
  String? _message;

  void _toggle(HomeShortcut item, bool selected) => setState(() {
    _message = null;
    if (!selected) {
      _selected.remove(item);
    } else if (_selected.length < maxHomeFavorites) {
      _selected.add(item);
    } else {
      _message =
          'Quita un favorito antes de añadir otro. Puedes tener hasta tres.';
    }
  });

  void _move(int index, int offset) => setState(() {
    final item = _selected.removeAt(index);
    _selected.insert(index + offset, item);
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tus favoritos',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Elige tus accesos y ordénalos como prefieras. Las funciones siguen en su sitio aunque las quites.',
            ),
            const SizedBox(height: 12),
            for (final item in HomeShortcut.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(item.label),
                value: _selected.contains(item),
                onChanged: (selected) => _toggle(item, selected ?? false),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(liveRegion: true, child: Text(_message!)),
              ),
            if (_selected.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Orden en Inicio',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final (index, item) in _selected.indexed)
                Row(
                  children: [
                    Expanded(child: Text('${index + 1}. ${item.label}')),
                    IconButton(
                      tooltip: 'Subir ${item.label}',
                      onPressed: index == 0 ? null : () => _move(index, -1),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Bajar ${item.label}',
                      onPressed: index == _selected.length - 1
                          ? null
                          : () => _move(index, 1),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pop(List<HomeShortcut>.of(_selected)),
              child: const Text('Guardar favoritos'),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    ),
  );
}
