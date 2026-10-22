import 'running_step.dart';

/// Contrato de persistencia V2. Las entidades no dependen de su representación.
abstract final class RunningStepCodec {
  static Map<String, dynamic> encode(RunningStepMetadata step) => {
    'schema_version': 2,
    'kind': step.kind.name,
    'completion': step.completion.name,
  };
  static RunningStepMetadata? decode(Object? value) {
    if (value == null) return null;
    if (value is! Map ||
        value['schema_version'] != 2 ||
        value.length != 3 ||
        !RunningStepKind.values.any((v) => v.name == value['kind']) ||
        !RunningStepCompletion.values.any(
          (v) => v.name == value['completion'],
        )) {
      throw const FormatException('Paso de carrera incompatible.');
    }
    return RunningStepMetadata(
      kind: RunningStepKind.values.byName(value['kind'] as String),
      completion: RunningStepCompletion.values.byName(
        value['completion'] as String,
      ),
    );
  }
}
