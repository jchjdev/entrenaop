export type Outcome = 'sent' | 'retry' | 'invalid';
type Job = { job_id: string; installation_id: string; claim_id: string; generation: number; binding_id: string; token: string };
export type Rpc = (name: string, params?: Record<string, unknown>) => Promise<unknown>;

function authorized(expected: string, actual: string | null): boolean {
  if (!/^[a-f0-9]{64}$/.test(expected) || actual?.length !== 64) return false;
  let difference = 0;
  for (let i = 0; i < 64; i++) difference |= expected.charCodeAt(i) ^ actual.charCodeAt(i);
  return difference === 0;
}

export function createPushWorker(options: {
  enabled: boolean; secret: string; serviceRoleKey: string; projectId: string; rpc: Rpc;
  schedulerJwt?: string;
  consumeTicket?: (ticket: string) => Promise<boolean>;
  send: (destination: string, kind: string, previousDay?: boolean) => Promise<Outcome>;
}) {
  return async (request: Request): Promise<Response> => {
    const bearer=request.headers.get('Authorization') ?? '';
    const expected='Bearer '+options.serviceRoleKey;
    if (request.method !== 'POST') return Response.json({code:'method_not_allowed'}, {status:405});
    let difference=0;
    let access=false;
    if(options.serviceRoleKey.length>=20 && bearer.length===expected.length) {
      for(let i=0;i<expected.length;i++) difference |= bearer.charCodeAt(i)^expected.charCodeAt(i);
      access=difference===0 && authorized(options.secret,request.headers.get('X-EntrenaOP-Push-Worker'));
    }
    // El programador solo activa este trabajo fijo con una capacidad efímera
    // consumida atómicamente. No deposita la clave de servicio en pg_net.
    const ticket=request.headers.get('X-EntrenaOP-Push-Ticket');
    if(!access && options.enabled && options.schedulerJwt && options.consumeTicket &&
       bearer==='Bearer '+options.schedulerJwt && ticket && /^[A-Za-z0-9_-]{43}$/.test(ticket)) {
      try { access=await options.consumeTicket(ticket); } catch { access=false; }
    }
    if(!access) return Response.json({code:'unauthorized'},{status:401});
    if (!options.enabled) return Response.json({disabled:true});
    try {
      const config = await options.rpc('get_student_push_worker_configuration') as {enabled:boolean;firebase_project_id:string};
      if (!config.enabled) return Response.json({disabled:true});
      if (config.firebase_project_id !== options.projectId) return Response.json({code:'provider_mismatch'}, {status:503});
      const jobs = await options.rpc('claim_student_notice_jobs', {p_limit:5}) as Job[];
      if (!Array.isArray(jobs) || jobs.length>5) throw new Error('Invalid batch');
      const counts = {sent:0,retry:0,invalid:0,skipped:0,errors:0,deferred:0};
      for (const job of jobs) {
        const identity = {p_id:job.job_id,p_claim:job.claim_id,p_generation:job.generation,p_binding:job.binding_id};
        try {
          const current = await options.rpc('prepare_student_notice_job',identity) as {kind:string;previous_day?:boolean}|null;
          let outcome: Outcome | 'skipped' | 'deferred' = 'skipped';
          if (current?.kind === 'defer') outcome='deferred';
          else if (current && ['assignment','message','other','reminder'].includes(current.kind)) {
            try { outcome = await options.send(job.token,current.kind,current.previous_day===true); } catch { outcome='retry'; }
          }
          await options.rpc('finish_student_notice_job',{...identity,p_outcome:outcome});
          if (outcome==='invalid') await options.rpc('retire_invalid_push_device',{p_id:job.installation_id,p_binding:job.binding_id});
          counts[outcome]++;
        } catch { counts.errors++; }
      }
      // Nunca devuelve identificadores, direcciones de entrega ni cuerpos.
      return Response.json(counts,{status:counts.errors ? 503 : 200});
    } catch { return Response.json({code:'worker_unavailable'},{status:503}); }
  };
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'');
}
const encoder = new TextEncoder();
export type ServiceAccount = {type:string;project_id:string;client_email:string;private_key:string};

export function createFcmSender(account: ServiceAccount, fetcher: typeof fetch = fetch) {
  if (account.type!=='service_account' || !/^[a-z][a-z0-9-]{4,62}$/.test(account.project_id) ||
      typeof account.client_email!=='string' || typeof account.private_key!=='string') throw new Error('Provider configuration missing');
  let accessToken: string | null = null, expiresAt = 0;
  async function bearer(): Promise<string> {
    if (accessToken && expiresAt>Date.now()+60000) return accessToken;
    const now = Math.floor(Date.now()/1000);
    const header = base64url(encoder.encode(JSON.stringify({alg:'RS256',typ:'JWT'})));
    const payload = base64url(encoder.encode(JSON.stringify({iss:account.client_email,
      scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})));
    const der = Uint8Array.from(atob(account.private_key.replace(/-----[^-]+-----|\s/g,'')),c=>c.charCodeAt(0));
    const key = await crypto.subtle.importKey('pkcs8',der,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,encoder.encode(header+'.'+payload));
    const assertion = header+'.'+payload+'.'+base64url(new Uint8Array(signature));
    const response = await fetcher('https://oauth2.googleapis.com/token',{method:'POST',
      headers:{'Content-Type':'application/x-www-form-urlencoded'},
      body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),
      signal:AbortSignal.timeout(15000)});
    const result = await response.json() as {access_token?:string;expires_in?:number};
    if (!response.ok || !result.access_token) throw new Error('Provider authorization failed');
    accessToken=result.access_token; expiresAt=Date.now()+Math.min(result.expires_in??300,3600)*1000;
    return accessToken;
  }
  return async (destination: string, kind = 'other', previousDay = false): Promise<Outcome> => {
    const body = kind === 'assignment' ? 'Tu preparador ha actualizado tu planificación.' :
      kind === 'message' ? 'Tienes mensajes pendientes de tu preparador.' :
      kind === 'reminder' ? (previousDay ? 'Tienes entrenamiento pautado para mañana.' : 'Tienes entrenamiento pautado para hoy.') :
      'Tienes novedades de seguimiento pendientes.';
    const response = await fetcher(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,{
      method:'POST',headers:{Authorization:'Bearer '+await bearer(),'Content-Type':'application/json'},
      body:JSON.stringify({message:{fid:destination,
        notification:{title:'EntrenaOP',body},data:{type:'student_notices',notice_kind:kind},
        android:{collapse_key:'entrenaop_notices',priority:'NORMAL',ttl:'3600s',notification:{tag:'entrenaop_notices'}},
        apns:{headers:{'apns-collapse-id':'entrenaop-notices','apns-expiration':String(Math.floor(Date.now()/1000)+3600)},payload:{aps:{sound:'default'}}},
      }}),signal:AbortSignal.timeout(15000),
    });
    if (response.ok) return 'sent';
    const result = await response.json().catch(()=>({})) as {error?:{details?:{errorCode?:string}[]}};
    const permanent = result.error?.details?.some(d=>d.errorCode==='UNREGISTERED' || d.errorCode==='SENDER_ID_MISMATCH');
    return permanent ? 'invalid' : 'retry';
  };
}
