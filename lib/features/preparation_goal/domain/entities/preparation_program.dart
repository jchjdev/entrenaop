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
  });

  final String id;
  final String name;
  final PreparationProgramKind kind;
  final String? currentAssessmentCatalogVersion;

  @override
  List<Object?> get props => [id, name, kind, currentAssessmentCatalogVersion];
}
