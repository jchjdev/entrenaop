import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_assessment_codec.dart';

ProfessionalAssessmentTest protocol({
  ProfessionalMarkUnit unit = ProfessionalMarkUnit.seconds,
  double resolution = 0.01,
  int maximumAttempts = 2,
  ProfessionalRetryPolicy retry = ProfessionalRetryPolicy.invalidOnly,
}) => ProfessionalAssessmentTest(
  id: 'run',
  name: 'Control privado',
  unit: unit,
  direction: ProfessionalBetterDirection.lower,
  resolution: resolution,
  instructions: 'Realiza el recorrido definido y registra la marca.',
  maximumAttempts: maximumAttempts,
  retryPolicy: retry,
);
ProfessionalAssessmentVersion battery(ProfessionalAssessmentTest test) =>
    ProfessionalAssessmentVersion(
      id: 'version',
      familyId: 'family',
      version: 1,
      title: 'Simulacro',
      tests: [test],
    );

void main() {
  ProfessionalAssessmentDelivery result({
    required String id,
    required String completed,
    String client = 'client',
    String trainer = 'trainer',
    String hash = 'hash',
    double? mark = 10,
  }) => ProfessionalAssessmentCodec.delivery({
    'id': id,
    'client_id': client,
    'relation_id': 'relation',
    'trainer_id': trainer,
    'trainer_name': 'Preparador',
    'client_name': 'Alumno',
    'status': 'completed',
    'revision': 2,
    'scheduled_date': '2026-10-21',
    'created_at': '2026-10-20T12:00:00Z',
    'started_at': completed,
    'completed_at': completed,
    'can_start': false,
    'can_edit': false,
    'answers': {
      'run': [
        if (mark != null) {'valid': true, 'value': mark} else {'valid': false},
      ],
    },
    'battery': {
      'id': 'battery',
      'family_id': 'family',
      'version': 1,
      'content': {
        'title': 'Pruebas',
        'tests': [
          {
            'id': 'run',
            'name': 'Recorrido',
            'source': 'custom',
            'unit': 'seconds',
            'direction': 'lower',
            'resolution': 0.01,
            'instructions': 'Recorre el trazado definido.',
            'max_attempts': 1,
            'retry_policy': 'none',
            'protocol_fingerprint': hash,
          },
        ],
      },
    },
  });
  test(
    'comparación exige mismo servicio, protocolo y orden temporal estricto',
    () {
      final old = result(
        id: 'old',
        completed: '2026-10-20T12:00:00Z',
        mark: 12,
      );
      final current = result(
        id: 'new',
        completed: '2026-10-21T12:00:00Z',
        mark: 10,
      );
      final change = compareProfessionalAssessments(old, current).single;
      expect(change.favorableDifference, 2);
      expect(change.test.unit, ProfessionalMarkUnit.seconds);
      for (final invalid in [
        result(id: 'new', completed: '2026-10-20T12:00:00Z'),
        result(id: 'new', completed: '2026-10-21T12:00:00Z', hash: 'changed'),
        result(id: 'new', completed: '2026-10-21T12:00:00Z', client: 'another'),
        result(
          id: 'new',
          completed: '2026-10-21T12:00:00Z',
          trainer: 'another',
        ),
        result(id: 'new', completed: '2026-10-21T12:00:00Z', mark: null),
      ]) {
        expect(compareProfessionalAssessments(old, invalid), isEmpty);
      }
    },
  );
  test(
    'evento tipado conserva fecha civil y cursor compuesto sin fingir sesión',
    () {
      final event = ProfessionalAssessmentCodec.event({
        'kind': 'assessment',
        'id': 'delivery',
        'date': '2026-10-25',
        'status': 'planned',
        'revision': 0,
        'title': 'Simulacro',
        'client_id': 'client',
        'relation_id': 'relation',
        'person_name': 'Alumno',
      });
      expect(event.kind, 'assessment');
      expect(event.date, DateTime(2026, 10, 25));
      expect(event.cursorParameters, {
        'p_before_date': '2026-10-25',
        'p_before_id': 'delivery',
      });
      expect(ProfessionalAssessmentEvent.pageSize, 200);
      expect(
        () => ProfessionalAssessmentCodec.event({'kind': 'workout'}),
        throwsFormatException,
      );
    },
  );
  test('segundos reutilizan parser y mantienen precisión sin redondear', () {
    expect(
      ProfessionalAssessmentValidator.parseMark('1:30,25', protocol()),
      90.25,
    );
    expect(
      ProfessionalAssessmentValidator.parseMark('13,27', protocol()),
      13.27,
    );
    expect(
      () => ProfessionalAssessmentValidator.parseMark('13,271', protocol()),
      throwsFormatException,
    );
    expect(ProfessionalAssessmentValidator.parseMark('0', protocol()), 0);
    expect(
      () => ProfessionalAssessmentValidator.parseMark('', protocol()),
      throwsFormatException,
    );
  });
  test(
    'resolución decimal exacta no usa tolerancias ni inventa repeticiones',
    () {
      expect(
        ProfessionalAssessmentValidator.parseMark(
          '0,3',
          protocol(resolution: 0.1),
        ),
        0.3,
      );
      expect(
        () => ProfessionalAssessmentValidator.parseMark(
          '0,3000000001',
          protocol(resolution: 0.1),
        ),
        throwsFormatException,
      );
      expect(
        () => ProfessionalAssessmentValidator.parseMark(
          '2,5',
          protocol(unit: ProfessionalMarkUnit.repetitions, resolution: 1),
        ),
        throwsFormatException,
      );
      for (final value in ['NaN', 'Infinity', '-1', '1000000001']) {
        expect(
          () => ProfessionalAssessmentValidator.parseMark(value, protocol()),
          throwsFormatException,
        );
      }
    },
  );
  test('nulo no equivale a cero y no lleva marca', () {
    final f = battery(protocol());
    expect(
      ProfessionalAssessmentValidator.answers(f, {
        'run': [const ProfessionalAssessmentAttempt(valid: false)],
      }, complete: true)['run']!.single.value,
      isNull,
    );
    expect(
      ProfessionalAssessmentValidator.answers(f, {
        'run': [const ProfessionalAssessmentAttempt(valid: true, value: 0)],
      }, complete: true)['run']!.single.value,
      0,
    );
    expect(
      () => ProfessionalAssessmentValidator.answers(f, {
        'run': [const ProfessionalAssessmentAttempt(valid: false, value: 0)],
      }, complete: true),
      throwsFormatException,
    );
  });
  test('solo repetir tras nulo impide un segundo intento tras válido', () {
    final f = battery(protocol());
    expect(
      ProfessionalAssessmentValidator.answers(f, {
        'run': [
          const ProfessionalAssessmentAttempt(valid: false),
          const ProfessionalAssessmentAttempt(valid: true, value: 10),
        ],
      }, complete: true)['run'],
      hasLength(2),
    );
    expect(
      () => ProfessionalAssessmentValidator.answers(f, {
        'run': [
          const ProfessionalAssessmentAttempt(valid: true, value: 10),
          const ProfessionalAssessmentAttempt(valid: false),
        ],
      }, complete: true),
      throwsFormatException,
    );
  });
  test('repetición libre conserva intentos y elige mejor sin puntuar', () {
    final t = protocol(retry: ProfessionalRetryPolicy.always);
    const values = [
      ProfessionalAssessmentAttempt(valid: true, value: 20),
      ProfessionalAssessmentAttempt(valid: true, value: 18),
    ];
    expect(
      ProfessionalAssessmentValidator.answers(battery(t), {
        'run': values,
      }, complete: true)['run'],
      values,
    );
    expect(ProfessionalAssessmentValidator.best(t, values), 18);
    expect(
      ProfessionalAssessmentValidator.best(t, [
        const ProfessionalAssessmentAttempt(valid: false),
      ]),
      isNull,
    );
  });
  test('borrador parcial no cierra una batería incompleta y rechaza pruebas ajenas', () {
    final f = battery(protocol());
    expect(
      ProfessionalAssessmentValidator.answers(f, {}, complete: false),
      isEmpty,
    );
    expect(
      () => ProfessionalAssessmentValidator.answers(f, {}, complete: true),
      throwsFormatException,
    );
    expect(
      () => ProfessionalAssessmentValidator.answers(f, {
        'other': [],
      }, complete: false),
      throwsFormatException,
    );
    expect(
      () => ProfessionalAssessmentValidator.normalize(
        battery(protocol(maximumAttempts: 11)),
      ),
      throwsFormatException,
    );
  });
  test('codec no envía huella, versión o definición oficial fabricadas por cliente', () {
    final official = ProfessionalAssessmentTest(
      id: 'run',
      name: 'Oficial',
      unit: ProfessionalMarkUnit.seconds,
      direction: ProfessionalBetterDirection.lower,
      resolution: 0.01,
      instructions: 'Protocolo completo publicado.',
      maximumAttempts: 1,
      retryPolicy: ProfessionalRetryPolicy.none,
      source: ProfessionalProtocolSource.official,
      officialTestId: 'official-id',
      protocolFingerprint: 'forged',
      definitionVersion: 99,
    );
    final payload = ProfessionalAssessmentCodec.encode(battery(official));
    expect((payload['tests'] as List).single, {
      'id': 'run',
      'source': 'official',
      'official_test_id': 'official-id',
    });
  });
}
