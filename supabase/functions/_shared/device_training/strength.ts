import {TrainingError, runningPrescription} from './prescription.ts';
import type {RunningPrescription} from './prescription.ts';

// La receta usa identificadores propios; las equivalencias de fabricante viven en su adaptador.
export type StrengthStep = {kind:'strength'|'rest'; measure:'reps'|'seconds'; value:number;
  description:string; exerciseCode:string|null; loadKg:number|null; block:number; item:number; set:number};
export type StrengthPrescription = {sport:'strength';name:string;description:string;date:string;source:'coach'|'algorithm';steps:StrengthStep[]};
export type TrainingPrescription = RunningPrescription | StrengthPrescription;
type Json=Record<string,unknown>;
const obj=(v:unknown):Json=>{if(!v||typeof v!=='object'||Array.isArray(v))throw new TrainingError('invalid_prescription');return v as Json;};
function sequence(v:unknown):Json[]{
  if(!Array.isArray(v)||!v.length||v.length>100)throw new TrainingError('unsupported_prescription');
  const rows=v.map(obj);if(rows.some((row,i)=>row.order_index!==i))throw new TrainingError('unsupported_prescription');return rows;
}
function text(v:unknown,max:number):string{
  if(typeof v!=='string'||!v.trim()||v.length>max||/[\u0000-\u001f]/u.test(v))throw new TrainingError('invalid_prescription');return v;
}
function integer(v:unknown,min:number,max:number):number{
  if(typeof v!=='number'||!Number.isInteger(v)||v<min||v>max)throw new TrainingError('invalid_prescription');return v;
}
export function strengthPrescription(value:unknown):StrengthPrescription{
  const p=obj(value);
  if(p.source!=='coach'&&p.source!=='algorithm')throw new TrainingError('source_not_allowed');
  const name=text(p.name,80),date=text(p.date,10),description=p.description==null||p.description===''?'':text(p.description,1024);
  if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date+'T00:00:00Z'))||new Date(date+'T00:00:00Z').toISOString().slice(0,10)!==date)throw new TrainingError('invalid_prescription');
  const steps:StrengthStep[]=[];
  for(const b of sequence(p.blocks)){
    // Otros formatos necesitan su traducción y aceptación; nunca aplanarlos a series por defecto.
    if(b.format!=='straight_sets'||b.rounds!==1||b.time_cap_seconds!=null)throw new TrainingError('unsupported_prescription');
    const items=sequence(b.items);
    for(const i of items){
      const code=text(i.exercise_code,100),label=text(i.exercise_name,200);
      const sets=sequence(i.sets);
      for(const s of sets){
        const allowed=new Set(['order_index','target_reps','target_duration_seconds','target_load_kg','target_rpe','target_rir','rest_after_seconds']);
        if(Object.entries(s).some(([k,v])=>!allowed.has(k)&&v!=null))throw new TrainingError('unsupported_prescription');
        if((s.target_reps==null)===(s.target_duration_seconds==null))throw new TrainingError('unsupported_prescription');
        const measure=s.target_reps==null?'seconds':'reps';
        const target=integer(s.target_reps??s.target_duration_seconds,1,measure==='reps'?1000:86400);
        const load=s.target_load_kg??null;
        if(load!==null&&(typeof load!=='number'||!Number.isFinite(load)||load<0||load>1000))throw new TrainingError('invalid_prescription');
        const notes=i.notes==null||i.notes===''?'':text(i.notes,200);
        const cues=[label,notes];
        if(s.target_rir!=null){if(typeof s.target_rir!=='number'||s.target_rir<0||s.target_rir>10)throw new TrainingError('invalid_prescription');cues.push(`RIR orientativo ${s.target_rir}`);}
        if(s.target_rpe!=null){if(typeof s.target_rpe!=='number'||s.target_rpe<1||s.target_rpe>10)throw new TrainingError('invalid_prescription');cues.push(`RPE orientativo ${s.target_rpe}/10`);}
        const position={block:Number(b.order_index),item:Number(i.order_index),set:Number(s.order_index)};
        steps.push({kind:'strength',measure,value:target,description:cues.filter(Boolean).join(' · '),exerciseCode:code,loadKg:load as number|null,...position});
        const rest=integer(s.rest_after_seconds,0,86400);
        if(rest)steps.push({kind:'rest',measure:'seconds',value:rest,description:'Descanso',exerciseCode:null,loadKg:null,...position});
      }
    }
    const rest=integer(b.rest_after_seconds,0,86400);
    if(rest)throw new TrainingError('unsupported_prescription');
  }
  if(steps.length>100||steps.some(s=>s.description.length>512))throw new TrainingError('unsupported_prescription');
  return {sport:'strength',name,date,description,source:p.source,steps};
}
export function isStrength(p:TrainingPrescription):p is StrengthPrescription{return 'sport' in p&&p.sport==='strength';}
export function trainingPrescription(value:unknown):TrainingPrescription{
  const p=obj(value);return p.sport==='strength'?strengthPrescription(p):runningPrescription(p);
}
