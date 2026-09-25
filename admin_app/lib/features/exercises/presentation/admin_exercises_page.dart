import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

class AdminExercisesPage extends StatefulWidget {
  const AdminExercisesPage({super.key, required this.repository});

  final AdminExerciseRepository repository;

  @override
  State<AdminExercisesPage> createState() => _AdminExercisesPageState();
}

class _AdminExercisesPageState extends State<AdminExercisesPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<AdminCatalogExercise> _exercises = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exercises = await widget.repository.listOfficial();
      if (!mounted) return;
      setState(() {
        _exercises = exercises;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el catálogo oficial.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([AdminCatalogExercise? exercise]) async {
    final submission = await showDialog<ExerciseFormSubmission<ExerciseDraft>>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ExerciseForm(
              title: exercise == null
                  ? 'Nuevo ejercicio oficial'
                  : 'Editar ejercicio oficial',
              supportingText:
                  'Se publicará en el catálogo general de EntrenaOP.',
              submitLabel: exercise == null
                  ? 'Crear ejercicio'
                  : 'Guardar cambios',
              fieldKeyPrefix: 'admin-exercise',
              initialDraft: exercise?.toDraft(),
              initialImageUrl: exercise?.imageUrl,
              onSubmit: (value) => Navigator.of(dialogContext).pop(value),
            ),
          ),
        ),
      ),
    );
    if (submission == null || !mounted) return;

    setState(() => _saving = true);
    try {
      if (exercise == null) {
        await widget.repository.createOfficial(
          submission.draft,
          image: submission.image,
        );
      } else {
        await widget.repository.updateOfficial(
          exercise.id,
          submission.draft,
          image: submission.image,
          removeImage: submission.removeExistingImage,
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exercise == null
                ? 'Ejercicio oficial creado.'
                : 'Ejercicio oficial actualizado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar. Comprueba el permiso y los datos.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administración · ejercicios')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: _buildContent(),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving ? null : _openEditor,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo ejercicio'),
    ),
  );

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_exercises.isEmpty) {
      return const Center(child: Text('Todavía no hay ejercicios oficiales.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
      itemCount: _exercises.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final exercise = _exercises[index];
        return Card(
          child: ListTile(
            leading: _ExerciseImage(url: exercise.imageUrl),
            title: Text(exercise.name),
            subtitle: Text(
              [...exercise.muscleGroups, ...exercise.equipment].join(' · '),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _saving ? null : () => _openEditor(exercise),
          ),
        );
      },
    );
  }
}

class _ExerciseImage extends StatelessWidget {
  const _ExerciseImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 64,
      height: 48,
      child: url == null
          ? ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.fitness_center_outlined),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
            ),
    ),
  );
}
