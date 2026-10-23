import {runningTrainingCompatibility} from "../device_training/capabilities.ts";
import {TrainingError} from "../device_training/prescription.ts";
import type {RunningPrescription} from "../device_training/prescription.ts";
import {isStrength} from '../device_training/strength.ts';
import type {TrainingPrescription} from '../device_training/strength.ts';
import {garminStrengthWorkout,supportsGarminStrength} from './strength.ts';
import {DeliveryFailure} from "../device_training/delivery.ts";
import type {TrainingGateway} from "../device_training/delivery.ts";
import type {TrainingLifecycleGateway} from "../device_training/sync.ts";
export const garminRunningCapabilities={canSend:true,maxSteps:100,
  kinds:['run','warmup','cooldown','recovery','rest','walk','jog'],
  completions:['seconds','meters','manual'],pace:true} as const;
export function garminRunningWorkout(p:RunningPrescription) {
  if(runningTrainingCompatibility(p,garminRunningCapabilities).length) throw new TrainingError('unsupported_prescription');
  return {workoutName:p.name,description:p.description||"Sesión de carrera prescrita en EntrenaOP.",sport:"RUNNING",
    workoutProvider:"EntrenaOP",workoutSourceId:"EntrenaOP",segments:[{segmentOrder:1,sport:"RUNNING",steps:p.steps.map((step,index)=>({
      type:"WorkoutStep",stepOrder:index+1,description:step.description,
      intensity:({run:"ACTIVE",warmup:"WARMUP",cooldown:"COOLDOWN",rest:"REST",walk:"RECOVERY",jog:"RECOVERY",recovery:"RECOVERY"} as const)[step.kind],
      durationType:step.measure==="manual"?"OPEN":step.measure==="seconds"?"TIME":"DISTANCE",
      ...(step.measure==="manual"?{}:{durationValue:step.value}),
      // TIME usa segundos y DISTANCE metros; durationValueType solo modifica HR/POWER.
      targetType:step.pace?"PACE":"OPEN",
      // Garmin espera velocidad m/s: el extremo lento corresponde al mínimo.
      targetValueLow:step.pace?1000/step.pace.slow:null,targetValueHigh:step.pace?1000/step.pace.fast:null,
    }))}]};
}
function id(value:unknown):number {
  if(typeof value!=="number"||!Number.isSafeInteger(value)||value<=0) throw new DeliveryFailure("invalid_provider_response",true);return value;
}
export class GarminTrainingClient implements TrainingGateway,TrainingLifecycleGateway {
  readonly capabilities=garminRunningCapabilities;
  supportsStrength(p:TrainingPrescription):boolean{return isStrength(p)&&supportsGarminStrength(p);}
  private readonly f:typeof fetch;
  constructor(f:typeof fetch=fetch){this.f=f;}
  private async request(path:string,token:string,body?:unknown,method=body===undefined?'GET':'POST'):Promise<unknown> {
    const write=method!=='GET';
    try {
      const result=await this.f(`https://apis.garmin.com${path}`,{method,
        headers:{Authorization:`Bearer ${token}`,"Content-Type":"application/json"},body:body===undefined?undefined:JSON.stringify(body),
        signal:AbortSignal.timeout(10000),redirect:"error"});
      if(result.status===404){await result.body?.cancel().catch(()=>{});
        if(method==='DELETE')return null;
        throw new DeliveryFailure('provider_missing');}
      if(!result.ok){await result.body?.cancel().catch(()=>{});
        const code=result.status===429?"rate_limited":result.status===401?"reauthorization_required":
          [403,412].includes(result.status)?"permission_denied":result.status===400?"provider_rejected":"provider_unavailable";
        console.warn(JSON.stringify({event:"garmin_training_provider_failed",operation:path.startsWith("/workoutportal/")?"create":write?"schedule":"confirm",status:result.status,code}));
        throw new DeliveryFailure(code,write&&result.status>=500);
      }
      const reader=result.body?.getReader();if(!reader) return null;
      const chunks:Uint8Array[]=[];let size=0;
      try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;
        if(size>65536)throw new DeliveryFailure("invalid_provider_response",write);chunks.push(value);}}
      finally{await reader.cancel().catch(()=>{});}
      if(size===0)return null;
      const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
      try{return JSON.parse(new TextDecoder().decode(bytes));}catch{throw new DeliveryFailure("invalid_provider_response",write);}
    }catch(error){if(error instanceof DeliveryFailure)throw error;throw new DeliveryFailure("provider_unavailable",write);}
  }
  async create(token:string,p:TrainingPrescription):Promise<number> {
    // URL de creación especificada en Training API V2 2.0, p.18.
    const result=await this.request("/workoutportal/workout/v2",token,isStrength(p)?garminStrengthWorkout(p):garminRunningWorkout(p));
    return id(result&&typeof result==="object"?(result as Record<string,unknown>).workoutId:null);
  }
  async schedule(token:string,workout:number,date:string):Promise<void> {
    await this.request("/training-api/schedule/",token,{workoutId:workout,date});
  }
  async confirmSchedule(token:string,workout:number,date:string):Promise<number> {
    const result=await this.request(`/training-api/schedule?startDate=${date}&endDate=${date}`,token);
    if(!Array.isArray(result)||result.length>1000)throw new DeliveryFailure("invalid_provider_response");
    const matches=result.filter(x=>x&&x.workoutId===workout&&x.date===date);
    if(matches.length!==1)throw new DeliveryFailure("schedule_not_confirmed",true);
    return id(matches[0].scheduleId);
  }
  async update(token:string,workout:number,p:TrainingPrescription):Promise<void>{
    id(workout);
    await this.request(`/training-api/workout/v2/${workout}`,token,{...(isStrength(p)?garminStrengthWorkout(p):garminRunningWorkout(p)),workoutId:workout},'PUT');
  }
  async updateSchedule(token:string,schedule:number,workout:number,date:string):Promise<void>{
    id(schedule);id(workout);
    await this.request(`/training-api/schedule/${schedule}`,token,{scheduleId:schedule,workoutId:workout,date},'PUT');
  }
  async removeSchedule(token:string,schedule:number):Promise<void>{
    id(schedule);await this.request(`/training-api/schedule/${schedule}`,token,undefined,'DELETE');
  }
  async remove(token:string,workout:number):Promise<void>{
    id(workout);await this.request(`/training-api/workout/v2/${workout}`,token,undefined,'DELETE');
  }
}
