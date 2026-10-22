import {TrainingSyncService} from '../device_training/sync.ts';
import type {TrainingSyncStore} from '../device_training/sync.ts';
import {TrainingDeliveryService,DeliveryFailure} from '../device_training/delivery.ts';
import {SupabaseTrainingStore} from './training_http.ts';
import {GarminTrainingClient} from './training.ts';
import {GarminOAuthClient} from './oauth.ts';
import {GarminCipher} from './cipher.ts';
import {ready,service} from './http.ts';
import type {GarminServerConfig} from './http.ts';

const safeCodes=new Set(['stale_attempt','connection_busy','delivery_needs_review','access_required','connection_changed']);
export async function handleGarminSync(request:Request,c:GarminServerConfig,f:typeof fetch=fetch):Promise<Response>{
  const headers={'Cache-Control':'no-store'};
  try{
    ready(c);
    if(request.method!=='POST')return Response.json({code:'method_not_allowed'},{status:405,headers});
    const token=request.headers.get('authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43,128})$/)?.[1];
    if(!token)return Response.json({code:'unauthorized'},{status:401,headers});
    const command:TrainingSyncStore['command']=async(action,input)=>{
      const response=await f(`${c.supabaseUrl}/rest/v1/rpc/garmin_training_sync_command`,{method:'POST',
        headers:{apikey:c.serviceKey,Authorization:`Bearer ${c.serviceKey}`,'Content-Type':'application/json'},
        body:JSON.stringify({p_action:action,p_input:input}),redirect:'error',signal:AbortSignal.timeout(15000)});
      const data=await response.json();
      if(!response.ok)throw new DeliveryFailure(safeCodes.has(data?.message)?data.message:'garmin_unavailable');
      if(!data||typeof data!=='object'||Array.isArray(data))throw new DeliveryFailure('garmin_unavailable');
      return data;
    };
    if(!(await command('authorize',{token})).authorized)return Response.json({code:'unauthorized'},{status:401,headers});
    await command('scan',{});
    let processed=0;
    const deadline=Date.now()+45000;
    // Bucle acotado: una invocación no acapara la cuenta ni los límites Edge.
    while(processed<4&&Date.now()<deadline){
      const job=await command('take',{});if(!job.id)break;
      const raw=new SupabaseTrainingStore(c,f);
      const deliveryStore={command:(action: string,who:Parameters<typeof raw.command>[1],input:Record<string,unknown>)=>
        raw.command(action,who,{...input,auto_job:job.id,auto_lease:job.lease})};
      const gateway=new GarminTrainingClient(f),cipher=new GarminCipher(c.encryptionKey);
      const account=new GarminOAuthClient({clientId:c.clientId,clientSecret:c.clientSecret,
        redirectUri:`${c.supabaseUrl}/functions/v1/garmin-oauth-callback`},f);
      const release=(owner:string)=>service(c,f).finishPendingDisconnect(owner);
      const delivery=new TrainingDeliveryService(deliveryStore,gateway,account,cipher,Date.now,release);
      await new TrainingSyncService({command},delivery,gateway,account,cipher,Date.now,release).run(job);
      processed++;
    }
    return Response.json({processed},{headers});
  }catch{
    console.warn(JSON.stringify({event:'garmin_training_sync_failed',code:'worker_unavailable'}));
    return Response.json({code:'worker_unavailable'},{status:503,headers});
  }
}
