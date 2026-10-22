import {test} from "node:test";
import assert from "node:assert/strict";
import {runningPrescription} from "../_shared/device_training/prescription.ts";
import {TrainingDeliveryService,DeliveryFailure} from "../_shared/device_training/delivery.ts";
import type {TrainingDeliveryStore,DeliveryActor,AccessGrant,TrainingGateway} from "../_shared/device_training/delivery.ts";
import {garminRunningWorkout,GarminTrainingClient} from "../_shared/garmin/training.ts";
import {handleGarminTraining} from "../_shared/garmin/training_http.ts";
const owner="10000000-0000-4000-8000-000000000001",session="20000000-0000-4000-8000-000000000001";
const scheduled="30000000-0000-4000-8000-000000000001",revision="a".repeat(64);
const who:DeliveryActor={actor:owner,owner,session};
function source(){return {name:"Carrera prescrita",date:"2026-10-27",source:"coach",blocks:[{order_index:0,name:"Carrera",format:"running",rounds:1,rest_after_seconds:0,time_cap_seconds:null,
  items:[{order_index:0,exercise_id:"20000000-0000-4000-8000-000000000004",notes:"Ritmo cómodo",sets:[{order_index:0,target_duration_seconds:null,target_distance_meters:1000,
    target_pace_min_seconds_per_km:300,target_pace_max_seconds_per_km:360,rest_after_seconds:0,recovery_type:"walking",recovery_duration_seconds:30,recovery_distance_meters:null}]}]}]};}
const grant:AccessGrant={accessToken:"PRIVATE_ACCESS",refreshToken:"PRIVATE_REFRESH",expiresInSeconds:3600,refreshExpiresInSeconds:7200,scope:"CONNECT_WRITE"};
test("normaliza carrera, conserva recuperación final e invierte extremos al convertir ritmo a velocidad",()=>{
 const raw=source(),before=JSON.stringify(raw),p=runningPrescription(raw),out=garminRunningWorkout(p);
 assert.equal(JSON.stringify(raw),before);assert.equal(p.steps.length,2);assert.equal(p.steps[1].kind,"walk");
 assert.equal(out.segments[0].steps[0].targetValueLow,1000/360);assert.equal(out.segments[0].steps[0].targetValueHigh,1000/300);
 assert.equal(out.segments[0].steps[1].durationValue,30);assert.equal(out.segments[0].steps[1].targetType,"OPEN");
 assert.equal(out.segments[0].steps[1].durationType,"TIME");
});
test("rechaza degradación, orden ambiguo, recetas ajenas y duración/distancia simultáneas",()=>{
 const edits=[(p:any)=>p.source="user",(p:any)=>p.blocks[0].rounds=2,(p:any)=>p.blocks[0].format="circuit",
  (p:any)=>p.blocks[0].items[0].exercise_id="strength",(p:any)=>p.blocks[0].items[0].sets[0].target_duration_seconds=600,
  (p:any)=>p.blocks[0].items[0].sets[0].order_index=9,(p:any)=>p.blocks[0].items[0].sets[0].target_distance_meters=Infinity,
  (p:any)=>p.blocks[0].items[0].sets[0].rest_after_seconds=45,(p:any)=>p.blocks[0].items[0].sets[0].target_load_kg=20,
  (p:any)=>p.blocks[0].items[0].sets[0].recovery_type="unknown",(p:any)=>p.blocks[0].items[0].sets[0].target_pace_max_seconds_per_km=200];
 for(const edit of edits){const raw=source();edit(raw);assert.throws(()=>runningPrescription(raw));}
});
test("límite de cien pasos se comprueba incluyendo recuperaciones",()=>{
 const raw=source();raw.blocks[0].items[0].sets=Array.from({length:51},(_,i)=>({...raw.blocks[0].items[0].sets[0],order_index:i}));
 assert.throws(()=>runningPrescription(raw),/unsupported_prescription/);
});
test("duración, calentamiento y vuelta a calma se mantienen sin estimar metros",()=>{
 const raw:any=source();raw.blocks[0].format="warm_up";raw.blocks[0].items[0].sets[0].target_distance_meters=null;
 raw.blocks[0].items[0].sets[0].target_duration_seconds=300;
 assert.equal(garminRunningWorkout(runningPrescription(raw)).segments[0].steps[0].intensity,"WARMUP");
 raw.blocks[0].format="cool_down";assert.equal(garminRunningWorkout(runningPrescription(raw)).segments[0].steps[0].intensity,"COOLDOWN");
});
test("instrucciones de sesión se conservan y no se truncan para encajar Garmin",()=>{
 const raw={...source(),description:"Calentar antes y mantener la técnica indicada."};
 assert.equal(garminRunningWorkout(runningPrescription(raw)).description,raw.description);
 raw.description="x".repeat(1025);assert.throws(()=>runningPrescription(raw),/unsupported_prescription/);
});
test("transporte crea, agenda y confirma referencias de Garmin sin seguir redirecciones",async()=>{
 const paths:string[]=[];
 const client=new GarminTrainingClient(async(url,init)=>{
  paths.push(String(url));assert.equal(init?.redirect,"error");assert.equal(new Headers(init?.headers).get("Authorization"),"Bearer fixture");
  if(String(url).endsWith("/workout/v2")){assert.equal(JSON.parse(String(init?.body)).sport,"RUNNING");return Response.json({workoutId:123});}
  if(init?.method==="POST"){assert.deepEqual(JSON.parse(String(init.body)),{workoutId:123,date:"2026-10-27"});return new Response(null,{status:204});}
  return Response.json([{scheduleId:456,workoutId:123,date:"2026-10-27"}]);
 });
 const p=runningPrescription(source());assert.equal(await client.create("fixture",p),123);await client.schedule("fixture",123,p.date);
 assert.equal(await client.confirmSchedule("fixture",123,p.date),456);
 assert.equal(paths[0],"https://apis.garmin.com/workoutportal/workout/v2");
 assert.equal(paths[1],"https://apis.garmin.com/training-api/schedule/");
});
test("rejetos HTTP conocidos son distintos de escrituras inciertas y no filtran cuerpos",async()=>{
 for(const status of [400,401,403,412,429,500]){
  const client=new GarminTrainingClient(async()=>new Response("PRIVATE_PROVIDER_BODY",{status}));
  await assert.rejects(client.create("fixture",runningPrescription(source())),(e)=>{
   assert.ok(e instanceof DeliveryFailure);assert.equal(e.uncertain,status>=500);assert.equal(e.message.includes("PRIVATE"),false);return true;
  });
 }
 for(const response of [new Response(null,{status:204}),Response.json({workoutId:Number.MAX_SAFE_INTEGER+1}),new Response("{"),Response.json({workoutId:1,x:"x".repeat(66000)})]){
  await assert.rejects(new GarminTrainingClient(async()=>response).create("fixture",runningPrescription(source())),e=>e instanceof DeliveryFailure&&e.uncertain);
 }
});
test("un calendario ambiguo o sin referencia no se anuncia como enviado",async()=>{
 for(const result of [[],[{scheduleId:1,workoutId:999,date:"2026-10-27"}],
  [{scheduleId:1,workoutId:123,date:"2026-10-27"},{scheduleId:2,workoutId:123,date:"2026-10-27"}]]){
  await assert.rejects(new GarminTrainingClient(async()=>Response.json(result)).confirmSchedule("fixture",123,"2026-10-27"),/schedule_not_confirmed/);
 }
});
function fixture(options:{expired?:boolean;permission?:boolean;saveLost?:boolean;createUnknown?:boolean;scheduleUnknown?:boolean;confirmFail?:boolean;rejectSchedule?:boolean}={}){
 const calls:string[]=[],row:any={id:"delivery",status:"prepared",workout_id:null,garmin_user_id:"fixture-user",generation:2};
 const receipt=()=>({id:row.id,scheduled_id:scheduled,status:row.status,name:"Carrera",date:"2026-10-27",error_code:row.error_code??null});
 const store:TrainingDeliveryStore={async command(action,actor,input){
  assert.deepEqual(actor,who);calls.push(action);
  if(action==="preview")return {revision,snapshot:source()};
  if(action==="claim")return row.status==="sent"||row.status==="uncertain"?{done:true,receipt:receipt()}:
   {...row,done:false,snapshot:source(),tokens_cipher:"encrypted",access_expires_at:options.expired?"2000-01-01T00:00:00Z":"2099-01-01T00:00:00Z",refresh_expires_at:"2099-01-01T00:00:00Z"};
  if(action==="rotate"){row.status=row.workout_id?"workout_created":"prepared";return {};}
  if(action==="mark_refreshing")row.status="refreshing";
  if(action==="mark_creating")row.status="creating";
  if(action==="save_workout"){if(options.saveLost)throw new DeliveryFailure("garmin_unavailable");row.workout_id=input.workout_id;row.status="workout_created";}
  if(action==="mark_scheduling")row.status="scheduling";
  if(action==="save_schedule")row.status="sent";
  if(action==="fail"){row.status=input.uncertain?"uncertain":"failed";row.error_code=input.code;}
  return receipt();
 }};
 const gateway:TrainingGateway={async create(){calls.push("POST_workout");if(options.createUnknown)throw new DeliveryFailure("provider_unavailable",true);return 123;},
  async schedule(){calls.push("POST_schedule");if(options.scheduleUnknown)throw new DeliveryFailure("provider_unavailable",true);if(options.rejectSchedule)throw new DeliveryFailure("rate_limited");},
  async confirmSchedule(){calls.push("GET_schedule");if(options.confirmFail)throw new DeliveryFailure("rate_limited");return 456;}};
 const account={async refresh(){calls.push("refresh");return grant;},async userId(){calls.push("identity");return "fixture-user";},
  async permissions(){calls.push("permissions_read");return {canReadActivities:true,canSendWorkouts:options.permission!==false};}};
 const cipher={async open<T>():Promise<T>{return grant as T;},async seal(){return "new-encrypted";}};
 const service=new TrainingDeliveryService(store,gateway,account,cipher,Date.now,async()=>{calls.push("cleanup");});
 return {service,calls,row};
}
test("envío completo e idempotencia de la misma cita sin secretos en recibo",async()=>{
 const f=fixture();assert.equal((await f.service.send(who,scheduled,revision)).status,"sent");
 assert.equal((await f.service.send(who,scheduled,revision)).status,"sent");
 assert.equal(f.calls.filter(x=>x==="POST_workout").length,1);assert.equal(f.calls.filter(x=>x==="POST_schedule").length,1);
 assert.ok(f.calls.indexOf("save_workout")<f.calls.indexOf("POST_schedule"));
 assert.equal(JSON.stringify(await f.service.send(who,scheduled,revision)).includes("PRIVATE"),false);
});
test("revisión diferente se rechaza antes de reservar o llamar al proveedor",async()=>{
 const f=fixture();await assert.rejects(f.service.send(who,scheduled,"b".repeat(64)),/stale_prescription/);assert.deepEqual(f.calls,["preview"]);
});
test("timeouts de creación, agenda, persistencia y confirmación no duplican POST",async()=>{
 for(const options of [{createUnknown:true},{scheduleUnknown:true},{saveLost:true},{confirmFail:true}]){
  const f=fixture(options);assert.equal((await f.service.send(who,scheduled,revision)).status,"uncertain");
  const before=f.calls.filter(x=>x.startsWith("POST")).length;
  assert.equal((await f.service.send(who,scheduled,revision)).status,"uncertain");
  assert.equal(f.calls.filter(x=>x.startsWith("POST")).length,before);
 }
});
test("un rechazo conocido al agendar reutiliza el entrenamiento creado",async()=>{
 const options={rejectSchedule:true},f=fixture(options);
 assert.equal((await f.service.send(who,scheduled,revision)).status,"failed");options.rejectSchedule=false;
 assert.equal((await f.service.send(who,scheduled,revision)).status,"sent");
 assert.equal(f.calls.filter(x=>x==="POST_workout").length,1);
});
test("rotación se persiste antes de identidad o escritura, sin token en el cliente",async()=>{
 const f=fixture({expired:true});await f.service.send(who,scheduled,revision);
 assert.ok(f.calls.indexOf("mark_refreshing")<f.calls.indexOf("refresh"));
 assert.ok(f.calls.indexOf("rotate")<f.calls.indexOf("identity"));
});
test("permiso externo retirado no crea y libera su lease",async()=>{
 const f=fixture({permission:false});assert.equal((await f.service.send(who,scheduled,revision)).status,"failed");
 assert.equal(f.calls.includes("POST_workout"),false);assert.equal(f.calls.at(-1),"cleanup");
});
test("HTTP verifica sesión/actor y cierra producción antes de SQL o Garmin",async()=>{
 const config={environment:"DEVELOPMENT",supabaseUrl:"https://sxbxfjqgoddzhtcyhalw.supabase.co",anonKey:"a",serviceKey:"s",clientId:"c",clientSecret:"secret",encryptionKey:Buffer.alloc(32,7).toString("base64url")};
 const jwt=`f.${Buffer.from(JSON.stringify({session_id:session})).toString("base64url")}.f`;
 let sqlCalls=0;
 const fetcher:typeof fetch=async(url,init)=>{
  if(String(url).endsWith("/auth/v1/user"))return Response.json({id:owner});
  sqlCalls++;const body=JSON.parse(String(init?.body));assert.equal(body.p_actor,owner);assert.equal(body.p_owner,owner);
  return Response.json({candidates:[],deliveries:[]});
 };
 const request=(expected=owner)=>new Request("https://edge.invalid",{method:"POST",headers:{Authorization:`Bearer ${jwt}`},body:JSON.stringify({action:"list",expected_user_id:expected})});
 assert.equal((await handleGarminTraining(request(),{...config,environment:"PRODUCTION"},fetcher)).status,503);
 assert.equal(sqlCalls,0);
 assert.equal((await handleGarminTraining(request("stranger"),config,fetcher)).status,409);assert.equal(sqlCalls,0);
 assert.equal((await handleGarminTraining(request(),config,fetcher)).status,200);assert.equal(sqlCalls,1);
});
test("Trainer exige también aal2 en el JWT verificado antes de acceder al alumno",async()=>{
 const config={environment:"DEVELOPMENT",supabaseUrl:"https://sxbxfjqgoddzhtcyhalw.supabase.co",anonKey:"a",serviceKey:"s",clientId:"c",clientSecret:"secret",encryptionKey:Buffer.alloc(32,7).toString("base64url")};
 const pupil="10000000-0000-4000-8000-000000000002";let sqlCalls=0;
 const fetcher:typeof fetch=async(url,init)=>{
  if(String(url).endsWith("/auth/v1/user"))return Response.json({id:owner});
  sqlCalls++;const body=JSON.parse(String(init?.body));assert.equal(body.p_actor,owner);assert.equal(body.p_owner,pupil);
  return Response.json({candidates:[],deliveries:[]});
 };
 function request(aal:string){
  const jwt=`f.${Buffer.from(JSON.stringify({session_id:session,aal})).toString("base64url")}.f`;
  return new Request("https://edge.invalid",{method:"POST",headers:{Authorization:`Bearer ${jwt}`},body:JSON.stringify({action:"list",expected_user_id:owner,client_id:pupil})});
 }
 assert.equal((await handleGarminTraining(request("aal1"),config,fetcher)).status,403);assert.equal(sqlCalls,0);
 assert.equal((await handleGarminTraining(request("aal2"),config,fetcher)).status,200);assert.equal(sqlCalls,1);
});
