import 'package:flutter/material.dart';

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
    this.searchLabel = 'Buscar por nombre, músculo o material',
    this.searchHint,
    this.emptyMessage = 'No hay ejercicios que coincidan con esta búsqueda.',
  });

  final List<T> exercises;
  final String Function(T) nameOf;
  final Iterable<String> Function(T) searchTermsOf;
  final String? Function(T) thumbnailOf;
  final String? Function(T)? subtitleOf;
  final ValueChanged<T> onSelected;
  final String searchLabel;
  final String? searchHint;
  final String emptyMessage;

  @override
  State<ExerciseSearchList<T>> createState() => _ExerciseSearchListState<T>();
}

class _ExerciseSearchListState<T> extends State<ExerciseSearchList<T>> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = widget.exercises
        .where((exercise) {
          if (query.isEmpty) return true;
          return widget
              .searchTermsOf(exercise)
              .join(' ')
              .toLowerCase()
              .contains(query);
        })
        .toList(growable: false);
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
                      leading: ExerciseThumbnail(
                        url: widget.thumbnailOf(exercise),
                      ),
                      title: Text(widget.nameOf(exercise)),
                      subtitle: widget.subtitleOf == null
                          ? null
                          : Text(widget.subtitleOf!(exercise) ?? ''),
                      onTap: () => widget.onSelected(exercise),
                    );
                  },
                ),
        ),
      ],
    );
  }
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
