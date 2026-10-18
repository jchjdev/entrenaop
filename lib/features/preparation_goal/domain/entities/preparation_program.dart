import 'package:workout_core/editorial_cover.dart';
import 'package:equatable/equatable.dart';

enum PreparationProgramKind { access, internalAssessment }

/// Preparación oficial que EntrenaOP ofrece en su catálogo.
///
/// El usuario puede seguir varias, pero solo una vez cada programa mientras
/// permanezca activo.
class PreparationProgram extends Equatable {
  const PreparationProgram({
    required this.id,
    required this.name,
    required this.kind,
    this.currentAssessmentCatalogVersion,
    this.cover,
  });

  final String id;
  final String name;
  final PreparationProgramKind kind;
  final String? currentAssessmentCatalogVersion;
  final PreparationProgramCover? cover;

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    currentAssessmentCatalogVersion,
    cover,
  ];
}

/// Identidad editorial del catálogo; no participa en la planificación deportiva.
class PreparationProgramCover extends EditorialCover {
  const PreparationProgramCover({
    required super.cardUrl,
    required super.headerUrl,
    super.focalX,
    super.focalY,
    super.headerFocalX,
    super.headerFocalY,
  });
}
