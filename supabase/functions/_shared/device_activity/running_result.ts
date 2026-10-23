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
export function validateRunningObservation(value: ObservedRunningActivity): void {
  const positive = (v: number, zero = false) => Number.isFinite(v) && (zero ? v >= 0 : v > 0);
  const timestamp = (v: string) => typeof v === 'string' && Number.isFinite(Date.parse(v)) && v.endsWith('Z');
  if (value.schemaVersion !== 1 || !/^[0-9]{1,24}$/.test(value.externalId) ||
      typeof value.name !== 'string' || value.name.length > 256 || !timestamp(value.startedAt) ||
      !positive(value.elapsedSeconds) || !positive(value.timerSeconds) ||
      value.timerSeconds > value.elapsedSeconds + .01 || value.elapsedSeconds > 172800 ||
      !positive(value.distanceMeters) || value.distanceMeters > 1000000 ||
      value.offsetSeconds !== null && (!Number.isInteger(value.offsetSeconds) || Math.abs(value.offsetSeconds) > 86400) ||
      !Array.isArray(value.laps) || value.laps.length > 2000) throw new ActivityReturnError('invalid_activity');
  for (const hr of [value.averageHeartRate, value.maxHeartRate]) {
    if (hr !== null && (!Number.isFinite(hr) || hr < 30 || hr > 250)) throw new ActivityReturnError('invalid_activity');
  }
  if (value.averageHeartRate !== null && value.maxHeartRate !== null && value.maxHeartRate < value.averageHeartRate) {
    throw new ActivityReturnError('invalid_activity');
  }
  let previousEnd = Date.parse(value.startedAt), timer = 0, distance = 0;
  for (const [index, lap] of value.laps.entries()) {
    const start = Date.parse(lap.startedAt);
    if (lap.index !== index || !timestamp(lap.startedAt) || start < previousEnd - 1100 ||
        !positive(lap.elapsedSeconds) || !positive(lap.timerSeconds, true) || lap.timerSeconds > lap.elapsedSeconds + .01 ||
        !positive(lap.distanceMeters, true) || lap.workoutStepIndex !== null &&
          (!Number.isInteger(lap.workoutStepIndex) || lap.workoutStepIndex < 0 || lap.workoutStepIndex > 10000)) {
      throw new ActivityReturnError('invalid_activity');
    }
    previousEnd = start + lap.elapsedSeconds * 1000;
    timer += lap.timerSeconds; distance += lap.distanceMeters;
  }
  if (previousEnd > Date.parse(value.startedAt) + value.elapsedSeconds * 1000 + 2000 ||
      timer > value.timerSeconds + 2 || distance > value.distanceMeters + 2) throw new ActivityReturnError('invalid_activity');
}

export type ActivityStep = {kind: string; measure: 'seconds' | 'meters' | 'manual'; value: number | null};
/** Una candidatura por estructura; el titular revisa los emparejamientos antes de confirmar. */
export function proposeLapMapping(steps: readonly ActivityStep[], laps: readonly ObservedLap[]): (number[] | null)[] {
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
    if (groups.length !== steps.length || groups.some((g,i)=>g[0].workoutStepIndex!==i)) return steps.map(()=>null);
  }
  const compatible = (step: ActivityStep, group: ObservedLap[]) => group.every(lap => {
    const kind = lap.intensity;
    if (kind === null) return false;
    if (step.kind === 'warmup' && kind !== 'warmup') return false;
    if (step.kind === 'cooldown' && kind !== 'cooldown') return false;
    if (['rest', 'walk', 'jog', 'recovery'].includes(step.kind) && !['rest', 'recovery'].includes(kind)) return false;
    if (step.kind === 'run' && !['active', 'interval'].includes(kind)) return false;
    // Una vuelta automática no se convierte en repetición por compartir fecha.
    return true;
  }) && (step.measure !== 'meters' || Math.abs(group.reduce((sum,lap)=>sum+lap.distanceMeters,0)-step.value!)<=Math.max(5,step.value!*.03));
  return steps.every((step, i) => compatible(step, groups[i])) ? groups.map(group => group.map(lap => lap.index)) : steps.map(() => null);
}

/** La evidencia conserva decimales; el resultado histórico admite segundos enteros. */
export function historicalSeconds(seconds: number): number {
  if (!Number.isFinite(seconds) || seconds < 0) throw new ActivityReturnError('invalid_activity');
  return Math.round(seconds);
}
