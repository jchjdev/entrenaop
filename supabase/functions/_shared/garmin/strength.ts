import {TrainingError} from '../device_training/prescription.ts';
import type {StrengthPrescription} from '../device_training/strength.ts';

// Equivalencias explícitas contrastadas con Training API V2, anexos A/B.
// No se deduce la variante a partir de un nombre traducido o de un patrón muscular.
export const garminStrengthExercises:Readonly<Record<string,{category:string;name:string}>>={
  bench_press_barbell:{category:'BENCH_PRESS',name:'BARBELL_BENCH_PRESS'},
  push_up_standard:{category:'PUSH_UP',name:'PUSH_UP'},
  pull_up_pronated:{category:'PULL_UP',name:'PULL_UP'},
};
export function supportsGarminStrength(p:StrengthPrescription):boolean{
  return p.steps.length<=100&&p.steps.every(s=>s.kind==='rest'||s.exerciseCode!=null&&Object.hasOwn(garminStrengthExercises,s.exerciseCode));
}
export function garminStrengthWorkout(p:StrengthPrescription){
  if(!supportsGarminStrength(p))throw new TrainingError('unsupported_prescription');
  return {workoutName:p.name,description:p.description||'Sesión de fuerza prescrita en EntrenaOP.',sport:'STRENGTH_TRAINING',
    workoutProvider:'EntrenaOP',workoutSourceId:'EntrenaOP',segments:[{segmentOrder:1,sport:'STRENGTH_TRAINING',steps:p.steps.map((s,i)=>({
      type:'WorkoutStep',stepOrder:i+1,description:s.description,intensity:s.kind==='rest'?'REST':'ACTIVE',
      durationType:s.measure==='reps'?'REPS':'TIME',durationValue:s.value,targetType:'OPEN',
      ...(s.kind==='rest'?{}:{exerciseCategory:garminStrengthExercises[s.exerciseCode!].category,exerciseName:garminStrengthExercises[s.exerciseCode!].name,
        ...(s.loadKg==null?{}:{weightValue:s.loadKg,weightDisplayUnit:'KILOGRAM'})}),
    }))}]};
}
