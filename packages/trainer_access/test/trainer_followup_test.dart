import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_followup.dart';

TrainerFollowupQuestion question({
  String id = 'question-1',
  int position = 0,
  TrainerFollowupQuestionType type = TrainerFollowupQuestionType.number,
  bool required = false,
  String prompt = ' ¿Cómo ha ido? ',
  Iterable<TrainerFollowupOption> options = const [],
  double? minimum,
  double? maximum,
  int? maximumSelections,
}) => TrainerFollowupQuestion(
  id: id,
  position: position,
  prompt: prompt,
  type: type,
  required: required,
  options: options,
  minimum: minimum,
  maximum: maximum,
  maximumSelections: maximumSelections,
);

TrainerFollowupFormVersion form(
  Iterable<TrainerFollowupQuestion> questions, {
  String versionId = 'version-1',
}) => TrainerFollowupFormVersion(
  formId: 'form-1',
  versionId: versionId,
  revision: 1,
  title: ' Revisión semanal ',
  description: ' Primera línea\r\nSegunda línea ',
  questions: questions,
);

TrainerFollowupSubmission answer(TrainerFollowupQuestion q, Object? value) =>
    TrainerFollowupValidator.normalizeSubmission(
      form: form([q]),
      versionId: 'version-1',
      answers: {q.id: value},
    );

const options = [
  TrainerFollowupOption(id: 'morning', label: ' Mañana '),
  TrainerFollowupOption(id: 'evening', label: 'Tarde'),
  TrainerFollowupOption(id: 'night', label: 'Noche'),
];

void main() {
  group('versiones y orden', () {
    test('normaliza texto, conserva IDs y ordena por posición explícita', () {
      final source = [
        question(id: 'second', position: 1),
        question(id: 'first'),
      ];
      final normalized = TrainerFollowupValidator.normalizeForm(form(source));
      source.clear();
      expect(normalized.title, 'Revisión semanal');
      expect(normalized.description, 'Primera línea\nSegunda línea');
      expect(normalized.questions.map((q) => q.id), ['first', 'second']);
      expect(normalized.questions.first.prompt, '¿Cómo ha ido?');
      expect(() => normalized.questions.clear(), throwsUnsupportedError);
    });

    test('rechaza IDs repetidos, posiciones repetidas o huecos', () {
      for (final questions in [
        [question(), question(position: 1)],
        [question(), question(id: 'other')],
        [question(position: 1)],
        [question(id: 'invalid id')],
      ]) {
        expect(
          () => TrainerFollowupValidator.normalizeForm(form(questions)),
          throwsFormatException,
        );
      }
    });

    test('una respuesta antigua no se aplica a la versión nueva', () {
      final assigned = form([question()]);
      final edited = form([question()], versionId: 'version-2');
      expect(
        () => TrainerFollowupValidator.normalizeSubmission(
          form: edited,
          versionId: assigned.versionId,
          answers: {'question-1': 4},
        ),
        throwsFormatException,
      );
      expect(
        TrainerFollowupValidator.normalizeSubmission(
          form: assigned,
          versionId: assigned.versionId,
          answers: {'question-1': 4},
        ).answers['question-1'],
        4,
      );
    });

    test('impone número finito de preguntas y longitudes', () {
      expect(
        () => TrainerFollowupValidator.normalizeForm(form([])),
        throwsFormatException,
      );
      final forty = List.generate(40, (i) => question(id: 'q$i', position: i));
      expect(
        TrainerFollowupValidator.normalizeForm(form(forty)).questions,
        hasLength(40),
      );
      expect(
        () => TrainerFollowupValidator.normalizeForm(
          form([...forty, question(id: 'extra', position: 40)]),
        ),
        throwsFormatException,
      );
      expect(
        () => TrainerFollowupValidator.normalizeForm(
          form([question(prompt: 'x' * 201)]),
        ),
        throwsFormatException,
      );
    });
  });

  group('ausente y respuestas numéricas', () {
    test('cero y falso satisfacen preguntas obligatorias', () {
      final submission = TrainerFollowupValidator.normalizeSubmission(
        form: form([
          question(required: true),
          question(
            id: 'yes-no',
            position: 1,
            type: TrainerFollowupQuestionType.yesNo,
            required: true,
          ),
          question(id: 'optional', position: 2),
        ]),
        versionId: 'version-1',
        answers: {'question-1': 0, 'yes-no': false},
      );
      expect(submission.answers, {'question-1': 0.0, 'yes-no': false});
      expect(submission.answers.containsKey('optional'), isFalse);
      expect(
        () => submission.answers['question-1'] = 2,
        throwsUnsupportedError,
      );
      expect(
        () => answer(question(required: true), null),
        throwsFormatException,
      );
      expect(
        () => answer(question(required: true), '  '),
        throwsFormatException,
      );
    });

    test(
      'acepta coma o punto inequívocos sin eliminar cifras ni redondear',
      () {
        for (final text in [' 12,50 ', '12.50']) {
          expect(answer(question(), text).answers['question-1'], 12.5);
        }
        expect(answer(question(), '0,125').answers['question-1'], 0.125);
        expect(answer(question(), '-,25').answers['question-1'], -0.25);
        expect(answer(question(), '1234,567').answers['question-1'], 1234.567);
        expect(answer(question(), '1,2340').answers['question-1'], 1.234);
        expect(answer(question(), '0,123456').answers['question-1'], 0.123456);
      },
    );

    test('rechaza miles ambiguos, formatos agrupados y valores no finitos', () {
      for (final raw in <Object>[
        '1,234',
        '1.234',
        '1.234,5',
        '1,234.5',
        '1 234,5',
        '1e3',
        'NaN',
        'Infinity',
        '0,1234567',
        true,
        double.nan,
        double.infinity,
        -double.infinity,
        1000000001,
        '1000000001',
      ]) {
        expect(
          () => answer(question(), raw),
          throwsFormatException,
          reason: '$raw',
        );
      }
    });

    test('valida intervalos inclusivos y configuración finita', () {
      final bounded = question(minimum: 0, maximum: 10);
      expect(answer(bounded, 0).answers['question-1'], 0);
      expect(answer(bounded, 10).answers['question-1'], 10);
      expect(() => answer(bounded, -0.1), throwsFormatException);
      expect(() => answer(bounded, 10.1), throwsFormatException);
      for (final q in [
        question(minimum: 5, maximum: 4),
        question(minimum: double.nan),
        question(maximum: double.infinity),
        question(type: TrainerFollowupQuestionType.yesNo, minimum: 0),
      ]) {
        expect(
          () => TrainerFollowupValidator.normalizeForm(form([q])),
          throwsFormatException,
        );
      }
    });

    test(
      'escala usa 1..5 por defecto y exige enteros dentro del intervalo',
      () {
        final q = question(type: TrainerFollowupQuestionType.scale);
        expect(q.minimum, 1);
        expect(q.maximum, 5);
        expect(answer(q, '3').answers['question-1'], isA<int>());
        expect(() => answer(q, 0), throwsFormatException);
        expect(() => answer(q, 2.5), throwsFormatException);
        for (final q in [
          question(type: TrainerFollowupQuestionType.scale, minimum: 1.5),
          question(
            type: TrainerFollowupQuestionType.scale,
            minimum: 0,
            maximum: 21,
          ),
          question(
            type: TrainerFollowupQuestionType.scale,
            minimum: 5,
            maximum: 5,
          ),
        ]) {
          expect(
            () => TrainerFollowupValidator.normalizeForm(form([q])),
            throwsFormatException,
          );
        }
      },
    );

    test('sí-no no acepta cadenas ni valores de verdad implícitos', () {
      final q = question(type: TrainerFollowupQuestionType.yesNo);
      for (final raw in <Object>['sí', 'true', 1, 0]) {
        expect(() => answer(q, raw), throwsFormatException);
      }
    });
  });

  group('selecciones y texto', () {
    test(
      'opción única usa IDs, no etiquetas ni opciones de otro formulario',
      () {
        final q = question(
          type: TrainerFollowupQuestionType.singleChoice,
          options: options,
        );
        expect(answer(q, 'morning').answers['question-1'], 'morning');
        for (final raw in <Object>[
          'Mañana',
          'other',
          ['morning'],
        ]) {
          expect(() => answer(q, raw), throwsFormatException);
        }
      },
    );

    test('selección múltiple es finita, única, ordenada e inmutable', () {
      final q = question(
        type: TrainerFollowupQuestionType.multipleChoice,
        options: options,
        maximumSelections: 2,
      );
      final source = ['night', 'morning'];
      final result = answer(q, source);
      source.clear();
      expect(result.answers['question-1'], ['morning', 'night']);
      expect(
        () => (result.answers['question-1'] as List).clear(),
        throwsUnsupportedError,
      );
      for (final raw in <Object>[
        ['night', 'night'],
        ['morning', 'evening', 'night'],
        ['other'],
        [1],
        'morning',
      ]) {
        expect(() => answer(q, raw), throwsFormatException);
      }
      expect(answer(q, []).answers, isEmpty);
      expect(
        () => answer(
          question(type: q.type, options: options, required: true),
          [],
        ),
        throwsFormatException,
      );
    });

    test('no permite opciones duplicadas ni configuración de otro tipo', () {
      for (final q in [
        question(type: TrainerFollowupQuestionType.singleChoice),
        question(
          type: TrainerFollowupQuestionType.singleChoice,
          options: [options.first, options.first],
        ),
        question(options: options),
        question(maximumSelections: 1),
        question(
          type: TrainerFollowupQuestionType.multipleChoice,
          options: options,
          maximumSelections: 4,
        ),
        question(
          type: TrainerFollowupQuestionType.singleChoice,
          options: List.generate(
            21,
            (i) => TrainerFollowupOption(id: 'o$i', label: 'Opción $i'),
          ),
        ),
      ]) {
        expect(
          () => TrainerFollowupValidator.normalizeForm(form([q])),
          throwsFormatException,
        );
      }
    });

    test(
      'texto recorta bordes, conserva líneas y diferencia blanco de respuesta',
      () {
        final short = question(type: TrainerFollowupQuestionType.shortText);
        final long = question(type: TrainerFollowupQuestionType.longText);
        expect(
          answer(short, '  Bien\r\nGracias  ').answers['question-1'],
          'Bien\nGracias',
        );
        expect(answer(short, ' \n ').answers, isEmpty);
        expect(answer(short, 'x' * 240).answers['question-1'], hasLength(240));
        expect(() => answer(short, 'x' * 241), throwsFormatException);
        expect(answer(long, 'x' * 2000).answers['question-1'], hasLength(2000));
        expect(() => answer(long, 'x' * 2001), throwsFormatException);
        expect(() => answer(short, 'Texto\u0000oculto'), throwsFormatException);
        expect(() => answer(short, 0), throwsFormatException);
      },
    );

    test(
      'rechaza preguntas no asignadas aunque tengan una respuesta vacía',
      () {
        expect(
          () => TrainerFollowupValidator.normalizeSubmission(
            form: form([question()]),
            versionId: 'version-1',
            answers: {'question-1': 4, 'other': null},
          ),
          throwsFormatException,
        );
      },
    );
  });
}
