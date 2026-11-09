/** Observación deportiva independiente del fabricante, HTTP y persistencia. */
export type ObservedLap = {
  index: number;
  startedAt: string;
  elapsedSeconds: number;
  timerSeconds: number;
  distanceMeters: number;
  intensity: string | null;
  workoutStepIndex: number | null;
};
export type ObservedRunningActivity = {
  prescriptionReference?: string;
  prescriptionStepIndices?: number[];
  perceivedExertion?: number;
  schemaVersion: 1;
  externalId: string;
  name: string;
  startedAt: string;
  offsetSeconds: number | null;
  elapsedSeconds: number;
  timerSeconds: number;
  distanceMeters: number;
  averageHeartRate: number | null;
  maxHeartRate: number | null;
  laps: ObservedLap[];
};
export class ActivityReturnError extends Error {
  constructor(code: string) { super(code); this.name = 'ActivityReturnError'; }
}
export function validateObservedMetadata(value: Pick<ObservedRunningActivity,'prescriptionReference'|'prescriptionStepIndices'|'perceivedExertion'>):void {
  const indices=value.prescriptionStepIndices,effort=value.perceivedExertion;
  if(indices!==undefined&&(!value.prescriptionReference||!Array.isArray(indices)||indices.length<1||indices.length>100||
    indices.some(index=>!Number.isInteger(index)||index<0||index>10000))||
    effort!==undefined&&(!Number.isFinite(effort)||effort<0||effort>10))throw new ActivityReturnError('invalid_activity');
}
/** El historial actual usa enteros 1–10; no redondear una declaración externa. */
export function recordedActivityRpe(value: Pick<ObservedRunningActivity,'perceivedExertion'>):number|null {
  const rpe=value.perceivedExertion;
  return rpe!==undefined&&Number.isInteger(rpe)&&rpe>=1&&rpe<=10?rpe:null;
}
export function validateRunningObservation(value: ObservedRunningActivity): void {
  validateObservedMetadata(value);
  const positive = (v: number, zero = false) => Number.isFinite(v) && (zero ? v >= 0 : v > 0);
  const timestamp = (v: string) => typeof v === 'string' && Number.isFinite(Date.parse(v)) && v.endsWith('Z');
  if (value.schemaVersion !== 1 || !/^[0-9]{1,24}$/.test(value.externalId) ||
      typeof value.name !== 'string' || value.name.length > 256 || !timestamp(value.startedAt) ||
      !positive(value.elapsedSeconds) || !positive(value.timerSeconds) ||
      value.timerSeconds > value.elapsedSeconds + .01 || value.elapsedSeconds > 172800 ||
      // Cero es una medición válida en una grabación sin desplazamiento; no
      // equivale a distancia ausente ni acredita haber realizado la pauta.
      !positive(value.distanceMeters, true) || value.distanceMeters > 1000000 ||
      value.offsetSeconds !== null && (!Number.isInteger(value.offsetSeconds) || Math.abs(value.offsetSeconds) > 86400) ||
      !Array.isArray(value.laps) || value.laps.length > 2000) throw new ActivityReturnError('invalid_activity');
  for (const hr of [value.averageHeartRate, value.maxHeartRate]) {
    if (hr !== null && (!Number.isFinite(hr) || hr < 30 || hr > 250)) throw new ActivityReturnError('invalid_activity');
  }
  if (value.averageHeartRate !== null && value.maxHeartRate !== null && value.maxHeartRate < value.averageHeartRate) {
    throw new ActivityReturnError('invalid_activity');
  }
  let previousStart = Date.parse(value.startedAt), previousEnd = previousStart, timer = 0, distance = 0;
  for (const [index, lap] of value.laps.entries()) {
    const start = Date.parse(lap.startedAt);
    // Las marcas FIT tienen segundos y las duraciones, milisegundos. Se admite
    // un desfase máximo de 2 s entre fronteras, sin corregir ninguna medición.
    // El orden de inicios y las sumas siguen siendo obligatorios, incluso para
    // vueltas cortas que cabrían enteras dentro de ese margen.
    if (lap.index !== index || !timestamp(lap.startedAt) || start < previousStart || start < previousEnd - 2000 ||
        !positive(lap.elapsedSeconds) || !positive(lap.timerSeconds, true) || lap.timerSeconds > lap.elapsedSeconds + .01 ||
        !positive(lap.distanceMeters, true) || lap.workoutStepIndex !== null &&
          (!Number.isInteger(lap.workoutStepIndex) || lap.workoutStepIndex < 0 || lap.workoutStepIndex > 10000)) {
      throw new ActivityReturnError('invalid_activity');
    }
    previousStart = start; previousEnd = start + lap.elapsedSeconds * 1000;
    timer += lap.timerSeconds; distance += lap.distanceMeters;
  }
  if (previousEnd > Date.parse(value.startedAt) + value.elapsedSeconds * 1000 + 2000 ||
      timer > value.timerSeconds + 2 || distance > value.distanceMeters + 2) throw new ActivityReturnError('invalid_activity');
}

export type ActivityStep = {kind: string; measure: 'seconds' | 'meters' | 'manual'; value: number | null};
/** Identificar un paso no acredita haber cumplido su distancia o intensidad objetivo. */
export function proposeLapMapping(steps: readonly ActivityStep[], laps: readonly ObservedLap[], stepIndices?: readonly number[]): (number[] | null)[] {
  let groups: ObservedLap[][] = laps.map(lap => [lap]);
  if (steps.length !== laps.length) {
    groups = [];
    for (const lap of laps) {
      if (lap.workoutStepIndex === null) return steps.map(() => null);
      const last = groups.at(-1);
      if (last?.[0].workoutStepIndex === lap.workoutStepIndex) last.push(lap);
      else groups.push([lap]);
    }
    // Solo evidencia explícita del índice de paso, nunca proximidad temporal.
    if (groups.length !== steps.length) return steps.map(()=>null);
  }
  // Un índice nativo continuo identifica cada paso aunque se haya terminado
  // antes con Lap. Conservamos todas sus mediciones, también las de Auto Lap.
  // Sin esa evidencia se mantiene la candidatura conservadora por estructura.
  const matchesIndices = (indices: readonly number[]) => indices.length === steps.length &&
    groups.every((group,index) => group.every(lap => lap.workoutStepIndex === indices[index]));
  // El adaptador puede aportar los índices de una receta nativa con bucles.
  // Se exige la secuencia completa; no se deduce un bucle de las mediciones.
  const indexed = matchesIndices(steps.map((_,index)=>index)) ||
    stepIndices !== undefined && matchesIndices(stepIndices);
  if (steps.length !== laps.length && !indexed) return steps.map(()=>null);
  // Si hay índices explícitos contradictorios, la coincidencia de cantidad o
  // duración no autoriza ignorarlos y asociar otras vueltas por posición.
  if(!indexed&&laps.some(lap=>lap.workoutStepIndex!==null))return steps.map(()=>null);
  const compatible = (step: ActivityStep, group: ObservedLap[]) => group.every(lap => {
    const kind = lap.intensity;
    if (kind === null) return false;
    if (step.kind === 'warmup' && kind !== 'warmup') return false;
    if (step.kind === 'cooldown' && kind !== 'cooldown') return false;
    if (['rest', 'walk', 'jog', 'recovery'].includes(step.kind) && !['rest', 'recovery'].includes(kind)) return false;
    if (step.kind === 'run' && !['active', 'interval'].includes(kind)) return false;
    // Una vuelta automática no se convierte en repetición por compartir fecha.
    return true;
  }) && (indexed || step.measure !== 'meters' || Math.abs(group.reduce((sum,lap)=>sum+lap.distanceMeters,0)-step.value!)<=Math.max(5,step.value!*.03));
  return steps.every((step, i) => compatible(step, groups[i])) ? groups.map(group => group.map(lap => lap.index)) : steps.map(() => null);
}

/** Separa una vuelta residual del total sin atribuirla a un paso de la pauta. */
export function proposeRunningActivityMapping(
  steps: readonly ActivityStep[], activity: ObservedRunningActivity, stepIndices?: readonly number[],
  exactPrescription = false,
): {mapping: (number[] | null)[]; postWorkoutLap?: number} {
  const {laps} = activity;
  const mapping = proposeLapMapping(steps, laps, stepIndices);
  const tail = laps.at(-1), previous = laps.at(-2), lastStep = steps.at(-1);
  if (!exactPrescription || !activity.prescriptionStepIndices || !tail || !previous ||
      lastStep?.measure !== 'seconds' || lastStep.value === null || tail.workoutStepIndex !== null ||
      tail.elapsedSeconds > 2 || (tail.intensity !== null && tail.intensity !== previous.intensity)) return {mapping};

  // FIT registra fronteras en segundos. Solo se separa la última vuelta si
  // es contigua, cierra la grabación y el tramo previo agotó su temporizador.
  const end = (lap: ObservedLap) => Date.parse(lap.startedAt) + lap.elapsedSeconds * 1000;
  const prescribed = laps.slice(0, -1);
  if (Math.abs(Date.parse(tail.startedAt) - end(previous)) > 2000 ||
      Math.abs(end(tail) - (Date.parse(activity.startedAt) + activity.elapsedSeconds * 1000)) > 2000 ||
      Math.abs(laps.reduce((sum, lap) => sum + lap.timerSeconds, 0) - activity.timerSeconds) > .01 ||
      prescribed.some(lap => lap.workoutStepIndex === null)) return {mapping};
  const indexed = proposeLapMapping(steps, prescribed, activity.prescriptionStepIndices);
  const finalLaps = indexed.at(-1);
  if (!finalLaps || indexed.some(group => !group?.length) ||
      Math.abs(finalLaps.reduce((sum, index) => sum + laps[index].timerSeconds, 0) - lastStep.value) > .01) return {mapping};
  return {mapping: indexed, postWorkoutLap: tail.index};
}

/** La evidencia conserva decimales; el resultado histórico admite segundos enteros. */
export function historicalSeconds(seconds: number): number {
  if (!Number.isFinite(seconds) || seconds < 0) throw new ActivityReturnError('invalid_activity');
  return Math.round(seconds);
}
