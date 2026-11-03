import {test} from 'node:test';
import assert from 'node:assert/strict';
import {nativeGarminPrescriptionReference,deliveredGarminPrescriptionReference} from '../_shared/garmin/activity_reference.ts';
import {ActivityReturnService} from '../_shared/device_activity/return_service.ts';
import type {ActivityJob} from '../_shared/device_activity/return_service.ts';
import type {ObservedRunningActivity} from '../_shared/device_activity/running_result.ts';
import type {AccessGrant} from '../_shared/device_training/delivery.ts';
import {Encoder,Profile} from '@garmin/fitsdk';
import {garminFitObservation} from '../_shared/garmin/activity_fit.ts';

function source(){return {name:'Prueba',date:'2026-11-01',source:'coach',blocks:[{order_index:0,name:'Carrera',format:'running',rounds:1,
  rest_after_seconds:0,time_cap_seconds:null,items:[{order_index:0,exercise_id:'20000000-0000-4000-8000-000000000004',notes:null,
    sets:[{order_index:0,target_duration_seconds:120,target_distance_meters:null,rest_after_seconds:0,
      target_pace_min_seconds_per_km:300,target_pace_max_seconds_per_km:360,recovery_type:null}]}]}]};}
const workout=[{sport:'running',numValidSteps:1}];
const steps=[{messageIndex:0,intensity:'active',durationType:'time',durationValue:120000,
  targetType:'speed',targetValue:0,customTargetValueLow:2778,customTargetValueHigh:3333}];

test('compara la pauta enviada con unidades nativas FIT, sin convertir nombre o fecha en identidad',()=>{
  const snapshot=source(),ref=deliveredGarminPrescriptionReference(snapshot);
  assert.ok(ref);assert.equal(nativeGarminPrescriptionReference(workout,steps),ref);
  snapshot.name='Otro nombre';snapshot.date='2026-11-08';
  assert.equal(deliveredGarminPrescriptionReference(snapshot),ref);
  snapshot.blocks[0].items[0].sets[0].target_duration_seconds=121;
  assert.notEqual(deliveredGarminPrescriptionReference(snapshot),ref);
  assert.notEqual(nativeGarminPrescriptionReference(workout,[{...steps[0],customTargetValueHigh:3334}]),ref);
});
test('no identifica pautas truncadas, objetivos desconocidos ni índices discontinuos',()=>{
  for(const input of [[{...steps[0],messageIndex:1}],[{...steps[0],targetValue:2}],
    [{...steps[0],secondaryTargetType:'heartRate'}],[{...steps[0],durationType:'heartRateLessThan'}]]){
    assert.equal(nativeGarminPrescriptionReference(workout,input),null);
  }
  assert.equal(nativeGarminPrescriptionReference([{...workout[0],numValidSteps:2}],steps),null);
  assert.equal(nativeGarminPrescriptionReference([...workout,...workout],steps),null);
});
test('el SDK oficial conserva la referencia de pasos al leer una actividad FIT',()=>{
  const e=new Encoder(),start=new Date('2026-11-01T10:00:00Z');
  e.onMesg(Profile.MesgNum.FILE_ID,{type:'activity',manufacturer:'garmin',timeCreated:start});
  e.onMesg(Profile.MesgNum.WORKOUT,workout[0]);
  e.onMesg(Profile.MesgNum.WORKOUT_STEP,steps[0]);
  e.onMesg(Profile.MesgNum.LAP,{messageIndex:0,startTime:start,totalTimerTime:120,totalElapsedTime:120,totalDistance:400,intensity:'active',wktStepIndex:0});
  e.onMesg(Profile.MesgNum.SESSION,{sport:'running',startTime:start,totalTimerTime:120,totalElapsedTime:120,totalDistance:400});
  const a=garminFitObservation(e.close(),{activityId:'123',activityName:'Prueba'});
  assert.equal(a.prescriptionReference,deliveredGarminPrescriptionReference(source()));
});
test('la referencia de fuerza distingue variante y peso prescrito',()=>{
  const w=[{sport:'training',subSport:'strengthTraining',numValidSteps:1}];
  const s={messageIndex:0,intensity:'active',durationType:'reps',durationValue:5,targetType:'open',
    exerciseCategory:'benchPress',exerciseName:1,exerciseWeight:20};
  const first=nativeGarminPrescriptionReference(w,[s]);assert.ok(first);
  assert.notEqual(nativeGarminPrescriptionReference(w,[{...s,exerciseWeight:25}]),first);
  assert.notEqual(nativeGarminPrescriptionReference(w,[{...s,exerciseName:2}]),first);
});

test('un bucle FIT conserva la misma referencia que los pasos expandidos anteriores',()=>{
 const snapshot=source();snapshot.blocks[0].items[0].sets=Array.from({length:3},(_,order_index)=>({...snapshot.blocks[0].items[0].sets[0],order_index}));
 const repeat={messageIndex:1,durationType:'repeatUntilStepsCmplt',durationValue:0,targetValue:3};
 const grouped=[steps[0],repeat];
 const expected=deliveredGarminPrescriptionReference(snapshot);
 assert.ok(expected);
 assert.equal(nativeGarminPrescriptionReference([{sport:'running',numValidSteps:2}],grouped),expected);
 assert.equal(nativeGarminPrescriptionReference([{sport:'running',numValidSteps:3}],Array.from({length:3},(_,messageIndex)=>({...steps[0],messageIndex}))),expected);
 for(const invalid of [{...repeat,targetValue:101},{...repeat,durationValue:1},{...repeat,durationType:'repeatUntilTime'}])
  assert.equal(nativeGarminPrescriptionReference([{sport:'running',numValidSteps:2}],[steps[0],invalid]),null);
 const encoder=new Encoder(),start=new Date('2026-11-03T09:00:00Z');
 encoder.onMesg(Profile.MesgNum.FILE_ID,{type:'activity',manufacturer:'garmin',timeCreated:start});
 encoder.onMesg(Profile.MesgNum.WORKOUT,{sport:'running',numValidSteps:2});
 for(const step of grouped)encoder.onMesg(Profile.MesgNum.WORKOUT_STEP,step);
 encoder.onMesg(Profile.MesgNum.SESSION,{sport:'running',startTime:start,totalTimerTime:360,totalElapsedTime:360,totalDistance:1200});
 const activity=garminFitObservation(encoder.close(),{activityId:'1001',activityName:'Prueba'});
 assert.equal(activity.prescriptionReference,expected);
});

const job:ActivityJob={id:'job',owner:'owner',generation:1,lease:'lease',callback:'callback',metadata:{},tokens:'tokens',
  providerUserId:'provider',accessExpiresAt:'2026-11-02T00:00:00Z',refreshExpiresAt:'2026-11-03T00:00:00Z'};
const grant:AccessGrant={accessToken:'access',refreshToken:'refresh',expiresInSeconds:3600,refreshExpiresInSeconds:86400,scope:''};
function fixture(options:{duplicate?:boolean;stale?:boolean;extra?:boolean;failComplete?:boolean}={}){
  const actions:{action:string;input:Record<string,unknown>}[]=[];
  const activity:ObservedRunningActivity={schemaVersion:1,externalId:'123',name:'Prueba',startedAt:'2026-11-01T10:00:00Z',offsetSeconds:3600,
    timerSeconds:120,elapsedSeconds:120,distanceMeters:400,averageHeartRate:null,maxHeartRate:null,prescriptionReference:'reference',
    laps:[{index:0,startedAt:'2026-11-01T10:00:00Z',timerSeconds:120,elapsedSeconds:120,distanceMeters:400,intensity:'active',workoutStepIndex:0}]};
  if(options.extra){activity.timerSeconds=240;activity.elapsedSeconds=240;activity.distanceMeters=800;
    activity.laps.push({...activity.laps[0],index:1,startedAt:'2026-11-01T10:02:00Z',workoutStepIndex:1});}
  const candidates=[{scheduled_id:'one',revision:'revision',snapshot:source(),current:!options.stale}];
  if(options.duplicate)candidates.push({...candidates[0],scheduled_id:'two',current:false});
  const service=new ActivityReturnService({command:async(action,_owner,_session,input)=>{
    actions.push({action,input});
    if(action==='save')return {activity_id:'activity',activity_revision:'observed'};
    if(action==='automatic.context')return {activity_id:'activity',activity_revision:'observed',candidates};
    if(action==='automatic.complete'&&options.failComplete)throw new Error('stale_prescription');
    return {};
  }},{refresh:async()=>grant,userId:async()=> 'provider',permissions:async()=>({canReadActivities:true,canSendWorkouts:true})},
  {open:async<T>(value:string)=> (value==='tokens'?grant:'https://apis.garmin.com/wellness-api/rest/activityFile?id=1') as T,seal:async()=> 'rotated'},
  {read:async()=>activity,reference:()=> 'reference'},()=>Date.parse('2026-11-01T12:00:00Z'));
  return {service,actions};
}
test('cierra únicamente una coincidencia completa y conserva el mapa observado',async()=>{
  const f=fixture();await f.service.process(job);
  assert.deepEqual(f.actions.map(a=>a.action),['downloading','save','automatic.context','automatic.complete','release']);
  const request=f.actions.find(a=>a.action==='automatic.complete')!.input;
  assert.deepEqual(request.mapping,[{block_order:0,item_order:0,set_order:0,lap_indices:[0],recovery_lap_indices:[],skipped:false}]);
  assert.equal(request.scheduled_id,'one');assert.equal(request.rpe,undefined);
});
test('otra cita idéntica, versión retirada o intervalos sobrantes exigen revisión',async()=>{
  for(const [options,code] of [[{duplicate:true},'ambiguous_prescription'],[{stale:true},'stale_prescription'],
    [{extra:true},'intervals_require_review']] as const){
    const f=fixture(options);await f.service.process(job);
    assert.ok(!f.actions.some(a=>a.action==='automatic.complete'));
    assert.equal(f.actions.find(a=>a.action==='automatic.review')?.input.code,code);
  }
});
test('un cierre fallido no invalida la importación ni vuelve a consumir el FIT',async()=>{
  const f=fixture({failComplete:true});await f.service.process(job);
  assert.equal(f.actions.filter(a=>a.action==='save').length,1);
  assert.ok(!f.actions.some(a=>a.action==='failed'));
  assert.equal(f.actions.find(a=>a.action==='automatic.review')?.input.code,'review_required');
  assert.equal(f.actions.at(-1)?.action,'release');
});
