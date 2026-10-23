import {ActivityReturnError} from './running_result.ts';
import type {ObservedRunningActivity} from './running_result.ts';
export type ObservedStrengthSet={index:number;startedAt:string;seconds:number;kind:'active'|'rest';
  repetitions:number|null;loadKg:number|null;exerciseCode:string|null;workoutStepIndex:number|null};
export type ObservedStrengthActivity=Omit<ObservedRunningActivity,'schemaVersion'|'distanceMeters'|'laps'> & {
  schemaVersion:2;sport:'strength';distanceMeters:null;sets:ObservedStrengthSet[];
};
export type ObservedActivity=ObservedRunningActivity|ObservedStrengthActivity;
export function isStrengthActivity(a:ObservedActivity):a is ObservedStrengthActivity{return a.schemaVersion===2;}
export function validateStrengthObservation(a:ObservedStrengthActivity):void{
  const valid=(n:unknown,max:number)=>typeof n==='number'&&Number.isFinite(n)&&n>=0&&n<=max;
  const timestamp=(s:unknown)=>typeof s==='string'&&s.endsWith('Z')&&Number.isFinite(Date.parse(s));
  if(a.schemaVersion!==2||a.sport!=='strength'||a.distanceMeters!==null||!/^\d{1,24}$/.test(a.externalId)||
    typeof a.name!=='string'||a.name.length>256||!timestamp(a.startedAt)||!valid(a.elapsedSeconds,172800)||
    !valid(a.timerSeconds,a.elapsedSeconds)||a.timerSeconds<=0||!Array.isArray(a.sets)||a.sets.length>2000||a.sets.length===0||
    a.offsetSeconds!==null&&(!Number.isInteger(a.offsetSeconds)||Math.abs(a.offsetSeconds)>86400))throw new ActivityReturnError('invalid_activity');
  for(const hr of [a.averageHeartRate,a.maxHeartRate])if(hr!==null&&(!valid(hr,250)||hr<30))throw new ActivityReturnError('invalid_activity');
  if(a.averageHeartRate!==null&&a.maxHeartRate!==null&&a.maxHeartRate<a.averageHeartRate)throw new ActivityReturnError('invalid_activity');
  let end=Date.parse(a.startedAt),total=0;
  for(const [i,s] of a.sets.entries()){
    if(s.index!==i||!timestamp(s.startedAt)||Date.parse(s.startedAt)<end-1100||!valid(s.seconds,172800)||s.seconds<=0||
      !['active','rest'].includes(s.kind)||s.repetitions!==null&&(!valid(s.repetitions,1000)||!Number.isInteger(s.repetitions))||
      s.loadKg!==null&&!valid(s.loadKg,1000)||s.exerciseCode!==null&&!/^[a-z0-9_]{1,100}$/.test(s.exerciseCode)||
      s.workoutStepIndex!==null&&(!valid(s.workoutStepIndex,10000)||!Number.isInteger(s.workoutStepIndex)))throw new ActivityReturnError('invalid_activity');
    end=Date.parse(s.startedAt)+s.seconds*1000;total+=s.seconds;
  }
  if(end>Date.parse(a.startedAt)+a.elapsedSeconds*1000+2000||total>a.elapsedSeconds+2)throw new ActivityReturnError('invalid_activity');
}
