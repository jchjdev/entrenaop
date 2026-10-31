import {runningPrescription, TrainingError} from '../device_training/prescription.ts';

export type AppleConfig={url:string;key:string;enabled:boolean};
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, x-client-info, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Cache-Control':'no-store'};
const safe=new Set(['access_required','account_changed','source_not_allowed','source_not_available','stale_prescription','unsupported_prescription','invalid_prescription','date_outside_window','connection_busy','results_disabled','activity_conflict','history_limit']);
export async function handleAppleTraining(request:Request,c:AppleConfig,f:typeof fetch=fetch):Promise<Response>{
 const reply=(data:unknown,status=200)=>Response.json(data,{status,headers:cors});
 if(request.method==='OPTIONS')return new Response(null,{headers:cors});
 if(!c.enabled||c.url!=='https://sxbxfjqgoddzhtcyhalw.supabase.co'||!c.key)return reply({code:'apple_not_configured'},503);
 if(request.method!=='POST')return reply({code:'method_not_allowed'},405);
 const bearer=request.headers.get('Authorization');if(!bearer?.startsWith('Bearer '))return reply({code:'unauthorized'},401);
 try{
  // Límite previo al parseo. No se acepta una receta suministrada por el móvil.
  const reader=request.body?.getReader();if(!reader)return reply({code:'invalid_request'},400);
  let raw='';const decoder=new TextDecoder();
  try{while(true){const {done,value}=await reader.read();if(done)break;raw+=decoder.decode(value,{stream:true});if(raw.length>65536)return reply({code:'invalid_request'},413);}}finally{await reader.cancel().catch(()=>{});}
  const b=JSON.parse(raw);if(!b||typeof b!=='object'||Array.isArray(b)||!['list','preview','prepare','record','removal','removed','results.catalog','results.enable','results.ingest','results.classify'].includes(b.action)||typeof b.owner!=='string')return reply({code:'invalid_request'},400);
  if(b.action!=='results.ingest'&&raw.length>3000)return reply({code:'invalid_request'},413);
  const results=b.action.startsWith('results.');
  const response=await f(`${c.url}/rest/v1/rpc/${results?'apple_results_command':'apple_training_command'}`,{method:'POST',headers:{apikey:c.key,Authorization:bearer,'Content-Type':'application/json'},body:JSON.stringify({p_owner:b.owner,p_action:results?b.action.slice(8):b.action,p_input:b.input??{}}),redirect:'error',signal:AbortSignal.timeout(15000)});
  const data=await response.json();
  if(!response.ok)return reply({code:safe.has(data?.message)?data.message:response.status===401?'unauthorized':'apple_unavailable'},response.status===401?401:409);
  if(b.action==='preview'||b.action==='prepare'){
   // El mismo contrato deportivo que Garmin, sin importar su adaptador ni OAuth.
   const prescription=runningPrescription(data.snapshot);
   return reply({...data,snapshot:undefined,prescription});
  }
  if(b.action==='results.catalog'){
   return reply({...data,plans:data.plans.map((plan:{snapshot:unknown;revision:string;plan_id:string})=>({plan_id:plan.plan_id,revision:plan.revision,prescription:runningPrescription(plan.snapshot)}))});
  }
  return reply(data);
 }catch(error){return reply({code:error instanceof TrainingError?error.message:'apple_unavailable'},409);}
}
