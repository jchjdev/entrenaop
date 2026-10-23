import {ready, identity, HttpError} from './http.ts';
import type {GarminServerConfig} from './http.ts';
import {GarminCipher} from './cipher.ts';
import {GarminOAuthClient} from './oauth.ts';
import {garminActivityCallback, downloadGarminFit, garminFitObservation} from './activity_fit.ts';
import {ActivityReturnService, activityReview} from '../device_activity/return_service.ts';
import type {ActivityReturnStore, ActivityJob} from '../device_activity/return_service.ts';
type Json = Record<string, unknown>;
export type ActivityReturnConfig = GarminServerConfig & {webhookSecret: string};
const codes = new Set(['account_changed','access_required','source_not_available','source_not_allowed','stale_prescription',
  'activity_not_found','activity_already_confirmed','stale_activity','stale_review','operation_reused','invalid_mapping',
  'invalid_rpe','invalid_offset','invalid_activity_clock','connection_changed','activity_queue_full','unsupported_activity']);
const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, x-client-info, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS','Cache-Control':'no-store'};
export class SupabaseActivityReturnStore implements ActivityReturnStore {
  private readonly c: GarminServerConfig; private readonly f: typeof fetch;
  constructor(c: GarminServerConfig, f: typeof fetch = fetch) { this.c = c; this.f = f; }
  async command(action: string, owner: string | null, session: string | null, input: Json): Promise<Json> {
    const result = await this.f(`${this.c.supabaseUrl}/rest/v1/rpc/garmin_activity_command`, {method:'POST',
      headers:{apikey:this.c.serviceKey, Authorization:`Bearer ${this.c.serviceKey}`, 'Content-Type':'application/json'},
      body:JSON.stringify({p_action:action,p_owner:owner,p_session:session,p_input:input}),
      redirect:'error',signal:AbortSignal.timeout(15000)});
    const data = await result.json();
    if (!result.ok) throw new Error(codes.has(data?.message) ? data.message : 'activity_unavailable');
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('activity_unavailable');
    return data;
  }
}
async function body(request: Request, max: number): Promise<Json> {
  const reader = request.body?.getReader(); if (!reader) throw new HttpError(400,'invalid_request');
  const decoder = new TextDecoder(); let text = '';
  try { for (;;) {
    const chunk = await reader.read(); if (chunk.done) break;
    text += decoder.decode(chunk.value,{stream:true}); if (text.length > max) throw new HttpError(413,'request_too_large');
  } } finally { await reader.cancel(); }
  let data: unknown; try { data = JSON.parse(text + decoder.decode()); } catch { throw new HttpError(400,'invalid_request'); }
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new HttpError(400,'invalid_request');
  return data as Json;
}
async function hash(value: string): Promise<string> {
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))].map(v=>v.toString(16).padStart(2,'0')).join('');
}
async function sameSecret(actual: string, expected: string): Promise<boolean> {
  const a = await hash(actual), b = await hash(expected); let diff = 0;
  for (let i=0;i<a.length;i++) diff |= a.charCodeAt(i)^b.charCodeAt(i);
  return diff === 0;
}
export async function drainActivityReturns(c: GarminServerConfig, f: typeof fetch = fetch, store: ActivityReturnStore = new SupabaseActivityReturnStore(c,f)): Promise<number> {
  const pending = await store.command('pending',null,null,{});
  const cipher = new GarminCipher(c.encryptionKey);
  const account = new GarminOAuthClient({clientId:c.clientId,clientSecret:c.clientSecret,redirectUri:`${c.supabaseUrl}/functions/v1/garmin-oauth-callback`},f);
  const service = new ActivityReturnService(store,account,cipher,{read:async (url,token,metadata)=>
    garminFitObservation(await downloadGarminFit(url,token,f),{activityId:String(metadata.activityId),activityName:String(metadata.activityName)})});
  let processed = 0; const deadline = Date.now()+40000;
  for (const id of pending.ids as string[]) {
    if (Date.now()>deadline) break;
    const job = await store.command('claim',null,null,{id,lease_id:crypto.randomUUID()});
    if (job.done || job.busy) continue;
    await service.process(job as unknown as ActivityJob); processed++;
  }
  return processed;
}
export async function handleActivityIngest(request: Request, c: ActivityReturnConfig, f: typeof fetch = fetch,
  after: (work: Promise<unknown>) => void = () => {}, store: ActivityReturnStore = new SupabaseActivityReturnStore(c,f)): Promise<Response> {
  try {
    ready(c); if (request.method!=='POST') throw new HttpError(405,'method_not_allowed');
    const url = new URL(request.url);
    // El portal Garmin elimina los parámetros query al guardar el receptor.
    // La capacidad permanece en un segmento opaco; nunca se registra la URL.
    const pathKey = url.pathname.match(/\/garmin-activity-ingest\/([A-Za-z0-9_-]{43,128})$/)?.[1];
    const key = pathKey ?? url.searchParams.get('key');
    if (key === null) {
      const token = request.headers.get('authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43,128})$/)?.[1];
      if (!token || !(await store.command('authorize',null,null,{token})).authorized) throw new HttpError(401,'unauthorized');
      return Response.json({processed:await drainActivityReturns(c,f,store)},{headers});
    }
    if (!/^[A-Za-z0-9_-]{43,128}$/.test(c.webhookSecret)) throw new HttpError(503,'activity_not_configured');
    if ((pathKey ? url.searchParams.has('key') : url.searchParams.getAll('key').length!==1) ||
        !await sameSecret(key,c.webhookSecret)) throw new HttpError(401,'unauthorized');
    const data = await body(request,131072);
    if (!Array.isArray(data.activityFiles) || data.activityFiles.length>50 || Object.keys(data).some(k=>k!=='activityFiles')) {
      throw new HttpError(400,'invalid_request');
    }
    let queued = 0;
    for (const raw of data.activityFiles) {
      if (!raw || typeof raw!=='object' || typeof raw.userId!=='string' || raw.userId.length>256) throw new HttpError(400,'invalid_request');
      if (raw.fileType!=='FIT' || raw.manual===true) continue;
      if (typeof raw.activityId==='number' && !Number.isSafeInteger(raw.activityId)) throw new HttpError(400,'invalid_request');
      const externalId = String(raw.activityId);
      if (!/^[0-9]{1,24}$/.test(externalId) || typeof raw.activityName!=='string' || raw.activityName.length>256) throw new HttpError(400,'invalid_request');
      const callback = garminActivityCallback(raw.callbackURL).toString();
      const eventKey = await hash(JSON.stringify([raw.userId,externalId,raw.summaryId,callback]));
      const id = crypto.randomUUID(), cipher = new GarminCipher(c.encryptionKey);
      await store.command('enqueue',null,null,{id,event_key:eventKey,provider_user_id:raw.userId,
        callback_cipher:await cipher.seal(callback,`activity-callback:${id}`),metadata:{activityId:externalId,activityName:raw.activityName}});
      queued++;
    }
    // Primero checkpoint durable y respuesta; la lectura del FIT queda fuera del ACK.
    if (queued) after(Promise.resolve().then(()=>drainActivityReturns(c,f,store)).catch(()=>{}));
    return Response.json({received:true},{headers});
  } catch (error) { return failure(error); }
}
export async function handleActivityUser(request: Request, c: GarminServerConfig, f: typeof fetch = fetch): Promise<Response> {
  if (request.method==='OPTIONS') return new Response(null,{status:204,headers});
  try {
    ready(c); if (request.method!=='POST') throw new HttpError(405,'method_not_allowed');
    const who = await identity(request,c,f), data = await body(request,32768);
    if (data.expected_user_id!==who.user) throw new HttpError(409,'account_changed');
    const schema = data.activity_schema_version ?? 1;
    if (schema!==1 && schema!==2) throw new HttpError(400,'invalid_request');
    const store = new SupabaseActivityReturnStore(c,f), action = data.action;
    if (action==='list') {
      const catalog = await store.command('list',who.user,who.session,{});
      // El iPhone anterior solo conoce vueltas de carrera y distancia numérica.
      // La evidencia de fuerza se conserva; solo la muestran clientes que piden V2.
      return Response.json(schema===2 ? catalog : {...catalog,
        activities:(catalog.activities as Json[]).filter(row=>(row.activity as Json).schemaVersion===1),
        candidates:(catalog.candidates as Json[]).filter(row=>(row.sport??'running')==='running'),
      },{headers});
    }
    if (!['preview','confirm'].includes(String(action))) throw new HttpError(400,'invalid_request');
    const input = {...data}; delete input.action; delete input.expected_user_id; delete input.activity_schema_version;
    const value = await store.command(String(action),who.user,who.session,input);
    if(action==='preview' && schema===1 && (value.activity as Json).schemaVersion!==1) throw new HttpError(409,'unsupported_activity');
    return Response.json(action==='preview' ? activityReview(value) : value,{headers});
  } catch (error) { return failure(error); }
}
function failure(error: unknown): Response {
  const code = error instanceof HttpError ? error.message : error instanceof Error && codes.has(error.message) ? error.message : 'activity_unavailable';
  const status = error instanceof HttpError ? error.status : 409;
  // No registrar Error/cause, callback, UAT, cuerpo FIT, usuario o métricas.
  console.warn(JSON.stringify({event:'garmin_activity_failed',code}));
  return Response.json({code},{status,headers});
}
