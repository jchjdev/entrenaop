import { GarminCipher } from "./cipher.ts";
import { GarminCallbackError, GarminConnectionService } from "./connection.ts";
import type { GarminConnectionStore } from "./connection.ts";
import { GarminOAuthClient } from "./oauth.ts";

export type GarminServerConfig = {
  environment: string; supabaseUrl: string; anonKey: string; serviceKey: string;
  clientId: string; clientSecret: string; encryptionKey: string;
};
const devUrl="https://sxbxfjqgoddzhtcyhalw.supabase.co";
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods":"POST, OPTIONS"};
class HttpError extends Error {
  readonly status: number;
  constructor(status:number,code:string) { super(code); this.status=status; }
}
function object(value:unknown):Record<string,unknown> {
  if(!value || typeof value!=="object" || Array.isArray(value)) throw new HttpError(400,"invalid_request");
  return value as Record<string,unknown>;
}
function response(body:unknown,status=200) { return Response.json(body,{status,headers:{...cors,"Cache-Control":"no-store"}}); }
function ready(c:GarminServerConfig) {
  // Primera entrega exclusivamente Dev y cerrada por defecto; no activar producción por accidente.
  if(c.environment!=="DEVELOPMENT" || c.supabaseUrl!==devUrl ||
    !c.anonKey || !c.serviceKey || !c.clientId || !c.clientSecret || !c.encryptionKey) throw new HttpError(503,"garmin_not_configured");
}
const exposedCodes=new Set(["access_required","account_changed","invalid_attempt","stale_attempt","connection_busy",
  "rate_limited","provider_account_in_use","authorization_denied","reauthorization_required","provider_unavailable",
  "provider_rejected","permission_denied","invalid_callback"]);
function safeCode(error:unknown):string {
  return error instanceof Error && exposedCodes.has(error.message) ? error.message : "garmin_unavailable";
}
class SupabaseGarminStore implements GarminConnectionStore {
  private readonly c:GarminServerConfig;
  private readonly f:typeof fetch;
  constructor(c:GarminServerConfig,f:typeof fetch) {this.c=c;this.f=f;}
  async command(action:string,owner:string|null,session:string|null,input:Record<string,unknown>) {
    let result:Response;
    try { result=await this.f(`${this.c.supabaseUrl}/rest/v1/rpc/garmin_account_command`,{
      method:"POST",headers:{apikey:this.c.serviceKey,Authorization:`Bearer ${this.c.serviceKey}`,"Content-Type":"application/json"},
      body:JSON.stringify({p_action:action,p_owner:owner,p_session:session,p_input:input}),redirect:"error",signal:AbortSignal.timeout(10000)}); }
    catch {throw new HttpError(503,"garmin_unavailable");}
    const body=object(await result.json());
    if(!result.ok) {
      const code=typeof body.message==="string" && exposedCodes.has(body.message) ? body.message : "garmin_unavailable";
      throw new HttpError(code==="access_required"?403:code==="rate_limited"?429:409,code);
    }
    return body;
  }
}
function service(c:GarminServerConfig,f:typeof fetch) {
  return new GarminConnectionService(new SupabaseGarminStore(c,f),new GarminOAuthClient({
    clientId:c.clientId,clientSecret:c.clientSecret,redirectUri:`${c.supabaseUrl}/functions/v1/garmin-oauth-callback`},f),
    new GarminCipher(c.encryptionKey),{clientId:c.clientId,
      redirectUri:`${c.supabaseUrl}/functions/v1/garmin-oauth-callback`});
}
async function identity(req:Request,c:GarminServerConfig,f:typeof fetch) {
  const authorization=req.headers.get("Authorization");
  if(!authorization?.startsWith("Bearer ")) throw new HttpError(401,"unauthorized");
  const auth=await f(`${c.supabaseUrl}/auth/v1/user`,{headers:{apikey:c.anonKey,Authorization:authorization},
    redirect:"error",signal:AbortSignal.timeout(10000)});
  if(!auth.ok) throw new HttpError(401,"unauthorized");
  const user=object(await auth.json()).id;
  if(typeof user!=="string" || !uuid.test(user)) throw new HttpError(401,"unauthorized");
  let session:unknown;
  // Auth ha verificado el JWT. El claim no verificado no se usa para autorizar.
  // SQL comprueba además que esta sesión pertenezca al usuario y siga existiendo.
  try { const payload=authorization.slice(7).split(".")[1];
    session=JSON.parse(atob(payload.replaceAll("-","+").replaceAll("_","/"))).session_id;
  } catch {throw new HttpError(401,"unauthorized");}
  if(typeof session!=="string" || !uuid.test(session)) throw new HttpError(401,"unauthorized");
  return {user,session};
}
async function requestBody(request:Request) {
  const reader=request.body?.getReader();
  if(!reader) throw new HttpError(400,"invalid_request");
  let text=""; const decoder=new TextDecoder();
  try { while(true) { const {value,done}=await reader.read(); if(done) break;
    text+=decoder.decode(value,{stream:true}); if(text.length>2048) throw new HttpError(413,"request_too_large"); }
    text+=decoder.decode();
  } finally {await reader.cancel().catch(()=>{});}
  try {return object(JSON.parse(text));} catch(error) {if(error instanceof HttpError) throw error;throw new HttpError(400,"invalid_request");}
}
export async function handleGarminConnection(request:Request,c:GarminServerConfig,f:typeof fetch=fetch):Promise<Response> {
  if(request.method==="OPTIONS") return new Response(null,{status:204,headers:cors});
  try {
    if(request.method!=="POST") throw new HttpError(405,"method_not_allowed");
    ready(c);
    const actor=await identity(request,c,f);
    const body=await requestBody(request);
    if(body.expected_user_id!==actor.user) throw new HttpError(409,"account_changed");
    const s=service(c,f);
    if(body.action==="status") return response(await s.status(actor.user,actor.session));
    if(body.action==="begin") return response(await s.begin(actor.user,actor.session));
    if(body.action==="disconnect" && typeof body.generation==="number" && Number.isSafeInteger(body.generation) && body.generation>=0) {
      return response(await s.disconnect(actor.user,actor.session,body.generation));
    }
    throw new HttpError(400,"invalid_request");
  } catch(error) {
    return response({code:error instanceof HttpError?error.message:safeCode(error)},error instanceof HttpError?error.status:503);
  }
}
export async function handleGarminCallback(request:Request,c:GarminServerConfig,f:typeof fetch=fetch):Promise<Response> {
  let status=200, message="Conexión completada. Vuelve a EntrenaOP y pulsa Actualizar estado.";
  try {
    if(request.method!=="GET") throw new HttpError(405,"method_not_allowed");
    ready(c);
    // Edge puede reescribir host/prefijo internamente. El retorno público se fija
    // en configuración; no se deriva de Host ni de cabeceras reenviadas.
    const result=await service(c,f).callback(`${c.supabaseUrl}/functions/v1/garmin-oauth-callback${new URL(request.url).search}`);
    if(result!=="connected") message="La conexión no se ha activado. Vuelve a EntrenaOP para revisar su estado.";
  } catch(error) {
    const original=error instanceof GarminCallbackError?error.cause:error;
    status=original instanceof HttpError?original.status:400;
    // Solo etapa y códigos de una lista cerrada: nunca URL, state, código OAuth,
    // cuenta, cuerpos de Garmin ni el objeto Error/cause con datos privados.
    const code=error instanceof Error && ["invalid_response","invalid_configuration","invalid_ciphertext"].includes(error.message)
      ? error.message : safeCode(error);
    console.warn(JSON.stringify({event:"garmin_callback_failed",
      stage:error instanceof GarminCallbackError?error.stage:"validate_or_claim",code}));
    message=safeCode(error)==="authorization_denied" ? "Has cancelado la autorización. Puedes volver a EntrenaOP." :
      "No se pudo completar la conexión. Vuelve a EntrenaOP y revisa su estado antes de volver a intentarlo.";
  }
  // El dominio estándar de Edge transforma HTML en texto. Devolver texto UTF-8
  // explícito evita código visible y conserva el retorno registrado en Garmin.
  return new Response(`EntrenaOP · Garmin\n\n${message}\n`,{
    status,headers:{"Content-Type":"text/plain; charset=utf-8","Cache-Control":"no-store","Referrer-Policy":"no-referrer",
      "Content-Security-Policy":"default-src 'none'; frame-ancestors 'none'; base-uri 'none'","X-Content-Type-Options":"nosniff"}});
}
