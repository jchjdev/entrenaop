import {Encoder, Profile} from '@garmin/fitsdk';
import type {FileIdMesg, WorkoutMesg, WorkoutStepMesg, ExerciseTitleMesg} from '@garmin/fitsdk';
import {TrainingError} from '../device_training/prescription.ts';
import {strengthPrescription} from '../device_training/strength.ts';
import type {StrengthPrescription} from '../device_training/strength.ts';

export type WorkoutFileIdentity = {serialNumber: number; createdAt: Date; workoutName?: string; productNumber?: number};
const fitEpoch = Date.UTC(1989, 11, 31);
const utf8 = new TextEncoder();
const maxFitTextBytes = 254;

function fitText(value: string): string {
  // La longitud del campo FIT incluye el terminador; nunca cortar una pauta.
  if (utf8.encode(value).length > maxFitTextBytes) throw new TrainingError('unsupported_prescription');
  return value;
}

function workoutNotes(prescription: StrengthPrescription) {
  const notes = prescription.steps.map(step => fitText(step.description));
  let remaining = prescription.description;
  if (utf8.encode(remaining).length <= maxFitTextBytes) return {description: remaining, notes};

  // El campo general no admite más bytes. Conservar la pauta íntegra en notas
  // de pasos existentes, manteniendo sus instrucciones y sin añadir series.
  let part = 1;
  for (const [index, step] of prescription.steps.entries()) {
    if (!remaining) break;
    if (step.kind === 'rest') continue;
    const prefix = `${notes[index]}\nPauta general (${part}): `;
    const capacity = maxFitTextBytes - utf8.encode(prefix).length;
    let bytes = 0;
    let end = 0;
    let wordEnd = 0;
    for (const character of remaining) {
      bytes += utf8.encode(character).length;
      if (bytes > capacity) break;
      end += character.length;
      if (character === ' ') wordEnd = end;
    }
    if (!end) continue;
    if (end < remaining.length && wordEnd > 0) end = wordEnd;
    notes[index] = prefix + remaining.slice(0, end);
    remaining = remaining.slice(end);
    part++;
  }
  if (remaining) throw new TrainingError('unsupported_prescription');
  return {description: 'Antes de empezar, consulta la pauta general numerada en las notas de los primeros ejercicios.', notes};
}

/** Generador sin transporte: el llamador debe aportar una instantánea autorizada. */
export function garminStrengthFit(snapshot: unknown, identity: WorkoutFileIdentity): Uint8Array {
  if (!snapshot || typeof snapshot !== 'object' || (snapshot as {sport?: unknown}).sport !== 'strength') {
    throw new TrainingError('unsupported_prescription');
  }
  const prescription = strengthPrescription(snapshot);
  const productNumber = identity.productNumber ?? 1;
  if (!Number.isInteger(identity.serialNumber) || identity.serialNumber < 1 || identity.serialNumber > 0xfffffffe ||
      !Number.isInteger(productNumber) || productNumber < 1 || productNumber > 0xfffe ||
      !(identity.createdAt instanceof Date) || !Number.isFinite(identity.createdAt.getTime()) ||
      identity.createdAt.getTime() < fitEpoch || identity.createdAt.getTime() >= fitEpoch + 0xffffffff * 1000) {
    throw new TrainingError('invalid_file_identity');
  }

  // El validador de la receta ya comprobó estructura, orden y nombres. La clave
  // usa la posición del ejercicio, no el texto ni una equivalencia de catálogo.
  const validated = snapshot as {blocks: {order_index: number; items: {order_index: number; exercise_name: string}[]}[]};
  const labels = new Map<string, {index: number; name: string}>();
  for (const block of validated.blocks) {
    for (const item of block.items) {
      labels.set(`${block.order_index}:${item.order_index}`, {index: labels.size, name: fitText(item.exercise_name)});
    }
  }
  fitText(prescription.name);
  const workoutName = identity.workoutName ?? prescription.name;
  if (typeof workoutName !== 'string' || !workoutName.trim() || /[\u0000-\u001f]/u.test(workoutName)) {
    throw new TrainingError('unsupported_prescription');
  }
  fitText(workoutName);
  const {description, notes} = workoutNotes(prescription);
  for (const step of prescription.steps) {
    // exerciseWeight es uint16 con escala 100. Rechazar desbordamientos y
    // precisión no representable evita cambiar silenciosamente los kilos.
    if (step.loadKg !== null && (step.loadKg > 655.34 ||
        Math.abs(step.loadKg * 100 - Math.round(step.loadKg * 100)) > 1e-8)) {
      throw new TrainingError('unsupported_prescription');
    }
  }

  const encoder = new Encoder();
  const fileId: FileIdMesg = {
    type: 'workout', manufacturer: 'development', product: productNumber,
    serialNumber: identity.serialNumber, timeCreated: identity.createdAt,
  };
  encoder.onMesg(Profile.MesgNum.FILE_ID, fileId);
  const workout: WorkoutMesg = {
    sport: 'training', subSport: 'strengthTraining',
    numValidSteps: prescription.steps.length, wktName: workoutName,
    ...(description ? {wktDescription: description} : {}),
  };
  encoder.onMesg(Profile.MesgNum.WORKOUT, workout);
  for (const [index, step] of prescription.steps.entries()) {
    const title = labels.get(`${step.block}:${step.item}`)!;
    const message: WorkoutStepMesg = {
      messageIndex: index, wktStepName: step.kind === 'rest' ? 'Descanso' : title.name,
      notes: notes[index], intensity: step.kind === 'rest' ? 'rest' : 'active',
      durationType: step.measure === 'reps' ? 'reps' : 'time',
      // El SDK recibe durationValue crudo: TIME en ms y REPS como entero.
      durationValue: step.measure === 'reps' ? step.value : step.value * 1000,
      targetType: 'open', targetValue: 0,
      ...(step.kind === 'rest' ? {} : {
        exerciseCategory: 'unknown', exerciseName: title.index,
        ...(step.loadKg === null ? {} : {exerciseWeight: step.loadKg, weightDisplayUnit: 'kilogram'}),
      }),
    };
    encoder.onMesg(Profile.MesgNum.WORKOUT_STEP, message);
  }
  // Las referencias coinciden con cada paso; el fēnix procesa esta tabla después
  // de WORKOUT_STEP. UNKNOWN no afirma identidad con ejercicios nativos.
  for (const title of labels.values()) {
    const message: ExerciseTitleMesg = {
      messageIndex: title.index, exerciseCategory: 'unknown',
      exerciseName: title.index, wktStepName: title.name,
    };
    encoder.onMesg(Profile.MesgNum.EXERCISE_TITLE, message);
  }
  return encoder.close();
}
