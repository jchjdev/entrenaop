import {test} from 'node:test';
import assert from 'node:assert/strict';
import {handleActivityIngest,handleActivityUser} from '../_shared/garmin/activity_http.ts';
import {GarminCipher} from '../_shared/garmin/cipher.ts';
import type {ActivityReturnConfig} from '../_shared/garmin/activity_http.ts';
const c: ActivityReturnConfig={environment:'DEVELOPMENT',supabaseUrl:'https://sxbxfjqgoddzhtcyhalw.supabase.co',
  anonKey:'fixture-anon',serviceKey:'fixture-service',clientId:'fixture-client',clientSecret:'fixture-secret',
  encryptionKey:Buffer.alloc(32,7).toString('base64url'),webhookSecret:'a'.repeat(43)};
const notification={activityFiles:[{userId:'provider',activityId:12345,activityName:'Sintética',summaryId:'fixture-file',fileType:'FIT',
  callbackURL:'https://apis.garmin.com/wellness-api/rest/activityFile?id=fixture&token=fixture'}]};
function webhook(payload:unknown=notification,key=c.webhookSecret) {
  return new Request(`${c.supabaseUrl}/functions/v1/garmin-activity-ingest?key=${key}`,{method:'POST',body:JSON.stringify(payload)});
}
test('ACK requiere guardar la notificación; cifra la URL y deja la descarga fuera del receptor',async()=>{
  let saved: Record<string,unknown>|undefined;
  let work:Promise<unknown>|undefined;
  const store={command:async(action:string,_owner:string|null,_session:string|null,input:Record<string,unknown>)=>{
    if(action==='enqueue') { saved=input;return {queued:true}; }
    assert.equal(action,'pending');return {ids:[]};
  }};
  const response=await handleActivityIngest(webhook(),c,async()=>{throw new Error('No network');},p=>{work=p;},store);
  assert.equal(response.status,200);assert.ok(saved);
  assert.ok(!JSON.stringify(saved).includes('activityFile?'));
  const decoded=await new GarminCipher(c.encryptionKey).open(saved.callback_cipher as string,`activity-callback:${saved.id}`);
  assert.equal(decoded,notification.activityFiles[0].callbackURL);
  await work;
});
test('no confirma entrega si falla el checkpoint y rechaza key incorrecta o repetida',async()=>{
  let calls=0;
  const store={command:async()=>{calls++;throw new Error('offline');}};
  assert.equal((await handleActivityIngest(webhook(),c,fetch,()=>{},store)).status,409);
  assert.equal((await handleActivityIngest(webhook(notification,'wrong'),c,fetch,()=>{},store)).status,401);
  assert.equal((await handleActivityIngest(new Request(`${c.supabaseUrl}/?key=${c.webhookSecret}&key=${c.webhookSecret}`,{method:'POST'}),c,fetch,()=>{},store)).status,401);
  assert.equal(calls,1);
});
test('no descarga URLs ajenas y no habilita producción',async()=>{
  const bad={activityFiles:[{...notification.activityFiles[0],callbackURL:'https://example.invalid/private'}]};
  assert.notEqual((await handleActivityIngest(webhook(bad),c)).status,200);
  assert.notEqual((await handleActivityIngest(webhook(),{...c,environment:'PRODUCTION'})).status,200);
});
test('no redondea un identificador numérico fuera de la precisión JSON',async()=>{
  const bad={activityFiles:[{...notification.activityFiles[0],activityId:Number.MAX_SAFE_INTEGER+1}]};
  assert.equal((await handleActivityIngest(webhook(bad),c)).status,400);
});
test('acepta la capacidad en la ruta que Garmin conserva al guardar el receptor',async()=>{
  const store={command:async()=>({queued:true})};
  const response=await handleActivityIngest(new Request(`${c.supabaseUrl}/functions/v1/garmin-activity-ingest/${c.webhookSecret}`,
    {method:'POST',body:JSON.stringify({activityFiles:[]})}),c,fetch,()=>{},store);
  assert.equal(response.status,200);
});
test('identidad del alumno procede de Auth y nunca del cuerpo ni del JWT sin verificar',async()=>{
  const owner='10000000-0000-4000-8000-000000000001',session='20000000-0000-4000-8000-000000000001';
  const jwt=`fixture.${Buffer.from(JSON.stringify({session_id:session})).toString('base64url')}.fixture`;
  const requests: Record<string,unknown>[]=[];
  const f:typeof fetch=async(url,init)=>{
    if(String(url).endsWith('/auth/v1/user')) return Response.json({id:owner});
    requests.push(JSON.parse(String(init?.body))); return Response.json({activities:[],candidates:[],problems:[]});
  };
  const request=(expected:string)=>new Request(c.supabaseUrl,{method:'POST',headers:{Authorization:`Bearer ${jwt}`},
    body:JSON.stringify({action:'list',expected_user_id:expected,p_owner:'forged'})});
  assert.equal((await handleActivityUser(request('stranger'),c,f)).status,409);
  assert.equal(requests.length,0);
  assert.equal((await handleActivityUser(request(owner),c,f)).status,200);
  assert.equal(requests[0].p_owner,owner);assert.equal(requests[0].p_session,session);
  assert.equal((await handleActivityUser(request(owner),c,async()=>new Response(null,{status:401}))).status,401);
});
