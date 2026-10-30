import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workout_editor_ui/exercise_video_preview.dart';

import '../domain/coach_planning_repository.dart';

import 'package:trainer_access/trainer_access.dart';

import 'coach_workspace_scope.dart';

class CoachExerciseLibraryPage extends StatefulWidget {
  const CoachExerciseLibraryPage({super.key});
  @override
  State<CoachExerciseLibraryPage> createState() =>
      _CoachExerciseLibraryPageState();
}

class _CoachExerciseLibraryPageState extends State<CoachExerciseLibraryPage> {
  bool _official = false, _initialized = false;
  String _query = '';
  late Future<List<CoachExerciseReference>> _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _future = _read();
    }
  }

  Future<List<CoachExerciseReference>> _read() =>
      CoachWorkspaceScope.of(context).planning!.exercises(official: _official);
  Future<void> _refresh() async {
    setState(() => _future = _read());
    try {
      await _future;
    } catch (_) {
      /* El error queda visible y se conserva el buscador. */
    }
  }

  void _origin(bool official) {
    if (_official == official) return;
    setState(() {
      _official = official;
      _future = _read();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ejercicios')),
    body: FutureBuilder<List<CoachExerciseReference>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final rows = loading
            ? <CoachExerciseReference>[]
            : (snapshot.data ?? [])
                  .where((e) => e.name.toLowerCase().contains(_query))
                  .toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Los míos'),
                          selected: !_official,
                          onSelected: (_) => _origin(false),
                        ),
                        ChoiceChip(
                          label: const Text('EntrenaOP'),
                          selected: _official,
                          onSelected: (_) => _origin(true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (q) =>
                          setState(() => _query = q.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        labelText: 'Buscar ejercicio',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (loading) const LinearProgressIndicator(),
                    if (snapshot.hasError) ...[
                      Text(trainerError(snapshot.error!)),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ] else if (rows.isEmpty && !loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay ejercicios que coincidan.'),
                      ),
                  ],
                );
              }
              final e = rows[index - 1];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: e.imageUrl == null
                        ? const Icon(Icons.fitness_center)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              e.imageUrl!,
                              cacheWidth: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, trace) => const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            ),
                          ),
                  ),
                  title: Text(e.name),
                  subtitle: Text(
                    e.official
                        ? 'EntrenaOP · solo consulta'
                        : 'Tu ejercicio privado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _detail(e),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  Future<void> _detail(CoachExerciseReference e) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: .9,
      child: Scaffold(
        appBar: AppBar(title: Text(e.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(e.official ? 'Catálogo de EntrenaOP' : 'Tu ejercicio privado'),
            const SizedBox(height: 16),
            if (e.imageUrl != null)
              Image.network(
                e.imageUrl!,
                height: 220,
                fit: BoxFit.contain,
                cacheWidth: 800,
                errorBuilder: (_, error, trace) => const Text(
                  'No se pudo cargar la imagen. Actualiza la biblioteca para reintentar.',
                ),
              ),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(e.description),
            ],
            if (Uri.tryParse(e.videoUrl ?? '') case final uri?
                when uri.scheme == 'https' && uri.userInfo.isEmpty) ...[
              const SizedBox(height: 16),
              if (uri.host.endsWith('.b-cdn.net'))
                if (TickerMode.valuesOf(sheet).enabled &&
                    CoachWorkspaceScope.of(sheet).controller.canRead)
                  ExerciseVideoPreview(
                    url: e.videoUrl!,
                    source: CoachWorkspaceScope.of(context).video,
                  )
                else
                  const Text('Reproducción detenida.')
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir demostración'),
                  onPressed: () async {
                    var opened = false;
                    try {
                      opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      /* Se mantiene la consulta si el proveedor no responde. */
                    }
                    if (!opened && sheet.mounted) {
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        const SnackBar(
                          content: Text('No se ha podido abrir el vídeo.'),
                        ),
                      );
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
