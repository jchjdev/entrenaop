// Contrato de carrera independiente de Garmin, Flutter y la persistencia.
export type RunningStep={kind:"run"|"warmup"|"cooldown"|"rest"|"walk"|"jog";
  measure:"seconds"|"meters";value:number;description:string;pace?:{fast:number;slow:number}};
export type RunningPrescription={name:string;description:string;date:string;source:"algorithm"|"coach";steps:RunningStep[]};
export class TrainingError extends Error {constructor(code:string){super(code);this.name="TrainingError";}}
type Json=Record<string,unknown>;
function object(value:unknown):Json {
  if(!value || typeof value!=="object" || Array.isArray(value)) throw new TrainingError("invalid_prescription");
  return value as Json;
}
function list(value:unknown,max:number):Json[] {
  if(!Array.isArray(value)||!value.length||value.length>max) throw new TrainingError("unsupported_prescription");
  const result=value.map(object);
  for(let i=0;i<result.length;i++) if(result[i].order_index!==i) throw new TrainingError("unsupported_prescription");
  return result;
}
function positive(value:unknown):number {
  if(typeof value!=="number"||!Number.isFinite(value)||value<=0) throw new TrainingError("invalid_prescription");return value;
}
function text(value:unknown,max:number):string {
  if(typeof value!=="string"||!value.trim()||Array.from(value).length>max||/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(value)) {
    throw new TrainingError("unsupported_prescription");
  }return value;
}
function measure(seconds:unknown,meters:unknown):Pick<RunningStep,"measure"|"value"> {
  if((seconds==null)===(meters==null)) throw new TrainingError("unsupported_prescription");
  const value=positive(seconds??meters);
  if(seconds!=null&&!Number.isInteger(value)) throw new TrainingError("unsupported_prescription");
  return {measure:seconds!=null?"seconds":"meters",value};
}
/** No estimaciones ni supresión de recuperación final para encajar un reloj. */
export function runningPrescription(value:unknown):RunningPrescription {
  const input=object(value);
  if(input.source!=="algorithm"&&input.source!=="coach") throw new TrainingError("source_not_allowed");
  const name=text(input.name,80),date=text(input.date,10);
  const description=input.description==null||input.description===""?"":text(input.description,1024);
  if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||new Date(date+"T00:00:00Z").toISOString().slice(0,10)!==date) throw new TrainingError("invalid_prescription");
  const steps:RunningStep[]=[];
  for(const block of list(input.blocks,100)) {
    if(!["running","warm_up","cool_down"].includes(String(block.format))||block.rounds!==1||block.rest_after_seconds!==0||block.time_cap_seconds!=null) {
      throw new TrainingError("unsupported_prescription");
    }
    const blockName=text(block.name,200);
    for(const item of list(block.items,100)) {
      if(item.exercise_id!=="20000000-0000-4000-8000-000000000004") throw new TrainingError("unsupported_prescription");
      const note=item.notes==null?"":text(item.notes,400);
      for(const set of list(item.sets,100)) {
        if(set.target_reps!=null||set.target_load_kg!=null||set.target_rir!=null||set.performance_prescription!=null||set.rest_after_seconds!==0) {
          throw new TrainingError("unsupported_prescription");
        }
        let description=[blockName,note].filter(Boolean).join(" · ");
        if(set.target_rpe!=null) {
          const rpe=positive(set.target_rpe);if(rpe>10) throw new TrainingError("invalid_prescription");
          description+=` · RPE orientativo ${rpe}/10`;
        }
        text(description,512);
        const step:RunningStep={kind:block.format==="warm_up"?"warmup":block.format==="cool_down"?"cooldown":"run",
          ...measure(set.target_duration_seconds,set.target_distance_meters),description};
        const fast=set.target_pace_min_seconds_per_km,slow=set.target_pace_max_seconds_per_km;
        if((fast==null)!==(slow==null)) throw new TrainingError("invalid_prescription");
        if(fast!=null){const f=positive(fast),s=positive(slow);if(!Number.isInteger(f)||!Number.isInteger(s)||f>s||s>3600) throw new TrainingError("invalid_prescription");step.pace={fast:f,slow:s};}
        steps.push(step);
        if(set.recovery_type!=null) {
          const kind=({passive:"rest",walking:"walk",jogging:"jog"} as const)[String(set.recovery_type) as "passive"|"walking"|"jogging"];
          if(!kind) throw new TrainingError("unsupported_prescription");
          const duration=measure(set.recovery_duration_seconds,set.recovery_distance_meters);
          if(kind==="rest"&&duration.measure!=="seconds") throw new TrainingError("unsupported_prescription");
          steps.push({kind,...duration,description:kind==="rest"?"Recuperación pasiva":kind==="walk"?"Recuperación andando":"Recuperación trotando"});
        }else if(set.recovery_duration_seconds!=null||set.recovery_distance_meters!=null) throw new TrainingError("invalid_prescription");
        if(steps.length>100) throw new TrainingError("unsupported_prescription");
      }
    }
  }
  return {name,description,date,source:input.source,steps};
}
