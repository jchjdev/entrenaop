import test from 'node:test';
import assert from 'node:assert/strict';
import {handleAppleTraining} from '../_shared/apple_training/http.ts';
const config={url:'https://sxbxfjqgoddzhtcyhalw.supabase.co',key:'PUBLIC_ANON_FIXTURE',enabled:true};
const request=(body:unknown,authorized=true)=>new Request('https://local/apple-training',{method:'POST',headers:authorized?{Authorization:'Bearer USER_FIXTURE'}:{},body:JSON.stringify(body)});
const source={name:'Series',description:'Entrenamiento',date:'2026-10-29',source:'coach',blocks:[{order_index:0,name:'Carrera',rounds:1,rest_after_seconds:0,time_cap_seconds:null,format:'running',items:[{order_index:0,exercise_id:'20000000-0000-4000-8000-000000000004',notes:'Carrera',sets:[{order_index:0,target_duration_seconds:120,target_reps:null,target_distance_meters:null,target_load_kg:null,target_rpe:null,target_rir:null,target_pace_min_seconds_per_km:300,target_pace_max_seconds_per_km:360,rest_after_seconds:0,recovery_type:'walking',recovery_duration_seconds:30,recovery_distance_meters:null}]}]}]};
test('Sin sesión, deshabilitado y fuera de Dev no llaman al servidor',async()=>{
 let calls=0;const f:typeof fetch=async()=>{calls++;return Response.json({});};
 assert.equal((await handleAppleTraining(request({action:'list',owner:'u'},false),config,f)).status,401);
 assert.equal((await handleAppleTraining(request({action:'list',owner:'u'}),{...config,enabled:false},f)).status,503);
 assert.equal((await handleAppleTraining(request({action:'list',owner:'u'}),{...config,url:'https://production.invalid'},f)).status,503);assert.equal(calls,0);
});
test('Solo la receta del servidor autoriza la traducción y se conserva el bearer',async()=>{
 const f:typeof fetch=async(_url,init)=>{assert.equal(new Headers(init?.headers).get('Authorization'),'Bearer USER_FIXTURE');assert.equal(new Headers(init?.headers).get('apikey'),'PUBLIC_ANON_FIXTURE');const b=JSON.parse(init?.body as string);assert.deepEqual(b,{p_owner:'owner',p_action:'preview',p_input:{scheduled_id:'s'}});return Response.json({snapshot:source,revision:'a'.repeat(64)});};
 const response=await handleAppleTraining(request({owner:'owner',action:'preview',input:{scheduled_id:'s'},prescription:{name:'forged'}}),config,f);
 const data=await response.json();assert.equal(response.status,200);assert.equal(data.prescription.name,'Series');assert.equal(data.prescription.steps.length,2);assert.equal(data.prescription.steps[1].kind,'walk');assert.equal(data.snapshot,undefined);
});
test('Una pauta incompatible no produce una traducción parcial',async()=>{
 const response=await handleAppleTraining(request({owner:'owner',action:'preview'}),config,async()=>Response.json({snapshot:{...source,blocks:[]},revision:'a'.repeat(64)}));
 assert.equal(response.status,409);assert.equal((await response.json()).code,'unsupported_prescription');
});
test('La respuesta no filtra detalles SQL ni credenciales de infraestructura',async()=>{
 const response=await handleAppleTraining(request({owner:'owner',action:'list'}),config,async()=>Response.json({message:'DETAIL: private table SECRET'},{status:500}));
 assert.deepEqual(await response.json(),{code:'apple_unavailable'});
});
test('Acciones desconocidas y cuerpos grandes se rechazan antes del RPC',async()=>{
 let calls=0;const f:typeof fetch=async()=>{calls++;return Response.json({});};
 assert.equal((await handleAppleTraining(request({owner:'o',action:'arbitrary_sql'}),config,f)).status,400);
 assert.equal((await handleAppleTraining(request({owner:'o',action:'list',padding:'x'.repeat(4000)}),config,f)).status,413);assert.equal(calls,0);
});
test('Retorno Apple usa la fachada propia y conserva el bearer del alumno',async()=>{
 const response=await handleAppleTraining(request({owner:'owner',action:'results.ingest',input:{observations:[]}}),config,async(url,init)=>{
  assert.ok(String(url).endsWith('/rpc/apple_results_command'));
  assert.equal(new Headers(init?.headers).get('Authorization'),'Bearer USER_FIXTURE');
  assert.deepEqual(JSON.parse(init?.body as string),{p_owner:'owner',p_action:'ingest',p_input:{observations:[]}});
  return Response.json({inserted:0});
 });
 assert.equal(response.status,200);
});
test('Catálogo de retorno traduce solo la receta autorizada del servidor',async()=>{
 const response=await handleAppleTraining(request({owner:'owner',action:'results.catalog'}),config,async()=>Response.json({enabled:true,results:[],plans:[{snapshot:source,revision:'a'.repeat(64),plan_id:'plan'}]}));
 const data=await response.json();assert.equal(data.plans[0].prescription.steps.length,2);assert.equal(data.plans[0].snapshot,undefined);
});

test('La revisión Apple usa los pasos autorizados y no asigna intervalos por su cuenta',async()=>{
 const response=await handleAppleTraining(request({owner:'owner',action:'results.preview',input:{activity_id:'activity',scheduled_id:'scheduled'}}),config,async(url,init)=>{
  assert.ok(String(url).endsWith('/rpc/apple_results_command'));
  assert.equal(JSON.parse(init?.body as string).p_action,'preview');
  return Response.json({snapshot:source,activity:{id:'activity',laps:[{index:0,timerSeconds:120}]},is_test:true});
 });
 const data=await response.json();assert.equal(response.status,200);
 assert.equal(data.snapshot,undefined);assert.equal(data.is_test,true);
 assert.equal(data.rows.length,1);assert.equal(data.rows[0].requires_recovery,true);
 assert.equal(data.rows[0].requires_distance,true);assert.equal(data.requires_measured_step,true);
 assert.deepEqual(data.rows[0].lap_indices,[]);assert.deepEqual(data.rows[0].recovery_lap_indices,[]);
});

test('El rechazo de pruebas se conserva y un cierre sobredimensionado no llega al RPC',async()=>{
 const response=await handleAppleTraining(request({owner:'owner',action:'results.confirm',input:{}}),config,async()=>Response.json({message:'test_activity'},{status:400}));
 assert.deepEqual(await response.json(),{code:'test_activity'});
 let calls=0;
 const large=await handleAppleTraining(request({owner:'owner',action:'results.confirm',padding:'x'.repeat(66000)}),config,async()=>{calls++;return Response.json({});});
 assert.equal(large.status,413);assert.equal(calls,0);
});
