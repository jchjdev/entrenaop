import {identity, requestBody, HttpError} from './http.ts';
import type {GarminServerConfig} from './http.ts';
import {garminStrengthFit} from './strength_fit.ts';
import {TrainingError} from '../device_training/prescription.ts';
import {ciqPrivacy} from './ciq_privacy.ts';

const devUrl = 'https://sxbxfjqgoddzhtcyhalw.supabase.co';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const tokenPattern = /^eopciq_[A-Za-z0-9_-]{43}$/;
const codes = new Set(['invalid_code','rate_limited','device_limit','account_changed','access_required','link_not_found',
  'link_required','link_revoked','pair_expired','source_not_available','stale_prescription','too_many_sessions',
  'source_not_allowed','unsupported_prescription']);
const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type',
  'Access-Control-Allow-Methods':'POST,GET,OPTIONS','Cache-Control':'no-store','X-EntrenaOP-Version':'ciq-private-2'};
const object = (v: unknown): Record<string, any> => {
  if (!v || typeof v !== 'object' || Array.isArray(v)) throw new HttpError(503,'ciq_unavailable');
  return v as Record<string, any>;
};
export async function ciqHash(kind: 'token'|'code'|'manifest', value: string): Promise<string> {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(`ciq:${kind}:${value}`))))
    .map(b=>b.toString(16).padStart(2,'0')).join('');
}
export function ciqCode(raw: unknown): string {
  if (typeof raw !== 'string') throw new HttpError(400,'invalid_code');
  const value = raw.replace(/[\s-]/g,'').toUpperCase();
  if (!/^[A-Z2-7]{8}$/.test(value)) throw new HttpError(400,'invalid_code');
  return value;
}
function credentials() {
  const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  const bytes=crypto.getRandomValues(new Uint8Array(32));
  return {credential:'eopciq_'+btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=',''),
    code:Array.from(crypto.getRandomValues(new Uint8Array(8))).map(b=>alphabet[b&31]).join('')};
}
type Export = {id:string; serial:number; created_at:string; snapshot:Record<string,unknown>; revision?:string; scheduled_id?:string};
export function ciqExport(raw: unknown): {entry:Export; name:string; bytes:Uint8Array} {
  const entry=object(raw) as Export;
  if (!uuid.test(entry.id) || !Number.isSafeInteger(entry.serial) || entry.serial<1 || entry.serial>0xfffffffe ||
      typeof entry.created_at!=='string') throw new HttpError(503,'ciq_unavailable');
  const snapshot=object(entry.snapshot);
  // La comparación nativa es exacta: evitar títulos largos o normalizaciones.
  // El nombre visible completo permanece en el manifiesto; este alias es único
  // por exportación, ASCII y de hasta 13 bytes para todo el rango uint32 válido.
  const name=`EOP${entry.serial}`;
  // Otro producto distingue este formato del anterior aunque ya se haya importado
  // el mismo serial/fecha. La identidad sigue siendo estable entre reintentos.
  const bytes=garminStrengthFit(snapshot,{serialNumber:entry.serial,createdAt:new Date(entry.created_at),workoutName:name,productNumber:2});
  return {entry,name,bytes};
}
export async function handleGarminCiq(request:Request,c:GarminServerConfig,f:typeof fetch=fetch):Promise<Response> {
  const json=(data:unknown,status=200)=>Response.json(data,{status,headers});
  if(request.method==='OPTIONS') return new Response(null,{status:204,headers});
  try {
    if(c.environment!=='DEVELOPMENT'||c.supabaseUrl!==devUrl||!c.serviceKey||!c.anonKey) throw new HttpError(503,'ciq_not_configured');
    const path=new URL(request.url).pathname;
    if(new URL(request.url).search) throw new HttpError(400,'invalid_request');
    // Aviso estático público para la ficha Beta. No consulta datos ni autoriza uso.
    if(path.endsWith('/garmin-ciq/privacy')) {
      if(request.method!=='GET') throw new HttpError(405,'method_not_allowed');
      return new Response(ciqPrivacy,{headers:{...headers,'Content-Type':'text/plain; charset=utf-8',
        'X-Content-Type-Options':'nosniff'}});
    }
    const command=async(action:string,input:Record<string,unknown>,owner:string|null=null,session:string|null=null)=>{
      const response=await f(`${c.supabaseUrl}/rest/v1/rpc/garmin_ciq_command`,{method:'POST',
        headers:{apikey:c.serviceKey,Authorization:`Bearer ${c.serviceKey}`,'Content-Type':'application/json'},
        body:JSON.stringify({p_action:action,p_owner:owner,p_session:session,p_input:input}),redirect:'error',signal:AbortSignal.timeout(15000)});
      const data=object(await response.json());
      const error=data.error??(!response.ok?data.message:null);
      if(error) throw new HttpError(error==='rate_limited'?429:403,codes.has(error)?error:'ciq_unavailable');
      return data;
    };
    if(path.endsWith('/garmin-ciq/account')) {
      if(request.method!=='POST') throw new HttpError(405,'method_not_allowed');
      const actor=await identity(request,c,f),body=await requestBody(request);
      if(body.expected_user_id!==actor.user) throw new HttpError(409,'account_changed');
      if(body.action==='account') return json(await command('account',{},actor.user,actor.session));
      if(body.action==='revoke'&&typeof body.id==='string'&&uuid.test(body.id)) {
        return json(await command('revoke',{id:body.id},actor.user,actor.session));
      }
      if(body.action==='review'||body.action==='approve') {
        const code=ciqCode(body.code);
        if(body.action==='approve'&&(typeof body.id!=='string'||!uuid.test(body.id))) throw new HttpError(400,'invalid_request');
        return json(await command(body.action,{code_hash:await ciqHash('code',code),...(body.action==='approve'?{id:body.id}:{})},actor.user,actor.session));
      }
      throw new HttpError(400,'invalid_request');
    }
    let body:Record<string,unknown>={};
    if(path.endsWith('/garmin-ciq/watch')) {
      if(request.method!=='POST') throw new HttpError(405,'method_not_allowed');
      body=await requestBody(request);
      if(body.action==='begin') {
        const pair=credentials();
        const result=await command('begin',{token_hash:await ciqHash('token',pair.credential),code_hash:await ciqHash('code',pair.code)});
        return json({...result,...pair});
      }
    }
    const authorization=request.headers.get('Authorization')??'';
    const token=authorization.startsWith('Bearer ')?authorization.slice(7):'';
    if(!tokenPattern.test(token)) throw new HttpError(401,'link_required');
    const token_hash=await ciqHash('token',token);
    if(path.endsWith('/garmin-ciq/watch')) {
      if(body.action==='status'||body.action==='unlink') return json(await command(body.action,{token_hash}));
      if(body.action==='manifest'||body.action==='changes') {
        const result=await command('manifest',{token_hash});
        if(result.complete!==true||!Array.isArray(result.entries)||result.entries.length>30) throw new HttpError(503,'ciq_unavailable');
        const entries=[]; let blocked=Number(result.blocked)||0;
        for(const raw of result.entries) {
          try {
            const {entry,name}=ciqExport(raw);
            entries.push({id:entry.id,scheduled_id:entry.scheduled_id,revision:entry.revision,name:entry.snapshot.name,
              date:entry.snapshot.date,fit_name:name});
          } catch(error) {
            if(!(error instanceof TrainingError)) throw error;
            blocked++;
          }
        }
        const revision=await ciqHash('manifest',JSON.stringify(entries.map(e=>[e.id,e.revision,e.fit_name])));
        if(body.action==='changes') return json({revision,count:entries.length,blocked});
        return json({complete:true,entries,blocked,revision,valid_until:result.valid_until});
      }
      throw new HttpError(400,'invalid_request');
    }
    const match=path.match(/\/garmin-ciq\/fit\/([0-9a-f-]{36})$/i);
    if(!match||!uuid.test(match[1])||request.method!=='GET') throw new HttpError(404,'not_found');
    const {bytes}=ciqExport(await command('download',{token_hash,id:match[1]}));
    return new Response(new Uint8Array(bytes),{headers:{...headers,'Content-Type':'application/vnd.ant.fit',
      'Content-Disposition':`attachment; filename="entrenaop-${match[1]}.fit"`}});
  } catch(error) {
    if(error instanceof HttpError) return json({code:error.message},error.status);
    if(error instanceof TrainingError) return json({code:'unsupported_prescription'},422);
    return json({code:'ciq_unavailable'},503);
  }
}
