import {TrainingDeliveryService,DeliveryFailure} from "../device_training/delivery.ts";
import type {DeliveryActor,TrainingDeliveryStore} from "../device_training/delivery.ts";
import {GarminTrainingClient} from "./training.ts";
import {GarminOAuthClient} from "./oauth.ts";
import {GarminCipher} from "./cipher.ts";
import {ready,identity,requestBody,HttpError,service} from "./http.ts";
import type {GarminServerConfig} from "./http.ts";
const codes=new Set(["account_changed","access_required","source_not_available","source_not_allowed","stale_prescription",
  "unsupported_prescription","invalid_prescription","connection_required","delivery_needs_review","connection_busy","rate_limited",
  "provider_rejected","provider_unavailable","permission_denied","reauthorization_required","invalid_provider_response",
  "schedule_not_confirmed","delivery_uncertain","connection_changed","stale_attempt"]);
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const headers={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, x-client-info, content-type",
 "Access-Control-Allow-Methods":"POST, OPTIONS","Cache-Control":"no-store"};
class SupabaseTrainingStore implements TrainingDeliveryStore {
  private readonly c:GarminServerConfig;private readonly f:typeof fetch;
  constructor(c:GarminServerConfig,f:typeof fetch){this.c=c;this.f=f;}
  async command(action:string,who:DeliveryActor,input:Record<string,unknown>){
    const result=await this.f(`${this.c.supabaseUrl}/rest/v1/rpc/garmin_training_command`,{method:"POST",
      headers:{apikey:this.c.serviceKey,Authorization:`Bearer ${this.c.serviceKey}`,"Content-Type":"application/json"},
      body:JSON.stringify({p_action:action,p_actor:who.actor,p_owner:who.owner,p_session:who.session,p_input:input}),
      redirect:"error",signal:AbortSignal.timeout(10000)});
    const data=await result.json();
    if(!result.ok)throw new DeliveryFailure(typeof data?.message==="string"&&codes.has(data.message)?data.message:"garmin_unavailable");
    if(!data||typeof data!=="object"||Array.isArray(data))throw new DeliveryFailure("garmin_unavailable");
    return data as Record<string,unknown>;
  }
}
export async function handleGarminTraining(request:Request,c:GarminServerConfig,f:typeof fetch=fetch):Promise<Response>{
  if(request.method==="OPTIONS")return new Response(null,{status:204,headers});
  try{
    if(request.method!=="POST")throw new HttpError(405,"method_not_allowed");
    ready(c);const actor=await identity(request,c,f),body=await requestBody(request);
    if(body.expected_user_id!==actor.user)throw new HttpError(409,"account_changed");
    const owner=body.client_id??actor.user;
    if(typeof owner!=="string"||!uuid.test(owner))throw new HttpError(400,"invalid_request");
    if(owner!==actor.user&&actor.aal!=="aal2")throw new HttpError(403,"mfa_required");
    const who={actor:actor.user,owner,session:actor.session};
    const delivery=new TrainingDeliveryService(new SupabaseTrainingStore(c,f),new GarminTrainingClient(f),
      new GarminOAuthClient({clientId:c.clientId,clientSecret:c.clientSecret,redirectUri:`${c.supabaseUrl}/functions/v1/garmin-oauth-callback`},f),
      new GarminCipher(c.encryptionKey),Date.now,(target)=>service(c,f).finishPendingDisconnect(target));
    let result:unknown;
    if(body.action==="list")result=await delivery.list(who);
    else if((body.action==="preview"||body.action==="send")&&typeof body.scheduled_id==="string"&&uuid.test(body.scheduled_id)){
      if(body.action==="preview")result=await delivery.preview(who,body.scheduled_id);
      else{
        if(typeof body.revision!=="string"||!/^[0-9a-f]{64}$/.test(body.revision))throw new HttpError(400,"invalid_request");
        result=await delivery.send(who,body.scheduled_id,body.revision);
      }
    }else throw new HttpError(400,"invalid_request");
    return Response.json(result,{headers});
  }catch(error){
    const code=error instanceof HttpError?error.message:error instanceof Error&&codes.has(error.message)?error.message:"garmin_unavailable";
    const status=error instanceof HttpError?error.status:code==="rate_limited"?429:
      ["access_required","permission_denied","account_changed","source_not_allowed"].includes(code)?403:409;
    console.warn(JSON.stringify({event:"garmin_training_failed",code}));
    return Response.json({code},{status,headers});
  }
}
