import {test} from 'node:test';
import assert from 'node:assert/strict';
import {TrainingSyncService} from '../_shared/device_training/sync.ts';
import {DeliveryFailure} from '../_shared/device_training/delivery.ts';
import {GarminTrainingClient} from '../_shared/garmin/training.ts';
import {handleGarminSync} from '../_shared/garmin/sync_http.ts';
import type {GarminServerConfig} from '../_shared/garmin/http.ts';
const snapshot={name:'Carrera sintética',date:'2026-10-27',source:'coach',blocks:[{order_index:0,name:'Carrera',format:'running',rounds:1,
  rest_after_seconds:0,time_cap_seconds:null,items:[{order_index:0,exercise_id:'20000000-0000-4000-8000-000000000004',notes:null,
    sets:[{order_index:0,target_duration_seconds:120,rest_after_seconds:0}]}]}]};
const job={id:'job',owner:'owner',scheduled:'scheduled',lease:'lease',operation:'change',target:{mode:'sync',snapshot,revision:'a'.repeat(64)}};
function fixture(){
  const calls:string[]=[],commands:Record<string,unknown>[]=[];
  const grant={accessToken:'ACCESS',refreshToken:'REFRESH',expiresInSeconds:3600,refreshExpiresInSeconds:7200,scope:'CONNECT_WRITE'};
  const claim={generation:1,tokens_cipher:'SEALED',access_expires_at:'2099-01-01',refresh_expires_at:'2099-01-02',garmin_user_id:'garmin',workout_id:123,schedule_id:456};
  let fail:string|undefined,failCommand:string|undefined;
  const store={command:async(action:string,input:Record<string,unknown>)=>{
    calls.push(action);commands.push(input);
    if(action===failCommand)throw new DeliveryFailure('stale_attempt');
    return action==='claim_change'?claim:{};
  }};
  const gateway={update:async(_t:string,id:number)=>{calls.push(`PUT:${id}`);if(fail)throw new DeliveryFailure(fail,true);},
    updateSchedule:async(_t:string,id:number)=>{calls.push(`DATE:${id}`);},removeSchedule:async(_t:string,id:number)=>{calls.push(`DELETE_DATE:${id}`);},
    remove:async(_t:string,id:number)=>{calls.push(`DELETE:${id}`);}};
  const account={refresh:async()=>{calls.push('refresh');if(fail==='refresh')throw new DeliveryFailure('provider_unavailable',true);return grant;},
    userId:async()=> 'garmin',permissions:async()=>({canReadActivities:true,canSendWorkouts:true})};
  const cipher={open:async<T>()=>grant as T,seal:async()=> 'ROTATED'};
  let sent='sent';let sentError:string|undefined;
  const delivery={send:async()=>{calls.push('send');return {status:sent,error_code:sentError};}};
  const service=new TrainingSyncService(store,delivery,gateway,account,cipher,()=>Date.parse('2026-10-22'));
  return {calls,commands,claim,service,setFail:(code:string)=>fail=code,setCommandFail:(code:string)=>failCommand=code,setSent:(value:string,code?:string)=>{sent=value;sentError=code;}};
}
test('cambio conserva IDs y guarda la revisión después de las dos escrituras',async()=>{
 const f=fixture();await f.service.run(job);
 assert.deepEqual(f.calls,['claim_change','permissions','before_write','PUT:123','before_write','DATE:456','save_change','finish','release_change']);
 assert.equal(f.commands.at(-2)?.outcome,'done');
});
test('cancelación retira primero la cita y después únicamente la sesión propia',async()=>{
 const f=fixture();await f.service.run({...job,target:{mode:'cancel'}});
 assert.ok(f.calls.indexOf('DELETE_DATE:456')<f.calls.indexOf('DELETE:123'));
 assert.equal(f.calls.includes('PUT:123'),false);assert.equal(f.commands.at(-2)?.outcome,'done');
});
test('cambio incierto se reintenta sobre referencias conocidas sin POST',async()=>{
 const f=fixture();f.setFail('provider_unavailable');await f.service.run(job);
 assert.equal(f.commands.at(-2)?.outcome,'retry');assert.equal(f.commands.at(-2)?.write_pending,true);
 assert.equal(f.calls.includes('send'),false);assert.equal(f.calls.includes('save_change'),false);
});
test('cancelación concurrente impide la siguiente escritura',async()=>{
 const f=fixture();f.setCommandFail('before_write');await f.service.run(job);
 assert.equal(f.calls.includes('PUT:123'),false);assert.equal(f.calls.includes('save_change'),false);
});
test('refresh se guarda cifrado antes de escribir en Garmin',async()=>{
 const f=fixture();f.claim.access_expires_at='2020-01-01';await f.service.run(job);
 assert.ok(f.calls.indexOf('rotate')<f.calls.indexOf('PUT:123'));
 assert.ok(f.commands.some(input=>input.tokens_cipher==='ROTATED'));
});
test('refresh ambiguo exige revisión y frena la concesión',async()=>{
 const f=fixture();f.claim.access_expires_at='2020-01-01';f.setFail('refresh');await f.service.run(job);
 assert.equal(f.commands.at(-2)?.outcome,'review');assert.equal(f.commands.at(-2)?.refresh_uncertain,true);
 assert.equal(f.calls.includes('PUT:123'),false);
});
test('la creación reutiliza el caso de uso existente y aparca su POST incierto',async()=>{
 const f=fixture();f.setSent('uncertain');await f.service.run({...job,operation:'create'});
 assert.deepEqual(f.calls,['send','finish']);assert.equal(f.commands[0].outcome,'review');
});
test('históricos y efectos desconocidos no producen escrituras',async()=>{
 for(const mode of ['hold','review']){const f=fixture();await f.service.run({...job,target:{mode}});
  assert.deepEqual(f.calls,['finish']);assert.equal(f.commands[0].outcome,mode==='hold'?'done':'review');}
});
test('transporte PUT y DELETE usa los recursos oficiales sin crear copias',async()=>{
 const requests:{url:string;method:string;body:any}[]=[];
 const client=new GarminTrainingClient(async(url,init)=>{requests.push({url:String(url),method:init?.method??'GET',body:init?.body?JSON.parse(String(init.body)):null});return (init?.method??'GET')==='GET'?Response.json([{workoutId:123,scheduleId:456,date:'2026-10-27'}]):new Response(null,{status:204});});
 const p={name:'Carrera',description:'',date:'2026-10-27',source:'coach' as const,steps:[{kind:'run' as const,measure:'seconds' as const,value:120,description:'Carrera',pace:null}]};
 await client.update('token',123,p);await client.updateSchedule('token',456,123,p.date);await client.removeSchedule('token',456);await client.remove('token',123);
 assert.deepEqual(requests.map(x=>[new URL(x.url).pathname,x.method]),[
  ['/training-api/workout/v2/123','PUT'],['/training-api/schedule/456','PUT'],['/training-api/schedule','GET'],['/training-api/schedule/456','DELETE'],['/training-api/workout/v2/123','DELETE']]);
 assert.equal(requests[0].body.workoutId,123);assert.deepEqual(requests[1].body,{scheduleId:456,workoutId:123,date:p.date});
});
test('DELETE de un recurso ya retirado es idempotente; PUT ausente exige revisión',async()=>{
 const client=new GarminTrainingClient(async()=>new Response(null,{status:404}));
 await client.remove('token',123);await client.removeSchedule('token',456);
 await assert.rejects(client.updateSchedule('token',456,123,'2026-10-27'),/provider_missing/);
});
const config:GarminServerConfig={environment:'DEVELOPMENT',supabaseUrl:'https://sxbxfjqgoddzhtcyhalw.supabase.co',anonKey:'anon',serviceKey:'SERVICE',clientId:'id',clientSecret:'secret',encryptionKey:'key'};
test('trabajador rechaza invocaciones sin Bearer y nunca acepta otro entorno',async()=>{
 let calls=0;const fetcher=async()=>{calls++;return Response.json({});};
 assert.equal((await handleGarminSync(new Request('https://fixture',{method:'POST'}),config,fetcher)).status,401);
 assert.equal((await handleGarminSync(new Request('https://fixture',{method:'POST'}),{...config,environment:'PRODUCTION'},fetcher)).status,503);
 assert.equal(calls,0);
});
test('hash no autorizado no puede examinar ni reclamar la cola',async()=>{
 const actions:string[]=[];
 const response=await handleGarminSync(new Request('https://fixture',{method:'POST',headers:{Authorization:`Bearer ${'a'.repeat(43)}`}}),config,async(_url,init)=>{
  actions.push(JSON.parse(String(init?.body)).p_action);return Response.json({authorized:false});});
 assert.equal(response.status,401);assert.deepEqual(actions,['authorize']);
});
test('invocación autenticada usa solo trabajos del servidor y limita el lote',async()=>{
 let takes=0,finished=0;
 const response=await handleGarminSync(new Request('https://fixture',{method:'POST',headers:{Authorization:`Bearer ${'a'.repeat(43)}`},
  body:JSON.stringify({owner:'attacker',action:'delete_everything'})}),{...config,encryptionKey:'A'.repeat(43)},async(url,init)=>{
  assert.equal(new URL(String(url)).host,'sxbxfjqgoddzhtcyhalw.supabase.co');
  const body=JSON.parse(String(init?.body));
  if(body.p_action==='authorize')return Response.json({authorized:true});
  if(body.p_action==='take'){takes++;return Response.json({...job,id:`job-${takes}`,target:{mode:'hold'}});}
  if(body.p_action==='finish'){finished++;assert.equal(body.p_input.job_id,`job-${finished}`);assert.equal(body.p_input.job_lease,'lease');}
  return Response.json({});
 });
 assert.equal(response.status,200);assert.deepEqual(await response.json(),{processed:4});assert.equal(takes,4);assert.equal(finished,4);
});


test('un rechazo permanente del alta conserva la causa y no vuelve al bucle automático',async()=>{
 for(const code of ['provider_rejected','permission_denied','reauthorization_required','connection_changed','invalid_provider_response']){
  const f=fixture();f.setSent('failed',code);await f.service.run({...job,operation:'create'});
  assert.equal(f.commands[0].outcome,'review');assert.equal(f.commands[0].code,code);
  assert.deepEqual(f.calls,['send','finish']);
 }
});
test('un fallo transitorio del alta conserva la causa para el reintento seguro',async()=>{
 for(const code of ['rate_limited','provider_unavailable','garmin_unavailable']){
  const f=fixture();f.setSent('failed',code);await f.service.run({...job,operation:'create'});
  assert.equal(f.commands[0].outcome,'retry');assert.equal(f.commands[0].code,code);
 }
});
test('no confirma el cambio si Garmin no devuelve una única referencia en la nueva fecha',async()=>{
 for(const rows of [[],[{workoutId:123,scheduleId:999,date:'2026-10-27'}],
  [{workoutId:123,scheduleId:456,date:'2026-10-26'}],
  [{workoutId:123,scheduleId:456,date:'2026-10-27'},{workoutId:123,scheduleId:457,date:'2026-10-27'}]]){
  const methods:string[]=[];
  const client=new GarminTrainingClient(async(_url,init)=>{methods.push(init?.method??'GET');
   return init?.method==='PUT'?new Response(null,{status:204}):Response.json(rows);});
  await assert.rejects(client.updateSchedule('token',456,123,'2026-10-27'),/schedule_not_confirmed/);
  assert.deepEqual(methods,['PUT','GET']);
 }
});
