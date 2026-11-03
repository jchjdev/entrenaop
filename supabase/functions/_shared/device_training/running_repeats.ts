import {TrainingError} from './training_error.ts';
import type {RunningStep, RunningPrescription} from './prescription.ts';

// Índices sobre la secuencia expandida, que sigue siendo la referencia para
// medir y asociar resultados. Agrupar nunca cambia una dosis ni su revisión.
export type RunningRepeatBlock = {
  start: number; stepCount: number; iterations: number; omitLastRecovery: boolean;
};
const soft = (step: RunningStep) => ['rest','recovery','walk','jog'].includes(step.kind);
const comparable = (step: RunningStep) => JSON.stringify([
  step.kind, step.measure, step.value, step.description, step.pace?.fast ?? null, step.pace?.slow ?? null,
]);
const eligible = (steps: readonly RunningStep[]) =>
  !steps.some(s=>s.kind==='warmup'||s.kind==='cooldown') && steps.some(s=>s.kind==='run');

/** Compresión exacta y acotada dentro de cada elemento de la receta original. */
export function findRunningRepeats(steps: readonly RunningStep[], ranges: readonly [number,number][]): RunningRepeatBlock[] {
  const result: RunningRepeatBlock[] = [];
  const keys = steps.map(comparable);
  for (const [start,end] of ranges) {
    let cursor = start;
    while (cursor < end) {
      let best: RunningRepeatBlock | undefined;
      let bestSaved = 0;
      for (let length=1; length<=Math.ceil((end-cursor)/2); length++) {
        const pattern=steps.slice(cursor,cursor+length);
        if (!eligible(pattern)) continue;
        let iterations=1;
        while(cursor+(iterations+1)*length<=end &&
          keys.slice(cursor+iterations*length,cursor+(iterations+1)*length)
            .every((key,index)=>key===keys[cursor+index])) iterations++;
        const next=cursor+iterations*length;
        const omit=length>1 && soft(pattern.at(-1)!) && next+length-1<=end &&
          keys.slice(next,next+length-1).every((key,index)=>key===keys[cursor+index]);
        if(omit) iterations++;
        const covered=iterations*length-(omit?1:0);
        const saved=covered-length;
        if(iterations>=2 && saved>bestSaved) {
          best={start:cursor,stepCount:length,iterations,omitLastRecovery:omit};
          bestSaved=saved;
        }
      }
      if(best) {
        result.push(best);
        cursor+=best.stepCount*best.iterations-(best.omitLastRecovery?1:0);
      } else cursor++;
    }
  }
  return result;
}

/** Ningún adaptador acepta un bloque que no expanda exactamente a la receta. */
export function validatedRunningRepeats(p: RunningPrescription): readonly RunningRepeatBlock[] {
  const groups=p.repeatBlocks??[];
  let previousEnd=0;
  for(const group of groups) {
    const {start,stepCount,iterations,omitLastRecovery}=group;
    const end=start+stepCount*iterations-(omitLastRecovery?1:0);
    const pattern=p.steps.slice(start,start+stepCount);
    if(![start,stepCount,iterations].every(Number.isInteger)||start<previousEnd||stepCount<1||iterations<2||
      iterations>100||end>p.steps.length||typeof omitLastRecovery!=='boolean'||!eligible(pattern)||
      omitLastRecovery&&(stepCount<2||!soft(pattern.at(-1)!))||
      p.steps.slice(start,end).some((step,index)=>comparable(step)!==comparable(pattern[index%stepCount]))) {
      throw new TrainingError('unsupported_prescription');
    }
    previousEnd=end;
  }
  return groups;
}
