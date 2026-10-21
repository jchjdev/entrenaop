/// Contrato puro propuesto para formularios de seguimiento profesional.
///
/// Estos límites técnicos acotan edición y respuestas; no son cuotas comerciales.
/// Se admiten 40 preguntas, 20 opciones por pregunta, título de 120 caracteres,
/// descripción de 1.000, pregunta de 200, ayuda de 500 y opción de 100.
/// Las respuestas de texto admiten 240 o 2.000 caracteres según su tipo.
/// Los números son finitos, con magnitud máxima de 1.000.000.000; el texto
/// numérico admite hasta seis decimales. No se redondea ni se interpretan miles.
/// Se rechazan escrituras ambiguas como `1,234`/`1.234`; `0,125`, `12,5` y
/// `1,2340` son decimales explícitos. No se admiten exponentes ni agrupaciones.
/// Las escalas usan enteros, por defecto 1..5, con hasta 21 posiciones.
/// Los IDs tienen 1..64 caracteres ASCII alfanuméricos, guion o guion bajo,
/// empiezan por un carácter alfanumérico y no se regeneran al editar etiquetas.
/// Las posiciones de pregunta son únicas y consecutivas desde cero. No se
/// aceptan preguntas u opciones ajenas, duplicadas ni respuestas de otra versión.
/// Texto vacío y `null` significan ausencia; `0` y `false` son respuestas reales.
/// La persistencia debe imponer autorización, inmutabilidad de versiones y los
/// mismos límites. Validar este objeto no concede acceso a ningún alumno.
abstract final class TrainerFollowupLimits {
  static const questions = 40;
  static const options = 20;
  static const titleLength = 120;
  static const descriptionLength = 1000;
  static const promptLength = 200;
  static const helpLength = 500;
  static const optionLabelLength = 100;
  static const shortTextLength = 240;
  static const longTextLength = 2000;
  static const numericMagnitude = 1000000000.0;
  static const decimalPlaces = 6;
  static const scaleSteps = 20;
}

enum TrainerFollowupQuestionType {
  shortText,
  longText,
  number,
  singleChoice,
  multipleChoice,
  scale,
  yesNo,
}

class TrainerFollowupOption {
  const TrainerFollowupOption({required this.id, required this.label});

  final String id, label;
}

class TrainerFollowupQuestion {
  TrainerFollowupQuestion({
    required this.id,
    required this.position,
    required this.prompt,
    required this.type,
    this.required = false,
    this.help,
    Iterable<TrainerFollowupOption> options = const [],
    double? minimum,
    double? maximum,
    this.maximumSelections,
  }) : options = List.unmodifiable(options),
       minimum =
           minimum ?? (type == TrainerFollowupQuestionType.scale ? 1 : null),
       maximum =
           maximum ?? (type == TrainerFollowupQuestionType.scale ? 5 : null);

  /// Identidad estable, conservada al reordenar o revisar el formulario.
  final String id;
  final int position;
  final String prompt;
  final TrainerFollowupQuestionType type;
  final bool required;
  final String? help;

  /// Su orden es el de presentación; sus IDs no dependen de la etiqueta.
  final List<TrainerFollowupOption> options;
  final double? minimum, maximum;
  final int? maximumSelections;
}

class TrainerFollowupFormVersion {
  TrainerFollowupFormVersion({
    required this.formId,
    required this.versionId,
    required this.revision,
    required this.title,
    this.description,
    required Iterable<TrainerFollowupQuestion> questions,
  }) : questions = List.unmodifiable(questions);

  final String formId, versionId, title;
  final int revision;
  final String? description;
  final List<TrainerFollowupQuestion> questions;
}

class TrainerFollowupSubmission {
  TrainerFollowupSubmission._(this.versionId, Map<String, Object> answers)
    : answers = Map.unmodifiable(answers);

  /// La respuesta corresponde a esta versión, nunca a «la última» del formulario.
  final String versionId;

  /// Las respuestas opcionales ausentes no generan una entrada. Cero y falso sí.
  /// Las selecciones múltiples se conservan en el orden de las opciones.
  final Map<String, Object> answers;
}

abstract final class TrainerFollowupValidator {
  static final _id = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');
  static final _decimal = RegExp(r'^[+-]?(?:\d+(?:[.,]\d+)?|[.,]\d+)$');

  static TrainerFollowupFormVersion normalizeForm(
    TrainerFollowupFormVersion form,
  ) {
    _validId(form.formId, 'formulario');
    _validId(form.versionId, 'versión');
    if (form.revision < 1 || form.revision > 2147483647) {
      throw const FormatException('La revisión debe ser un entero positivo.');
    }
    final title = _text(
      form.title,
      TrainerFollowupLimits.titleLength,
      'título',
    );
    final description = _optionalText(
      form.description,
      TrainerFollowupLimits.descriptionLength,
      'descripción',
    );
    if (form.questions.isEmpty ||
        form.questions.length > TrainerFollowupLimits.questions) {
      throw const FormatException(
        'El formulario admite entre 1 y 40 preguntas.',
      );
    }
    final ids = <String>{};
    final positions = <int>{};
    final questions = <TrainerFollowupQuestion>[];
    for (final question in form.questions) {
      _validId(question.id, 'pregunta');
      if (!ids.add(question.id) ||
          !positions.add(question.position) ||
          question.position < 0 ||
          question.position >= form.questions.length) {
        throw const FormatException(
          'Las preguntas deben tener identidades únicas y posiciones consecutivas desde cero.',
        );
      }
      final options = _options(question);
      final numeric = question.type == TrainerFollowupQuestionType.number;
      final scale = question.type == TrainerFollowupQuestionType.scale;
      if (!numeric &&
          !scale &&
          (question.minimum != null || question.maximum != null)) {
        throw const FormatException(
          'Este tipo de pregunta no admite límites numéricos.',
        );
      }
      final minimum = question.minimum;
      final maximum = question.maximum;
      if (minimum != null) _finite(minimum);
      if (maximum != null) _finite(maximum);
      if (minimum != null && maximum != null && minimum > maximum) {
        throw const FormatException('El mínimo no puede superar el máximo.');
      }
      if (scale &&
          (minimum == null ||
              maximum == null ||
              minimum != minimum.truncateToDouble() ||
              maximum != maximum.truncateToDouble() ||
              maximum <= minimum ||
              maximum - minimum > TrainerFollowupLimits.scaleSteps)) {
        throw const FormatException(
          'La escala requiere límites enteros distintos y hasta 21 posiciones.',
        );
      }
      questions.add(
        TrainerFollowupQuestion(
          id: question.id,
          position: question.position,
          prompt: _text(
            question.prompt,
            TrainerFollowupLimits.promptLength,
            'pregunta',
          ),
          type: question.type,
          required: question.required,
          help: _optionalText(
            question.help,
            TrainerFollowupLimits.helpLength,
            'ayuda',
          ),
          options: options,
          minimum: minimum,
          maximum: maximum,
          maximumSelections: question.maximumSelections,
        ),
      );
    }
    questions.sort((a, b) => a.position.compareTo(b.position));
    return TrainerFollowupFormVersion(
      formId: form.formId,
      versionId: form.versionId,
      revision: form.revision,
      title: title,
      description: description,
      questions: questions,
    );
  }

  static List<TrainerFollowupOption> _options(
    TrainerFollowupQuestion question,
  ) {
    final choice =
        question.type == TrainerFollowupQuestionType.singleChoice ||
        question.type == TrainerFollowupQuestionType.multipleChoice;
    if (!choice && question.options.isNotEmpty) {
      throw const FormatException('Este tipo de pregunta no admite opciones.');
    }
    if (choice &&
        (question.options.length < 2 ||
            question.options.length > TrainerFollowupLimits.options)) {
      throw const FormatException(
        'Las preguntas de selección admiten entre 2 y 20 opciones.',
      );
    }
    final max = question.maximumSelections;
    if (max != null &&
        (question.type != TrainerFollowupQuestionType.multipleChoice ||
            max < 1 ||
            max > question.options.length)) {
      throw const FormatException('El máximo de selecciones no es válido.');
    }
    final ids = <String>{};
    return question.options
        .map((option) {
          _validId(option.id, 'opción');
          if (!ids.add(option.id)) {
            throw const FormatException(
              'Las opciones deben tener identidades únicas.',
            );
          }
          return TrainerFollowupOption(
            id: option.id,
            label: _text(
              option.label,
              TrainerFollowupLimits.optionLabelLength,
              'opción',
            ),
          );
        })
        .toList(growable: false);
  }

  static TrainerFollowupSubmission normalizeSubmission({
    required TrainerFollowupFormVersion form,
    required String versionId,
    required Map<String, Object?> answers,
  }) {
    final normalized = normalizeForm(form);
    if (versionId != normalized.versionId) {
      throw const FormatException(
        'La respuesta no corresponde a la versión asignada.',
      );
    }
    final ids = normalized.questions.map((q) => q.id).toSet();
    if (answers.keys.any((key) => !ids.contains(key))) {
      throw const FormatException(
        'La respuesta contiene preguntas ajenas al formulario.',
      );
    }
    final values = <String, Object>{};
    for (final question in normalized.questions) {
      final value = _answer(question, answers[question.id]);
      if (value == null) {
        if (question.required) {
          throw FormatException('Responde la pregunta «${question.prompt}».');
        }
      } else {
        values[question.id] = value;
      }
    }
    return TrainerFollowupSubmission._(versionId, values);
  }

  static Object? _answer(TrainerFollowupQuestion question, Object? raw) {
    if (raw == null) return null;
    switch (question.type) {
      case TrainerFollowupQuestionType.shortText:
      case TrainerFollowupQuestionType.longText:
        if (raw is! String) {
          throw const FormatException('Se esperaba una respuesta de texto.');
        }
        return _optionalText(
          raw,
          question.type == TrainerFollowupQuestionType.shortText
              ? TrainerFollowupLimits.shortTextLength
              : TrainerFollowupLimits.longTextLength,
          'respuesta',
        );
      case TrainerFollowupQuestionType.number:
      case TrainerFollowupQuestionType.scale:
        if (raw is String && raw.trim().isEmpty) return null;
        final value = normalizeNumber(raw);
        if ((question.minimum != null && value < question.minimum!) ||
            (question.maximum != null && value > question.maximum!)) {
          throw const FormatException(
            'El valor está fuera del intervalo permitido.',
          );
        }
        if (question.type == TrainerFollowupQuestionType.scale) {
          if (value != value.truncateToDouble()) {
            throw const FormatException('La escala requiere un valor entero.');
          }
          return value.toInt();
        }
        return value;
      case TrainerFollowupQuestionType.yesNo:
        if (raw is! bool) {
          throw const FormatException('La respuesta debe ser sí o no.');
        }
        return raw;
      case TrainerFollowupQuestionType.singleChoice:
        if (raw is! String) {
          throw const FormatException('Selecciona una sola opción.');
        }
        if (raw.isEmpty) return null;
        if (!question.options.any((option) => option.id == raw)) {
          throw const FormatException(
            'La opción no pertenece a esta pregunta.',
          );
        }
        return raw;
      case TrainerFollowupQuestionType.multipleChoice:
        if (raw is! List || raw.any((value) => value is! String)) {
          throw const FormatException('Se esperaba una lista de opciones.');
        }
        final selected = raw.cast<String>().toSet();
        if (selected.length != raw.length ||
            selected.length >
                (question.maximumSelections ?? question.options.length) ||
            selected.any(
              (id) => !question.options.any((option) => option.id == id),
            )) {
          throw const FormatException(
            'Las opciones son ajenas, repetidas o superan el máximo.',
          );
        }
        if (selected.isEmpty) return null;
        return List<String>.unmodifiable(
          question.options
              .where((option) => selected.contains(option.id))
              .map((option) => option.id),
        );
    }
  }

  /// Convierte un número o decimal textual inequívoco sin agrupar ni redondear.
  /// Sirve también para editar los límites de una pregunta con el mismo criterio.
  static double normalizeNumber(Object raw) {
    final double value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      final text = raw.trim();
      if (text.length > 32 || !_decimal.hasMatch(text)) {
        throw const FormatException(
          'Escribe un decimal sin separadores de miles.',
        );
      }
      final parts = text.split(RegExp('[.,]'));
      if (parts.length == 2 &&
          parts.last.length > TrainerFollowupLimits.decimalPlaces) {
        throw const FormatException(
          'Se admiten hasta seis decimales, sin redondeo automático.',
        );
      }
      // «1,234» y «1.234» pueden significar miles o decimales según el país.
      // Se exige una escritura inequívoca; nunca se eliminan separadores.
      final integerPart = parts.first.replaceFirst(RegExp(r'^[+-]'), '');
      if (parts.length == 2 &&
          parts.last.length == 3 &&
          integerPart.isNotEmpty &&
          integerPart.length <= 3 &&
          int.parse(integerPart) != 0) {
        throw const FormatException(
          'El separador es ambiguo: confirma el valor sin agrupar miles o con otro decimal explícito.',
        );
      }
      value = double.parse(text.replaceAll(',', '.'));
    } else {
      throw const FormatException('Se esperaba un número.');
    }
    _finite(value);
    return value;
  }

  static void _finite(double value) {
    if (!value.isFinite ||
        value.abs() > TrainerFollowupLimits.numericMagnitude) {
      throw const FormatException(
        'El número debe ser finito y no superar mil millones en valor absoluto.',
      );
    }
  }

  static void _validId(String value, String name) {
    if (!_id.hasMatch(value)) {
      throw FormatException('Identidad de $name no válida.');
    }
  }

  static String _text(String value, int maximum, String field) {
    final normalized = _optionalText(value, maximum, field);
    if (normalized == null) throw FormatException('Completa el campo $field.');
    return normalized;
  }

  static String? _optionalText(String? value, int maximum, String field) {
    final normalized = value
        ?.replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.length > maximum ||
        normalized.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'))) {
      throw FormatException(
        'El campo $field contiene texto no válido o supera $maximum caracteres.',
      );
    }
    return normalized;
  }
}
