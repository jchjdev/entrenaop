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
class PreparationProgramCover extends Equatable {
  const PreparationProgramCover({
    required this.cardUrl,
    required this.headerUrl,
    this.focalX = 0.5,
    this.focalY = 0.5,
    double? headerFocalX,
    double? headerFocalY,
  }) : headerFocalX = headerFocalX ?? focalX,
       headerFocalY = headerFocalY ?? focalY;
  final String cardUrl, headerUrl;
  final double focalX, focalY;
  final double headerFocalX, headerFocalY;
  @override
  List<Object?> get props => [
    cardUrl,
    headerUrl,
    focalX,
    focalY,
    headerFocalX,
    headerFocalY,
  ];
}
