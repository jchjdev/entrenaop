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
  });

  final String id;
  final String name;
  final PreparationProgramKind kind;

  @override
  List<Object?> get props => [id, name, kind];
}
