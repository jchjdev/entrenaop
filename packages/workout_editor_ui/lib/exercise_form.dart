import 'package:flutter/material.dart';
import 'package:workout_core/exercise_draft.dart';

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
  });

  final String title;
  final String supportingText;
  final String submitLabel;
  final ValueChanged<ExerciseDraft> onSubmit;
  final ExerciseDraft? initialDraft;
  final String fieldKeyPrefix;
  final bool autofocusName;

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
              onPressed: _submit,
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
      ExerciseDraftValidator.normalizeAndValidate(
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
    );
  }
}

List<String> _tags(String? value) => (value ?? '').split(',').toList();
