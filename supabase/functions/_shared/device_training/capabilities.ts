import type {RunningPrescription,RunningStep} from "./prescription.ts";

// Las capacidades pertenecen al adaptador verificado, nunca se deducen de la marca.
export type RunningTrainingCapabilities={
  canSend:boolean; maxSteps:number;
  kinds:readonly RunningStep['kind'][];
  completions:readonly RunningStep['measure'][];
  pace:boolean;
};
export type TrainingCompatibilityIssue={step:number|null;reason:'send_unavailable'|'step_limit'|'step_kind'|'completion'|'pace'};
export function runningTrainingCompatibility(p:RunningPrescription,c:RunningTrainingCapabilities):TrainingCompatibilityIssue[] {
  const issues:TrainingCompatibilityIssue[]=[];
  if(!c.canSend) issues.push({step:null,reason:'send_unavailable'});
  if(p.steps.length>c.maxSteps) issues.push({step:null,reason:'step_limit'});
  p.steps.forEach((s,index)=>{
    if(!c.kinds.includes(s.kind)) issues.push({step:index,reason:'step_kind'});
    if(!c.completions.includes(s.measure)) issues.push({step:index,reason:'completion'});
    if(s.pace&&!c.pace) issues.push({step:index,reason:'pace'});
  });
  return issues;
}
