import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

class ExerciseForm extends StatefulWidget {
  const ExerciseForm({
    super.key,
    required this.title,
    required this.supportingText,
    required this.submitLabel,
    required this.onSubmit,
    this.initialDraft,
    this.fieldKeyPrefix = 'exercise',
    this.autofocusName = true,
    this.initialImageUrl,
  });

  final String title;
  final String supportingText;
  final String submitLabel;
  final ValueChanged<ExerciseFormSubmission<ExerciseDraft>> onSubmit;
  final ExerciseDraft? initialDraft;
  final String fieldKeyPrefix;
  final bool autofocusName;
  final String? initialImageUrl;

  @override
  State<ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<ExerciseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _videoController;
  late final TextEditingController _musclesController;
  late final TextEditingController _equipmentController;
  late String _difficulty;
  late String _exerciseType;
  ExerciseImageUpload? _image;
  bool _removeExistingImage = false;
  bool _processingImage = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _nameController = TextEditingController(text: draft?.name);
    _descriptionController = TextEditingController(text: draft?.description);
    _videoController = TextEditingController(text: draft?.videoUrl);
    _musclesController = TextEditingController(
      text: draft?.muscleGroups.join(', '),
    );
    _equipmentController = TextEditingController(
      text: draft?.equipment.join(', '),
    );
    _difficulty = draft?.difficulty ?? 'inicial';
    _exerciseType = draft?.exerciseType ?? 'repeticiones';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _videoController.dispose();
    _musclesController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(widget.supportingText),
            const SizedBox(height: 18),
            _ImageHeader(
              bytes: _image?.bytes,
              initialUrl: _removeExistingImage ? null : widget.initialImageUrl,
              processing: _processingImage,
              error: _imageError,
              onPick: _pickImage,
              onRemove:
                  _image != null ||
                      (!_removeExistingImage && widget.initialImageUrl != null)
                  ? _removeImage
                  : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: ValueKey('${widget.fieldKeyPrefix}-name'),
              controller: _nameController,
              autofocus: widget.autofocusName,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Press francés con mancuerna',
              ),
              validator: ExerciseDraftValidator.nameError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Técnica o indicaciones importantes',
                alignLabelWithHint: true,
              ),
              validator: ExerciseDraftValidator.descriptionError,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _videoController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Vídeo HTTPS (opcional)',
                hintText: 'https://…',
                prefixIcon: Icon(Icons.play_circle_outline_rounded),
              ),
              validator: ExerciseDraftValidator.videoUrlError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('${widget.fieldKeyPrefix}-muscles'),
              controller: _musclesController,
              decoration: const InputDecoration(
                labelText: 'Grupos musculares',
                hintText: 'tríceps, pecho',
              ),
              validator: (value) =>
                  ExerciseDraftValidator.muscleGroupsError(_tags(value)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _equipmentController,
              decoration: const InputDecoration(
                labelText: 'Material (opcional)',
                hintText: 'mancuerna, banco',
              ),
              validator: (value) =>
                  ExerciseDraftValidator.equipmentError(_tags(value)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Dificultad'),
              items: const [
                DropdownMenuItem(value: 'inicial', child: Text('Inicial')),
                DropdownMenuItem(
                  value: 'intermedio',
                  child: Text('Intermedio'),
                ),
                DropdownMenuItem(value: 'avanzado', child: Text('Avanzado')),
              ],
              onChanged: (value) {
                if (value != null) _difficulty = value;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _exerciseType,
              decoration: const InputDecoration(labelText: 'Medición habitual'),
              items: const [
                DropdownMenuItem(
                  value: 'repeticiones',
                  child: Text('Repeticiones'),
                ),
                DropdownMenuItem(value: 'duración', child: Text('Tiempo')),
              ],
              onChanged: (value) {
                if (value != null) _exerciseType = value;
              },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _processingImage ? null : _submit,
              icon: const Icon(Icons.check_rounded),
              label: Text(widget.submitLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(
      ExerciseFormSubmission(
        draft: ExerciseDraftValidator.normalizeAndValidate(
          ExerciseDraft(
            name: _nameController.text,
            description: _descriptionController.text,
            videoUrl: _videoController.text,
            muscleGroups: _tags(_musclesController.text),
            equipment: _tags(_equipmentController.text),
            difficulty: _difficulty,
            exerciseType: _exerciseType,
          ),
        ),
        image: _image,
        removeExistingImage: _removeExistingImage,
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() {
      _processingImage = true;
      _imageError = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final optimized = await optimizeExerciseImage(await picked.readAsBytes());
      if (!mounted) return;
      setState(() {
        _image = optimized;
        _removeExistingImage = false;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _imageError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _imageError = 'No se pudo preparar la fotografía.');
      }
    } finally {
      if (mounted) setState(() => _processingImage = false);
    }
  }

  void _removeImage() => setState(() {
    _image = null;
    _removeExistingImage = true;
    _imageError = null;
  });
}

List<String> _tags(String? value) => (value ?? '').split(',').toList();

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({
    required this.bytes,
    required this.initialUrl,
    required this.processing,
    required this.error,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String? initialUrl;
  final bool processing;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final provider = bytes != null
        ? MemoryImage(bytes!) as ImageProvider
        : initialUrl != null && Uri.tryParse(initialUrl!)?.scheme == 'https'
        ? NetworkImage(initialUrl!)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (provider != null)
                  Image(image: provider, fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 44),
                        SizedBox(height: 8),
                        Text('Añade una foto del ejercicio'),
                      ],
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: processing ? null : onPick,
                        icon: processing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: Text(
                          provider == null ? 'Elegir foto' : 'Cambiar',
                        ),
                      ),
                      if (onRemove != null) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Quitar foto',
                          onPressed: processing ? null : onRemove,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          error ?? 'Se optimizará automáticamente a un máximo de 500 KB.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: error == null ? null : Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}
