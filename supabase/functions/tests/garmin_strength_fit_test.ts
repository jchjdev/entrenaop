import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Decoder, Stream} from '@garmin/fitsdk';
import {garminStrengthFit} from '../_shared/garmin/strength_fit.ts';

const identity = {serialNumber: 12345, createdAt: new Date('2026-10-26T10:00:00Z')};
function recipe(): any {
  return {sport: 'strength', name: 'Fuerza · nombres propios', description: 'Técnica y control', source: 'coach', date: '2026-10-26',
    blocks: [{order_index: 0, format: 'straight_sets', rounds: 1, rest_after_seconds: 0, time_cap_seconds: null,
      items: [
        {order_index: 0, exercise_code: null, exercise_name: 'Dominada con pausa', notes: 'Escápulas · RIR 2', sets: [
          {order_index: 0, target_reps: 6, target_load_kg: 7.5, rest_after_seconds: 90},
          {order_index: 1, target_reps: 5, rest_after_seconds: 60}]},
        {order_index: 1, exercise_code: null, exercise_name: 'Front lever isométrico', notes: null,
          sets: [{order_index: 0, target_duration_seconds: 7, rest_after_seconds: 0}]},
      ]}]};
}
function decode(bytes: Uint8Array) {
  const decoder = new Decoder(Stream.fromByteArray(bytes));
  assert.equal(decoder.isFIT(), true); assert.equal(decoder.checkIntegrity(), true);
  const result = decoder.read(); assert.deepEqual(result.errors, []); return result.messages;
}

test('FIT propio conserva títulos UTF-8, referencias, dosis, kilos, notas y todos los descansos', () => {
  const snapshot = recipe(), before = JSON.stringify(snapshot);
  const messages = decode(garminStrengthFit(snapshot, identity));
  assert.equal(JSON.stringify(snapshot), before);
  assert.equal(messages.fileIdMesgs[0].type, 'workout');
  assert.equal(messages.fileIdMesgs[0].serialNumber, identity.serialNumber);
  assert.equal(messages.fileIdMesgs[0].timeCreated.toISOString(), identity.createdAt.toISOString());
  assert.equal(messages.workoutMesgs[0].wktName, snapshot.name);
  assert.equal(messages.workoutMesgs[0].wktDescription, snapshot.description);
  assert.equal(messages.workoutMesgs[0].numValidSteps, 5);
  const steps = messages.workoutStepMesgs, titles = messages.exerciseTitleMesgs;
  assert.equal(titles.length, 2);
  assert.deepEqual(steps.map((s: any) => s.messageIndex), [0, 1, 2, 3, 4]);
  assert.deepEqual(steps.map((s: any) => s.durationType), ['reps', 'time', 'reps', 'time', 'time']);
  assert.deepEqual(steps.map((s: any) => s.durationReps ?? s.durationTime), [6, 90, 5, 60, 7]);
  assert.equal(steps[0].exerciseWeight, 7.5); assert.equal(steps[0].weightDisplayUnit, 'kilogram');
  assert.equal(steps[2].exerciseWeight, undefined);
  assert.equal(steps[0].notes, 'Dominada con pausa · Escápulas · RIR 2');
  for (const i of [0, 2, 4]) {
    const step = steps[i], title = titles.find((t: any) => t.exerciseCategory === step.exerciseCategory && t.exerciseName === step.exerciseName);
    assert.equal(step.intensity, 'active'); assert.equal(step.exerciseCategory, 'unknown');
    assert.equal(title.wktStepName, step.wktStepName);
  }
  for (const i of [1, 3]) {
    assert.equal(steps[i].wktStepName, 'Descanso'); assert.equal(steps[i].intensity, 'rest');
    assert.equal(steps[i].exerciseName, undefined); assert.equal(steps[i].exerciseWeight, undefined);
  }
});

test('una identidad estable genera los mismos bytes, sin añadir la hora de cada reintento', () => {
  assert.deepEqual(garminStrengthFit(recipe(), identity), garminStrengthFit(recipe(), identity));
});

test('ejercicios homónimos siguen teniendo referencias propias y no se inventa catálogo', () => {
  const raw = recipe(); raw.blocks[0].items[1].exercise_name = raw.blocks[0].items[0].exercise_name;
  raw.blocks[0].items[0].exercise_code = 'bench_press_barbell';
  const m = decode(garminStrengthFit(raw, identity));
  assert.notEqual(m.workoutStepMesgs[0].exerciseName, m.workoutStepMesgs[4].exerciseName);
  assert.equal(m.exerciseTitleMesgs.length, 2);
  assert.equal(m.workoutStepMesgs[0].exerciseCategory, 'unknown');
});

test('rechaza recortar notas o nombres por el límite FIT de bytes UTF-8', () => {
  const longNotes = recipe(); longNotes.blocks[0].items[0].notes = 'á'.repeat(130);
  assert.throws(() => garminStrengthFit(longNotes, identity), /unsupported_prescription/);
  const longName = recipe(); longName.blocks[0].items[0].exercise_name = 'é'.repeat(130);
  assert.throws(() => garminStrengthFit(longName, identity), /unsupported_prescription/);
  const longDescription = recipe(); longDescription.description = 'é'.repeat(130);
  assert.throws(() => garminStrengthFit(longDescription, identity), /unsupported_prescription/);
});

test('rechaza formatos no traducidos y recetas sin descansos explícitos', () => {
  for (const edit of [(r: any) => r.sport = 'running', (r: any) => r.blocks[0].format = 'superset',
    (r: any) => delete r.blocks[0].items[0].sets[0].rest_after_seconds,
    (r: any) => r.blocks[0].items[0].sets[0].target_distance_meters = 100]) {
    const raw = recipe(); edit(raw); assert.throws(() => garminStrengthFit(raw, identity));
  }
});

test('peso FIT no se desborda, pierde decimales ni confunde cero con dato ausente', () => {
  for (const weight of [655.35, 1000, 7.555]) {
    const raw = recipe(); raw.blocks[0].items[0].sets[0].target_load_kg = weight;
    assert.throws(() => garminStrengthFit(raw, identity), /unsupported_prescription/);
  }
  for (const weight of [0, 7.55, 655.34]) {
    const raw = recipe(); raw.blocks[0].items[0].sets[0].target_load_kg = weight;
    assert.equal(decode(garminStrengthFit(raw, identity)).workoutStepMesgs[0].exerciseWeight, weight);
  }
});

test('rechaza identidades FIT inválidas antes de generar un archivo sin referencia fiable', () => {
  for (const serialNumber of [0, -1, 1.5, 0xffffffff]) {
    assert.throws(() => garminStrengthFit(recipe(), {...identity, serialNumber}), /invalid_file_identity/);
  }
  for (const createdAt of [new Date(NaN), new Date('1989-01-01Z'), new Date('2200-01-01Z')]) {
    assert.throws(() => garminStrengthFit(recipe(), {...identity, createdAt}), /invalid_file_identity/);
  }
});
