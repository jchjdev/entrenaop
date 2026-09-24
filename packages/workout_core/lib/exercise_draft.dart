import 'package:equatable/equatable.dart';

/// Campos editoriales comunes de un ejercicio.
///
/// La visibilidad, el origen y la propiedad no forman parte del borrador: cada
/// backend debe imponerlos según el contexto desde el que se guarda.
class ExerciseDraft extends Equatable {
  const ExerciseDraft({
    required this.name,
    required this.muscleGroups,
    required this.equipment,
    required this.difficulty,
    required this.exerciseType,
    this.description,
    this.videoUrl,
  });

  final String name;
  final String? description;
  final String? videoUrl;
  final List<String> muscleGroups;
  final List<String> equipment;
  final String difficulty;
  final String exerciseType;

  @override
  List<Object?> get props => [
    name,
    description,
    videoUrl,
    muscleGroups,
    equipment,
    difficulty,
    exerciseType,
  ];
}

abstract final class ExerciseDraftValidator {
  static const difficulties = {'inicial', 'intermedio', 'avanzado'};
  static const exerciseTypes = {'repeticiones', 'duración'};

  static String? nameError(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 2 || length > 80
        ? 'Escribe entre 2 y 80 caracteres.'
        : null;
  }

  static String? descriptionError(String? value) =>
      (value?.trim().length ?? 0) > 500
      ? 'La descripción no puede superar 500 caracteres.'
      : null;

  static String? videoUrlError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return text.length > 500 ||
            uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty
        ? 'Introduce una dirección HTTPS válida.'
        : null;
  }

  static String? muscleGroupsError(Iterable<String> values) {
    final tags = normalizeTags(values);
    if (tags.isEmpty) return 'Añade al menos un grupo muscular.';
    if (tags.length > 10) return 'Añade como máximo 10 grupos.';
    if (tags.any((tag) => tag.length > 40)) {
      return 'Cada grupo muscular puede tener hasta 40 caracteres.';
    }
    return null;
  }

  static String? equipmentError(Iterable<String> values) {
    final tags = normalizeTags(values);
    if (tags.length > 10) return 'Añade como máximo 10 materiales.';
    if (tags.any((tag) => tag.length > 40)) {
      return 'Cada material puede tener hasta 40 caracteres.';
    }
    return null;
  }

  static List<String> normalizeTags(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    normalized.sort();
    return List.unmodifiable(normalized);
  }

  static ExerciseDraft normalizeAndValidate(ExerciseDraft draft) {
    final normalized = ExerciseDraft(
      name: draft.name.trim(),
      description: _optional(draft.description),
      videoUrl: _optional(draft.videoUrl),
      muscleGroups: normalizeTags(draft.muscleGroups),
      equipment: normalizeTags(draft.equipment),
      difficulty: draft.difficulty,
      exerciseType: draft.exerciseType,
    );

    final error =
        nameError(normalized.name) ??
        descriptionError(normalized.description) ??
        videoUrlError(normalized.videoUrl) ??
        muscleGroupsError(normalized.muscleGroups) ??
        equipmentError(normalized.equipment) ??
        (!difficulties.contains(normalized.difficulty)
            ? 'La dificultad elegida no es válida.'
            : null) ??
        (!exerciseTypes.contains(normalized.exerciseType)
            ? 'El tipo de ejercicio elegido no es válido.'
            : null);
    if (error != null) throw FormatException(error);
    return normalized;
  }

  static String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
