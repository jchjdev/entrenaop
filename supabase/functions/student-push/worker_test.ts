import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createPushWorker,createFcmSender,type Rpc,type ServiceAccount} from './worker.ts';

const secret='a'.repeat(64);
const serverKey='test-service-role-key'.repeat(3);
const request=()=>new Request('https://worker.invalid',{method:'POST',headers:{Authorization:'Bearer '+serverKey,'X-EntrenaOP-Push-Worker':secret}});
const job={installation_id:'installation',claim_id:'lease',generation:2,binding_id:'binding',token:'private-destination'};

test('rechaza acceso público y permanece inerte sin configurar',async()=>{
  let calls=0;
  const worker=createPushWorker({enabled:false,secret,serviceRoleKey:serverKey,projectId:'push-fixture',rpc:async()=>{calls++;return null;},send:async()=>{calls++;return 'sent';}});
  assert.equal((await worker(new Request('https://worker.invalid',{method:'POST'}))).status,401);
  assert.equal((await worker(new Request('https://worker.invalid',{method:'POST',headers:{Authorization:'Bearer regular-client-jwt','X-EntrenaOP-Push-Worker':secret}}))).status,401);
  assert.deepEqual(await (await worker(request())).json(),{disabled:true});
  assert.equal(calls,0);
});
test('no reclama direcciones si el proyecto no coincide',async()=>{
  let calls=0;
  const worker=createPushWorker({enabled:true,secret,serviceRoleKey:serverKey,projectId:'push-fixture',rpc:async()=>{calls++;return {enabled:true,firebase_project_id:'other-project'};},send:async()=>{throw Error('No enviar');}});
  assert.equal((await worker(request())).status,503);assert.equal(calls,1);
});
test('revalida lease antes de enviar y solo devuelve contadores',async()=>{
  const calls:{name:string;params:unknown}[]=[];
  const rpc:Rpc=async(name,params)=>{
    calls.push({name,params});
    if(name==='get_student_push_worker_configuration') return {enabled:true,firebase_project_id:'push-fixture'};
    if(name==='claim_student_push_jobs') return [job];
    if(name==='prepare_student_push_job') return false;
    return null;
  };
  const worker=createPushWorker({enabled:true,secret,serviceRoleKey:serverKey,projectId:'push-fixture',rpc,send:async()=>{throw Error('No enviar asociación obsoleta');}});
  const result=await worker(request());
  assert.deepEqual(await result.json(),{sent:0,retry:0,invalid:0,skipped:1,errors:0});
  assert.deepEqual(calls.at(-1)?.params,{p_id:'installation',p_claim:'lease',p_generation:2,p_binding:'binding',p_outcome:'skipped'});
});
test('fallo de red conserva reintento y no retira el dispositivo',async()=>{
  const calls:string[]=[];
  const rpc:Rpc=async(name)=>{calls.push(name);return name==='get_student_push_worker_configuration' ?
    {enabled:true,firebase_project_id:'push-fixture'} : name==='claim_student_push_jobs' ? [job] : true;};
  const worker=createPushWorker({enabled:true,secret,serviceRoleKey:serverKey,projectId:'push-fixture',rpc,send:async()=>{throw Error('Offline');}});
  assert.equal((await (await worker(request())).json()).retry,1);
  assert.ok(!calls.includes('retire_invalid_push_device'));
});
test('proveedor recibe FID, payload genérico y credencial OAuth firmada',async()=>{
  const key=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
  const der=await crypto.subtle.exportKey('pkcs8',key.privateKey);
  const pem='-----BEGIN PRIVATE KEY-----\n'+Buffer.from(der).toString('base64')+'\n-----END PRIVATE KEY-----';
  const account:ServiceAccount={type:'service_account',project_id:'push-fixture',client_email:'sender@push-fixture.iam.gserviceaccount.com',private_key:pem};
  let requests=0;
  const sender=createFcmSender(account,async(input,init)=>{
    requests++;
    if(String(input)==='https://oauth2.googleapis.com/token') {
      const jwt=new URLSearchParams(init?.body as URLSearchParams).get('assertion')!;
      const [head,body,sig]=jwt.split('.');const claims=JSON.parse(Buffer.from(body,'base64url').toString());
      assert.equal(claims.aud,'https://oauth2.googleapis.com/token');assert.equal(claims.iss,account.client_email);
      assert.equal(claims.scope,'https://www.googleapis.com/auth/firebase.messaging');
      assert.ok(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',key.publicKey,Buffer.from(sig,'base64url'),new TextEncoder().encode(head+'.'+body)));
      return Response.json({access_token:'test-access',expires_in:3600});
    }
    assert.equal(String(input),'https://fcm.googleapis.com/v1/projects/push-fixture/messages:send');
    const data=JSON.parse(init?.body as string);
    assert.equal(data.message.fid,'test-fid');assert.deepEqual(data.message.data,{type:'student_notices'});
    assert.deepEqual(data.message.notification,{title:'EntrenaOP',body:'Tienes novedades pendientes.'});
    assert.equal((init?.headers as Record<string,string>).Authorization,'Bearer test-access');
    return Response.json({error:{details:[{errorCode:'UNREGISTERED'}]}},{status:404});
  });
  assert.equal(await sender('test-fid'),'invalid');
  assert.equal(await sender('test-fid'),'invalid');assert.equal(requests,3);
});
