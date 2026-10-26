import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Decoder,Stream} from '@garmin/fitsdk';
import {handleGarminCiq,ciqHash,ciqCode,ciqExport} from '../_shared/garmin/ciq_http.ts';
const owner='10000000-0000-4000-8000-000000000001', session='20000000-0000-4000-8000-000000000001';
const id='30000000-0000-4000-8000-000000000001', credential='eopciq_'+'a'.repeat(43);
const config={environment:'DEVELOPMENT',supabaseUrl:'https://sxbxfjqgoddzhtcyhalw.supabase.co',anonKey:'anon',serviceKey:'server',
  clientId:'',clientSecret:'',encryptionKey:''};
const userJwt='a.'+btoa(JSON.stringify({session_id:session,aal:'aal1'}))+'.signature';
function request(path:string,body?:unknown,token?:string) {
  return new Request(config.supabaseUrl+'/functions/v1/garmin-ciq/'+path,{method:body===undefined?'GET':'POST',
    headers:{...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
}
function exported():any {return {id,serial:1000000000,created_at:'2026-10-26T12:00:00Z',revision:'a'.repeat(64),scheduled_id:id,
  snapshot:{sport:'strength',source:'coach',name:'Sesión propia',date:'2026-10-26',description:'Notas',blocks:[{
    order_index:0,format:'straight_sets',rounds:1,rest_after_seconds:0,time_cap_seconds:null,items:[{
      order_index:0,exercise_code:null,exercise_name:'Mi dominada',notes:null,
      sets:[{order_index:0,target_reps:6,target_load_kg:7.5,rest_after_seconds:90}]}]}]}};}
function mock(result:(body:any)=>unknown) {
  const calls:any[]=[];
  const f=(async(url:any,init:any)=>{
    if(String(url).endsWith('/auth/v1/user')) return Response.json({id:owner});
    assert.equal(init.headers.Authorization,'Bearer server');
    const body=JSON.parse(init.body);calls.push(body);return Response.json(result(body));
  }) as typeof fetch;
  return {f,calls};
}
test('CIQ queda cerrado fuera de Dev y sin credencial no consulta recetas',async()=>{
  let calls=0;const f=(async()=>{calls++;throw Error('No llamar');})as typeof fetch;
  assert.equal((await handleGarminCiq(request('watch',{action:'begin'}),{...config,environment:'PRODUCTION'},f)).status,503);
  assert.equal((await handleGarminCiq(request('fit/'+id),config,f)).status,401);
  assert.equal((await handleGarminCiq(request('account',{action:'account'}),config,f)).status,401);
  assert.equal(calls,0);
});
test('inicio anónimo genera secretos independientes y solo persiste hashes',async()=>{
  const {f,calls}=mock(()=>({id,status:'pending',pair_until:'2026-10-26T12:10:00Z'}));
  const response=await handleGarminCiq(request('watch',{action:'begin',owner_id:owner}),config,f);
  const body=await response.json();assert.equal(response.status,200);
  assert.match(body.credential,/^eopciq_[A-Za-z0-9_-]{43}$/);assert.match(body.code,/^[A-Z2-7]{8}$/);
  assert.equal(calls[0].p_owner,null);assert.equal(calls[0].p_session,null);
  assert.equal(calls[0].p_input.token_hash,await ciqHash('token',body.credential));
  assert.equal(calls[0].p_input.code_hash,await ciqHash('code',body.code));
  assert.ok(!JSON.stringify(calls).includes(body.credential));
});
test('aprobación usa la cuenta verificada, sesión viva y código normalizado; no acepta otro propietario',async()=>{
  const {f,calls}=mock(()=>({linked:true}));
  assert.equal(ciqCode('abcd-ef23'),'ABCDEF23');
  const bad=await handleGarminCiq(request('account',{action:'approve',expected_user_id:id,code:'ABCDEF23',id},userJwt),config,f);
  assert.equal(bad.status,409);assert.equal(calls.length,0);
  const ok=await handleGarminCiq(request('account',{action:'approve',expected_user_id:owner,code:'abcd ef23',id,owner_id:id},userJwt),config,f);
  assert.equal(ok.status,200);assert.equal(calls[0].p_owner,owner);assert.equal(calls[0].p_session,session);
  assert.equal(calls[0].p_input.code_hash,await ciqHash('code','ABCDEF23'));
});
test('el manifiesto no entrega snapshots, secretos o archivos incompatibles ni acepta recetas del reloj',async()=>{
  const incompatible=exported();incompatible.snapshot.blocks[0].format='superset';
  const {f,calls}=mock(()=>({complete:true,entries:[exported(),incompatible],blocked:0,valid_until:'2027-01-01Z'}));
  const response=await handleGarminCiq(request('watch',{action:'manifest',snapshot:{name:'Malicioso'},owner_id:id},credential),config,f);
  const body=await response.json();assert.equal(body.entries.length,1);assert.equal(body.blocked,1);
  assert.equal(body.entries[0].name,'Sesión propia');assert.match(body.entries[0].fit_name,/1000000000$/);
  assert.ok(!JSON.stringify(body).includes('snapshot'));assert.ok(!JSON.stringify(body).includes(credential));
  assert.deepEqual(Object.keys(calls[0].p_input),['token_hash']);
});
test('cada descarga consulta autorización actual y conserva bytes e identidad entre reintentos',async()=>{
  const {f,calls}=mock(()=>exported());
  const a=await handleGarminCiq(request('fit/'+id,undefined,credential),config,f);
  const b=await handleGarminCiq(request('fit/'+id,undefined,credential),config,f);
  const bytes=new Uint8Array(await a.arrayBuffer());assert.deepEqual(bytes,new Uint8Array(await b.arrayBuffer()));
  assert.equal(calls.length,2);assert.equal(calls[0].p_action,'download');assert.equal(calls[0].p_input.id,id);
  const decoder=new Decoder(Stream.fromByteArray(bytes));assert.equal(decoder.checkIntegrity(),true);
  const messages=decoder.read().messages;assert.equal(messages.workoutMesgs[0].wktName,'Sesión propia · 1000000000');
  assert.equal(messages.exerciseTitleMesgs[0].wktStepName,'Mi dominada');assert.equal(messages.workoutStepMesgs[1].durationTime,90);
});
test('revocación, revisión obsoleta y respuestas parciales nunca sirven FIT o manifiesto válido',async()=>{
  for(const error of ['link_revoked','stale_prescription','source_not_available']){
    const {f}=mock(()=>({error}));const r=await handleGarminCiq(request('fit/'+id,undefined,credential),config,f);
    assert.equal(r.status,403);assert.equal((await r.json()).code,error);
  }
  const {f}=mock(()=>({complete:false,entries:[exported()]}));
  assert.equal((await handleGarminCiq(request('watch',{action:'manifest'},credential),config,f)).status,503);
  assert.throws(()=>ciqExport({...exported(),serial:0}));
});

test('la comprobación ligera de cambios no entrega nombres, recetas o credenciales',async()=>{
  const {f}=mock(()=>({complete:true,entries:[exported()],blocked:0}));
  const a=await (await handleGarminCiq(request('watch',{action:'changes'},credential),config,f)).json();
  const b=await (await handleGarminCiq(request('watch',{action:'manifest'},credential),config,f)).json();
  assert.equal(a.revision,b.revision);assert.equal(a.count,1);
  assert.deepEqual(Object.keys(a).sort(),['blocked','count','revision']);
});
