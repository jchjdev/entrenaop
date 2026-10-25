import {createFcmSender,createPushWorker,type Rpc,type ServiceAccount} from './worker.ts';

// Publicado únicamente en Dev. Inerte sin secreto, proveedor y doble activación.
const url = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
// La clave interna inyectada por Supabase puede diferir del JWT estable del
// invocador. Este último se fija explícitamente; no se acepta cualquier JWT.
const callerKey = Deno.env.get('STUDENT_PUSH_CALLER_KEY') ?? '';
const workerSecret = Deno.env.get('STUDENT_PUSH_WORKER_SECRET') ?? '';
const enabled = Deno.env.get('STUDENT_PUSH_ENABLED') === 'true' &&
  url === 'https://sxbxfjqgoddzhtcyhalw.supabase.co';
let account: ServiceAccount | null = null;
try { account=JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? 'null'); } catch { /* Falta configuración: no se reclama trabajo. */ }
const rpc: Rpc = async (name,params={}) => {
  const response = await fetch(url+'/rest/v1/rpc/'+name,{
    method:'POST',headers:{apikey:serviceKey,Authorization:'Bearer '+serviceKey,'Content-Type':'application/json'},
    body:JSON.stringify(params),signal:AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error('Worker database unavailable');
  return response.status===204 ? null : await response.json();
};
let send: ReturnType<typeof createFcmSender> | null = null;
try { if (account) send=createFcmSender(account); } catch { /* No se imprimen credenciales ni errores del proveedor. */ }
const handler = createPushWorker({enabled:enabled && send!==null,secret:workerSecret,serviceRoleKey:callerKey,
  schedulerJwt:Deno.env.get('STUDENT_PUSH_SCHEDULER_JWT') ?? '',
  consumeTicket:async(ticket)=>await rpc('consume_student_push_dispatch_ticket',{p_token:ticket})===true,
  projectId:account?.project_id ?? '',rpc,send:send ?? (()=>Promise.resolve('retry'))});
Deno.serve(handler);
