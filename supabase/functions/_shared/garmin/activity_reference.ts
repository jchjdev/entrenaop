import {garminRunningWorkout} from './training.ts';
import {garminStrengthWorkout} from './strength.ts';
import {runningPrescription} from '../device_training/prescription.ts';
import {strengthPrescription} from '../device_training/strength.ts';

type Row=Record<string,unknown>;
const kinds=new Set(['active','warmup','cooldown','rest','recovery']);
const exercises:Record<string,number>={BARBELL_BENCH_PRESS:1,PUSH_UP:77,PULL_UP:38};
const categories:Record<string,string>={BENCH_PRESS:'benchPress',PUSH_UP:'pushUp',PULL_UP:'pullUp'};
function scalar(value:unknown,scale=1):number|null {
  return typeof value==='number'&&Number.isFinite(value)&&value>=0&&value*scale<=1e9?Math.round(value*scale):null;
}
function signature(sport:string,steps:Row[],native:boolean):string|null {
  if(!steps.length||steps.length>100)return null;
  const result:unknown[][]=[];
  for(const [index,s] of steps.entries()){
    if((native?s.messageIndex:s.stepOrder)!==(native?index:index+1))return null;
    const kind=String(s.intensity).toLowerCase();
    const duration=String(s.durationType).toLowerCase();
    if(!kinds.has(kind)||!['time','distance','open','reps'].includes(duration))return null;
    const value=duration==='open'?0:scalar(s.durationValue,native?1:duration==='time'?1000:duration==='distance'?100:1);
    if(value===null)return null;
    const target=String(s.targetType).toLowerCase().replace('pace','speed');
    if(!['open','speed'].includes(target)||native&&Number(s.targetValue??0)!==0)return null;
    const low=target==='open'?null:scalar(native?s.customTargetValueLow:s.targetValueLow,native?1:1000);
    const high=target==='open'?null:scalar(native?s.customTargetValueHigh:s.targetValueHigh,native?1:1000);
    if(target==='speed'&&(low===null||high===null||low<=0||high<low))return null;
    if(native&&s.secondaryTargetType!=null&&s.secondaryTargetType!=='open')return null;
    let exercise:string|null=null,weight:number|null=null;
    if(sport==='strength'&&kind!=='rest'){
      const category=native?String(s.exerciseCategory??'unknown'):categories[String(s.exerciseCategory)]??'unknown';
      const name=native?s.exerciseName:exercises[String(s.exerciseName)];
      exercise=category==='unknown'?'unknown':`${category}:${String(name)}`;
      const rawWeight=native?s.exerciseWeight:s.weightValue;
      weight=rawWeight==null?null:scalar(rawWeight,100);
      if(rawWeight!=null&&weight===null)return null;
    }
    result.push([kind,duration,value,target,low,high,exercise,weight]);
  }
  // Referencia del contenido exportable: dos citas con los mismos pasos siguen
  // siendo ambiguas. No se usa el nombre traducido ni la fecha como identidad.
  return JSON.stringify(['garmin-workout-v1',sport,result]);
}
export function nativeGarminPrescriptionReference(workouts:Row[],steps:Row[]):string|null {
  if(workouts.length!==1||Number(workouts[0].numValidSteps)!==steps.length)return null;
  const w=workouts[0];
  const sport=w.sport==='running'?'running':w.sport==='training'&&w.subSport==='strengthTraining'?'strength':null;
  return sport===null?null:signature(sport,steps,true);
}
export function deliveredGarminPrescriptionReference(snapshot:unknown):string|null {
  try {
    const strength=(snapshot as Row)?.sport==='strength';
    const workout=strength?garminStrengthWorkout(strengthPrescription(snapshot)):garminRunningWorkout(runningPrescription(snapshot));
    if(workout.segments.length!==1)return null;
    return signature(strength?'strength':'running',workout.segments[0].steps as unknown as Row[],false);
  } catch { return null; }
}
