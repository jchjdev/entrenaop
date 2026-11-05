import 'package:entrenaop_admin/features/programs/domain/pull_up_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'la dificultad inicial repetida reduce y un día difícil aislado mantiene',
    () {
      final policy = PullCircuitPolicy()..useGear(PullGear.rows);
      final first = policy.propose(1, 'A');
      policy.record(
        8,
        'A',
        first.dose!,
        PullSignal.difficulty,
        calibration: true,
      );
      expect(policy.propose(2, 'A').dose!.reps, [2, 2]);
      policy.record(
        15,
        'A',
        first.dose!,
        PullSignal.difficulty,
        calibration: true,
      );
      final reduced = policy.propose(3, 'A');
      expect(reduced.decision, PullDecision.reduce);
      expect(reduced.dose!.reps, [1, 2]);
      final minimum = PullDose(
        first.dose!.variant,
        first.dose!.setup,
        [1, 1],
        0,
        widths: first.dose!.widths,
        holdSeconds: 1,
      );
      policy.record(22, 'A', minimum, PullSignal.tolerated);
      policy.record(29, 'A', minimum, PullSignal.difficulty);
      expect(policy.propose(5, 'A').decision, PullDecision.maintain);
      policy.record(36, 'A', minimum, PullSignal.difficulty);
      expect(policy.propose(6, 'A').decision, PullDecision.calibrate);
    },
  );
  test('el circuito separa calibración, días, anchos y segundos', () {
    final policy = PullCircuitPolicy()..useGear(PullGear.bandsAndRows);
    final first = policy.propose(1, 'A');
    expect(first.decision, PullDecision.calibrate);
    expect(first.dose!.reps, [2, 2]);
    expect(first.dose!.holdSeconds, 2);
    policy.record(8, 'A', first.dose!, PullSignal.tolerated);
    policy.record(8, 'A', first.dose!, PullSignal.tolerated);
    expect(policy.propose(2, 'A').decision, PullDecision.maintain);
    expect(policy.propose(2, 'B').decision, PullDecision.calibrate);
    policy.record(12, 'A', first.dose!, PullSignal.tolerated);
    final progress = policy.propose(2, 'A');
    expect(progress.decision, PullDecision.progress);
    expect(progress.dose!.reps, [3, 2]);
    expect(progress.dose!.holdSeconds, 2);
    expect(policy.propose(2, 'A').dose!.signature, progress.dose!.signature);
    policy.record(15, 'A', progress.dose!, PullSignal.unknown);
    expect(policy.propose(3, 'A').decision, PullDecision.maintain);
    policy.record(19, 'A', progress.dose!, PullSignal.difficulty);
    expect(policy.propose(3, 'A').decision, PullDecision.maintain);
    policy.record(22, 'A', progress.dose!, PullSignal.difficulty);
    final reduction = policy.propose(4, 'A');
    expect(reduction.decision, PullDecision.reduce);
    expect(reduction.dose!.reps, [2, 2]);
    expect(reduction.dose!.holdSeconds, 2);
    policy.useGear(PullGear.feet);
    expect(policy.propose(4, 'A').decision, PullDecision.calibrate);
    expect(policy.propose(4, 'B').decision, PullDecision.calibrate);
  });

  test(
    'dos toleradas acercan cada circuito a la receta sin mezclar el hold',
    () {
      final policy = PullCircuitPolicy()..useGear(PullGear.rows);
      for (var week = 1; week <= 40; week++) {
        for (final (lane, day) in [('A', 1), ('B', 5)]) {
          final request = policy.propose(week, lane);
          policy.record(
            week * 7 + day,
            lane,
            request.dose!,
            PullSignal.tolerated,
          );
        }
      }
      final a = policy.propose(41, 'A').dose!;
      final b = policy.propose(41, 'B').dose!;
      expect(a.reps, [5, 5]);
      expect(a.widths, ['normales', 'cerradas']);
      expect(b.reps, [5, 5, 5]);
      expect(b.widths, ['abiertas', 'normales', 'cerradas']);
      expect(a.holdSeconds, 5);
      expect(b.holdSeconds, 5);
      expect(a.signature, isNot(b.signature));
      expect(b.label, contains('5 s de hold cerrado'));
      expect(b.minutes, greaterThanOrEqualTo(a.minutes));
      final changedHold = PullDose(
        a.variant,
        a.setup,
        a.reps,
        a.restSeconds,
        widths: a.widths,
        holdSeconds: 4,
      );
      expect(changedHold.signature, isNot(a.signature));
    },
  );

  test(
    'sin barra baja se conserva la misma progresión con y sin propuesta',
    () {
      for (final gear in [
        PullGear.bands,
        PullGear.machine,
        PullGear.step,
        PullGear.bar,
        PullGear.none,
      ]) {
        final baseline = simulatePullUps(
          startingMark: 5,
          gear: gear,
          calendar: PullCalendar.combined,
          response: PullResponse.favorable,
          weeks: 52,
        );
        final candidate = simulatePullUps(
          startingMark: 5,
          gear: gear,
          calendar: PullCalendar.combined,
          response: PullResponse.favorable,
          weeks: 52,
          approach: PullApproach.australian,
        );
        expect(_primary(candidate), _primary(baseline));
        expect(
          candidate
              .expand((w) => w.sessions)
              .every((s) => s.supportDose == null),
          isTrue,
        );
      }
    },
  );

  test('el apoyo aplazado mantiene su calibración y conserva las sesiones principales', () {
    final baseline = simulatePullUps(
      startingMark: 0,
      gear: PullGear.bandsAndRows,
      calendar: PullCalendar.tight,
      response: PullResponse.favorable,
      weeks: 52,
    );
    final candidate = simulatePullUps(
      startingMark: 0,
      gear: PullGear.bandsAndRows,
      calendar: PullCalendar.tight,
      response: PullResponse.favorable,
      weeks: 52,
      approach: PullApproach.australian,
    );
    expect(_primary(candidate), _primary(baseline));
    expect(candidate.any((w) => w.deferredSupports > 0), isTrue);
    expect(
      candidate
          .expand((w) => w.sessions)
          .any((s) => s.supportReason.contains('aplazadas')),
      isTrue,
    );
    final executed = candidate
        .expand((w) => w.sessions)
        .where((s) => s.supportDose != null)
        .toList();
    expect(executed, isNotEmpty);
    // El apoyo solo cabe en prácticas principales breves, muy separadas entre sí.
    // Los aplazamientos intermedios no acreditan dos días recientes tolerados.
    expect(executed.every((s) => s.supportDose!.widths.length == 2), isTrue);
    expect(executed.first.supportDecision, PullDecision.calibrate);
    expect(
      executed.every((s) => s.supportDose!.reps.join(',') == '2,2'),
      isTrue,
    );
    expect(
      executed.every((s) => s.supportDecision != PullDecision.progress),
      isTrue,
    );
  });

  test('volver tras perder material o parar recalibra también el apoyo', () {
    final trace = simulatePullUps(
      startingMark: 0,
      gear: PullGear.bandsAndRows,
      calendar: PullCalendar.combined,
      response: PullResponse.interrupted,
      weeks: 52,
      approach: PullApproach.australian,
    );
    expect(trace.sublist(12, 15).every((w) => w.sessions.isEmpty), isTrue);
    final returned = trace[15].sessions.single;
    expect(returned.decision, PullDecision.calibrate);
    expect(returned.supportDecision, PullDecision.calibrate);
    expect(returned.supportDose!.reps, [2, 2]);
    expect(trace[30].sessions, isEmpty);
    expect(trace[31].sessions, isEmpty);
    expect(trace[32].sessions.single.supportDecision, PullDecision.calibrate);
  });

  test(
    'solo australianas conserva cero estrictas y llega a las dos recetas',
    () {
      for (final weeks in [26, 52]) {
        final trace = simulatePullUps(
          startingMark: 0,
          gear: PullGear.rows,
          calendar: PullCalendar.combined,
          response: PullResponse.favorable,
          weeks: weeks,
          approach: PullApproach.australian,
        );
        expect(trace.every((w) => w.mark == 0), isTrue);
        final sessions = trace.expand((w) => w.sessions).toList();
        expect(sessions.every((s) => s.dose!.isCircuit), isTrue);
        expect(sessions.any((s) => s.decision == PullDecision.test), isFalse);
        expect(
          sessions.any(
            (s) => s.dose!.reps.join(',') == '5,5' && s.dose!.holdSeconds == 5,
          ),
          isTrue,
        );
        expect(
          sessions.any(
            (s) =>
                s.dose!.reps.join(',') == '5,5,5' && s.dose!.holdSeconds == 5,
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'el brazo actual conserva los recuentos originales a 26 y 52 semanas',
    () {
      const originalGear = [
        PullGear.bands,
        PullGear.machine,
        PullGear.feet,
        PullGear.rows,
        PullGear.step,
        PullGear.bar,
        PullGear.none,
      ];
      for (final weeks in [26, 52]) {
        var sessions = 0;
        var running = 0;
        var controls = 0;
        var deferred = 0;
        for (final mark in <int?>[null, 0, 1, 5, 12, 18, 25]) {
          for (final gear in originalGear) {
            for (final calendar in PullCalendar.values) {
              for (final response in PullResponse.values) {
                final trace = simulatePullUps(
                  startingMark: mark,
                  gear: gear,
                  calendar: calendar,
                  response: response,
                  weeks: weeks,
                );
                for (final week in trace) {
                  sessions += week.sessions.length;
                  running += week.runs.length;
                  controls += week.sessions
                      .where((s) => s.decision == PullDecision.test)
                      .length;
                  deferred += week.unplaced;
                }
              }
            }
          }
        }
        expect(
          [sessions, running, controls, deferred],
          weeks == 26 ? [18908, 20384, 464, 3775] : [38307, 40768, 1008, 7896],
        );
      }
    },
  );
}

List<Object?> _primary(List<PullWeek> trace) => [
  for (final w in trace)
    [
      w.number,
      w.runs,
      w.mark,
      w.unplaced,
      for (final s in w.sessions)
        [s.day, s.dose?.signature, s.decision, s.reason],
    ],
];
