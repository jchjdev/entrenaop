import 'package:equatable/equatable.dart';

import 'performance_time.dart';

/// Este circuito registra marcas escalares. Las tareas que necesitan otra
/// captura (reactividad, masa corporal/carga o aptitud normativa) no se degradan
/// a texto libre: requieren otro contrato y no se ofrecen aquí.
enum ProfessionalMarkUnit { repetitions, seconds, meters }

enum ProfessionalBetterDirection { higher, lower }

enum ProfessionalRetryPolicy { none, always, invalidOnly }

enum ProfessionalProtocolSource { custom, official }

abstract final class ProfessionalAssessmentLimits {
  static const versions = 100;
  static const tests = 40;
  static const attempts = 10;
  static const magnitude = 1000000000.0;
  static const minimumResolution = 0.000001;
}

class ProfessionalAssessmentTest extends Equatable {
  const ProfessionalAssessmentTest({
    required this.id,
    required this.name,
    required this.unit,
    required this.direction,
    required this.resolution,
    required this.instructions,
    required this.maximumAttempts,
    required this.retryPolicy,
    this.source = ProfessionalProtocolSource.custom,
    this.officialTestId,
    this.protocolFingerprint,
    this.definitionVersion,
    this.protocolId,
    this.protocolVersion,
  });
  final String id, name, instructions;
  final ProfessionalMarkUnit unit;
  final ProfessionalBetterDirection direction;
  final double resolution;
  final int maximumAttempts;
  final ProfessionalRetryPolicy retryPolicy;
  final ProfessionalProtocolSource source;
  final String? officialTestId, protocolFingerprint;
  final int? definitionVersion;
  final String? protocolId;
  final int? protocolVersion;
  @override
  List<Object?> get props => [
    id,
    name,
    unit,
    direction,
    resolution,
    instructions,
    maximumAttempts,
    retryPolicy,
    source,
    officialTestId,
    protocolFingerprint,
    definitionVersion,
    protocolId,
    protocolVersion,
  ];
}

class ProfessionalAssessmentDelivery {
  ProfessionalAssessmentDelivery({
    required this.id,
    required this.clientId,
    required this.relationId,
    required this.trainerId,
    required this.trainerName,
    required this.clientName,
    required this.status,
    required this.revision,
    required this.scheduledDate,
    required this.createdAt,
    required this.battery,
    required this.canStart,
    required this.canEdit,
    this.startedAt,
    this.completedAt,
    required Map<String, List<ProfessionalAssessmentAttempt>> answers,
  }) : answers = Map.unmodifiable(
         answers.map(
           (key, value) => MapEntry(
             key,
             List<ProfessionalAssessmentAttempt>.unmodifiable(value),
           ),
         ),
       );
  final String id,
      clientId,
      relationId,
      trainerId,
      trainerName,
      clientName,
      status;
  final int revision;
  final DateTime scheduledDate, createdAt;
  final DateTime? startedAt, completedAt;
  final ProfessionalAssessmentVersion battery;
  final bool canStart, canEdit;
  final Map<String, List<ProfessionalAssessmentAttempt>> answers;
  String get statusLabel => switch (status) {
    'planned' => 'Pendiente',
    'in_progress' => 'En curso',
    'completed' => 'Completada',
    'withdrawn' => 'Retirada',
    _ => 'Estado desconocido',
  };
}

abstract class ProfessionalAssessmentStudentRepository {
  Future<List<ProfessionalAssessmentDelivery>> mine({
    ProfessionalAssessmentDelivery? before,
  });
  Future<ProfessionalAssessmentDelivery> delivery(String id);
  Future<ProfessionalAssessmentDelivery> start(
    String operationId,
    ProfessionalAssessmentDelivery delivery,
  );
  Future<ProfessionalAssessmentDelivery> save(
    String operationId,
    ProfessionalAssessmentDelivery delivery,
    Map<String, List<ProfessionalAssessmentAttempt>> answers, {
    required bool finish,
  });
}

/// Evento de prueba real, separado de las sesiones de entrenamiento.
/// [date] es fecha civil pautada; no representa un instante UTC.
class ProfessionalAssessmentEvent {
  const ProfessionalAssessmentEvent({
    required this.id,
    required this.date,
    required this.status,
    required this.revision,
    required this.title,
    required this.clientId,
    required this.relationId,
    required this.personName,
  });
  final String id, status, title, clientId, relationId, personName;
  final DateTime date;
  final int revision;
  String get kind => 'assessment';
  static const pageSize = 200;

  /// Debe conservarse date+id del último evento para avanzar sin omitir filas.
  Map<String, dynamic> get cursorParameters => {
    'p_before_date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'p_before_id': id,
  };
}

/// Puerto opcional de agenda. No obliga a las implementaciones de captura a
/// cargar calendarios ni altera sus dobles de prueba.
abstract class ProfessionalAssessmentEventRepository {
  Future<List<ProfessionalAssessmentEvent>> listAssessmentEvents({
    required DateTime start,
    required DateTime endExclusive,
    ProfessionalAssessmentEvent? before,
  });
}

class ProfessionalMarkComparison {
  const ProfessionalMarkComparison({
    required this.test,
    required this.previous,
    required this.current,
    required this.favorableDifference,
  });
  final ProfessionalAssessmentTest test;
  final double previous, current, favorableDifference;
}

/// Compara marcas originales registradas, nunca puntos de baremos distintos.
/// La huella procede del servidor y fija fuente, protocolo y condiciones.
List<ProfessionalMarkComparison> compareProfessionalAssessments(
  ProfessionalAssessmentDelivery previous,
  ProfessionalAssessmentDelivery current,
) {
  if (previous.id == current.id ||
      previous.clientId != current.clientId ||
      previous.trainerId != current.trainerId ||
      previous.status != 'completed' ||
      current.status != 'completed' ||
      previous.completedAt == null ||
      current.completedAt == null ||
      !previous.completedAt!.isBefore(current.completedAt!)) {
    return const [];
  }
  final comparisons = <ProfessionalMarkComparison>[];
  for (final test in current.battery.tests) {
    final fingerprint = test.protocolFingerprint;
    if (fingerprint == null || fingerprint.isEmpty) continue;
    final old = previous.battery.tests
        .where((t) => t.protocolFingerprint == fingerprint)
        .singleOrNull;
    if (old == null ||
        old.unit != test.unit ||
        old.direction != test.direction ||
        old.resolution != test.resolution) {
      continue;
    }
    final before = ProfessionalAssessmentValidator.best(
      old,
      previous.answers[old.id] ?? const [],
    );
    final after = ProfessionalAssessmentValidator.best(
      test,
      current.answers[test.id] ?? const [],
    );
    if (before == null || after == null) continue;
    comparisons.add(
      ProfessionalMarkComparison(
        test: test,
        previous: before,
        current: after,
        favorableDifference:
            test.direction == ProfessionalBetterDirection.higher
            ? after - before
            : before - after,
      ),
    );
  }
  return List.unmodifiable(comparisons);
}

class ProfessionalAssessmentVersion {
  ProfessionalAssessmentVersion({
    required this.id,
    required this.familyId,
    required this.version,
    required this.title,
    this.description,
    required Iterable<ProfessionalAssessmentTest> tests,
  }) : tests = List.unmodifiable(tests);
  final String id, familyId, title;
  final int version;
  final String? description;
  final List<ProfessionalAssessmentTest> tests;
}

class ProfessionalAssessmentAttempt extends Equatable {
  const ProfessionalAssessmentAttempt({required this.valid, this.value});
  final bool valid;
  final double? value;
  @override
  List<Object?> get props => [valid, value];
}

abstract final class ProfessionalAssessmentValidator {
  static final _id = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');
  static ProfessionalAssessmentVersion normalize(
    ProfessionalAssessmentVersion form,
  ) {
    if (form.title.trim().isEmpty ||
        form.title.trim().length > 120 ||
        (form.description?.trim().length ?? 0) > 1000 ||
        form.version < 1 ||
        form.tests.isEmpty ||
        form.tests.length > ProfessionalAssessmentLimits.tests) {
      throw const FormatException(
        'La batería necesita título y entre 1 y 40 pruebas.',
      );
    }
    final ids = <String>{};
    for (final test in form.tests) {
      if (!_id.hasMatch(test.id) ||
          !ids.add(test.id) ||
          test.name.trim().isEmpty ||
          test.name.trim().length > 120 ||
          test.instructions.trim().length < 10 ||
          test.instructions.trim().length > 2000 ||
          !test.resolution.isFinite ||
          test.resolution < ProfessionalAssessmentLimits.minimumResolution ||
          test.resolution > ProfessionalAssessmentLimits.magnitude ||
          test.maximumAttempts < 1 ||
          test.maximumAttempts > ProfessionalAssessmentLimits.attempts ||
          (test.maximumAttempts == 1 &&
              test.retryPolicy != ProfessionalRetryPolicy.none) ||
          (test.maximumAttempts > 1 &&
              test.retryPolicy == ProfessionalRetryPolicy.none) ||
          (test.unit == ProfessionalMarkUnit.repetitions &&
              test.resolution % 1 != 0) ||
          (test.source == ProfessionalProtocolSource.official &&
              test.officialTestId == null)) {
        throw const FormatException(
          'Revisa identidad, nombre, protocolo, resolución y política de intentos.',
        );
      }
    }
    return ProfessionalAssessmentVersion(
      id: form.id,
      familyId: form.familyId,
      version: form.version,
      title: form.title.trim(),
      description: form.description?.trim(),
      tests: form.tests,
    );
  }

  /// Ausencia/nulo no equivale a una marca válida de cero. No se redondean los
  /// valores para que encajen en una resolución. Los segundos reutilizan el
  /// parser deportivo existente: `1:30` y `90` son noventa segundos.
  static double parseMark(String text, ProfessionalAssessmentTest test) {
    final value = test.unit == ProfessionalMarkUnit.seconds
        ? parsePerformanceTime(text)
        : double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || !validMark(value, test)) {
      throw const FormatException(
        'Marca no válida para la unidad y resolución del protocolo.',
      );
    }
    return value;
  }

  static bool validMark(double value, ProfessionalAssessmentTest test) =>
      value.isFinite &&
      value >= 0 &&
      value <= ProfessionalAssessmentLimits.magnitude &&
      (test.unit != ProfessionalMarkUnit.repetitions || value % 1 == 0) &&
      _multiple(value, test.resolution);

  /// Comprobación decimal exacta sobre la representación enviada a JSON; evita
  /// tolerancias que admitirían marcas que PostgreSQL rechazaría por resolución.
  static bool _multiple(double value, double step) {
    if (!step.isFinite || step <= 0) return false;
    (BigInt, BigInt) fraction(double value) {
      final parts = value.toString().toLowerCase().split('e');
      final decimal = parts.first.split('.');
      final exponent = parts.length == 2 ? int.parse(parts.last) : 0;
      final digits = BigInt.parse(decimal.join());
      final scale = (decimal.length == 2 ? decimal.last.length : 0) - exponent;
      return scale >= 0
          ? (digits, BigInt.from(10).pow(scale))
          : (digits * BigInt.from(10).pow(-scale), BigInt.one);
    }

    final (n, d) = fraction(value);
    final (sn, sd) = fraction(step);
    return (n * sd) % (sn * d) == BigInt.zero;
  }

  static Map<String, List<ProfessionalAssessmentAttempt>> answers(
    ProfessionalAssessmentVersion form,
    Map<String, List<ProfessionalAssessmentAttempt>> values, {
    required bool complete,
  }) {
    normalize(form);
    if (values.keys.any((id) => !form.tests.any((t) => t.id == id))) {
      throw const FormatException('Hay pruebas ajenas a esta batería.');
    }
    final normalized = <String, List<ProfessionalAssessmentAttempt>>{};
    for (final test in form.tests) {
      final attempts = values[test.id];
      if (attempts == null || attempts.isEmpty) {
        if (complete) {
          throw FormatException(
            'Registra al menos un intento de «${test.name}».',
          );
        }
        continue;
      }
      if (attempts.length > test.maximumAttempts) {
        throw const FormatException('Demasiados intentos.');
      }
      var validSeen = false;
      for (final attempt in attempts) {
        if ((test.retryPolicy == ProfessionalRetryPolicy.invalidOnly &&
                validSeen) ||
            (attempt.valid &&
                (attempt.value == null || !validMark(attempt.value!, test))) ||
            (!attempt.valid && attempt.value != null)) {
          throw const FormatException(
            'Intentos incompatibles con el protocolo. Un nulo no lleva una marca inventada.',
          );
        }
        validSeen |= attempt.valid;
      }
      normalized[test.id] = List.unmodifiable(attempts);
    }
    return Map.unmodifiable(normalized);
  }

  static double? best(
    ProfessionalAssessmentTest test,
    Iterable<ProfessionalAssessmentAttempt> attempts,
  ) {
    final valid = attempts.where((a) => a.valid).map((a) => a.value!).toList();
    if (valid.isEmpty) return null;
    valid.sort();
    return test.direction == ProfessionalBetterDirection.higher
        ? valid.last
        : valid.first;
  }
}
