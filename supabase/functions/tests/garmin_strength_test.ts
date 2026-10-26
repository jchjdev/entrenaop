import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Encoder,Profile} from '@garmin/fitsdk';
import {strengthPrescription} from '../_shared/device_training/strength.ts';
import {garminStrengthWorkout} from '../_shared/garmin/strength.ts';
import {GarminTrainingClient} from '../_shared/garmin/training.ts';
import {garminFitObservation} from '../_shared/garmin/activity_fit.ts';
import {activityReview} from '../_shared/device_activity/return_service.ts';
import {validateStrengthObservation} from '../_shared/device_activity/strength_result.ts';
import type {ObservedStrengthActivity} from '../_shared/device_activity/strength_result.ts';
function recipe(){return {sport:'strength',name:'Fuerza sintética',description:'Prueba de contrato',source:'coach',date:'2026-10-24',
  blocks:[{order_index:0,name:'Banca',format:'straight_sets',rounds:1,rest_after_seconds:0,time_cap_seconds:null,
    items:[{order_index:0,exercise_code:'bench_press_barbell',exercise_name:'Press banca',notes:null,
      sets:[0,1,2].map(order_index=>({order_index,target_reps:10,target_load_kg:20,rest_after_seconds:30}))}]}]};}
function file(missing=false){
  const e=new Encoder(),start=new Date('2026-10-24T08:00:00Z');
  e.onMesg(Profile.MesgNum.FILE_ID,{type:'activity',manufacturer:'garmin',timeCreated:start});
  for(let i=0;i<6;i++)e.onMesg(Profile.MesgNum.SET,{messageIndex:i,startTime:new Date(start.getTime()+i*30000),duration:30,
    setType:i%2?'rest':'active',wktStepIndex:i,...(i%2||missing?{}:{repetitions:10-i/2,weight:i===2?22.5:20,category:['benchPress'],categorySubtype:[1]})});
  e.onMesg(Profile.MesgNum.SESSION,{sport:'training',subSport:'strengthTraining',startTime:start,totalElapsedTime:180,totalTimerTime:180,avgHeartRate:110,maxHeartRate:140});
  return e.close();
}
const meta={activityId:'7654321',activityName:'Fixture fuerza'};
test('receta propia conserva cada serie, carga y descanso en STRENGTH_TRAINING',()=>{
  const raw=recipe(),before=JSON.stringify(raw),p=strengthPrescription(raw),out=garminStrengthWorkout(p);
  assert.equal(JSON.stringify(raw),before);assert.equal(out.sport,'STRENGTH_TRAINING');assert.equal(out.segments[0].steps.length,6);
  assert.equal(out.segments[0].steps[0].exerciseName,'BARBELL_BENCH_PRESS');assert.equal(out.segments[0].steps[0].durationType,'REPS');
  assert.equal(out.segments[0].steps[0].weightValue,20);assert.equal(out.segments[0].steps[1].intensity,'REST');
  assert.equal(out.segments[0].steps[5].durationValue,30);
});
test('rechaza degradar superseries, ejercicios desconocidos y mediciones especiales',()=>{
  for(const edit of [(p:any)=>p.blocks[0].format='superset',(p:any)=>p.blocks[0].rounds=2,
    (p:any)=>p.blocks[0].items[0].exercise_code='inventado',
    (p:any)=>p.blocks[0].items[0].sets[0].performance_prescription={schema_version:1},
    (p:any)=>p.blocks[0].items[0].sets[0].target_distance_meters=10]){
    const raw=recipe();edit(raw);assert.throws(()=>garminStrengthWorkout(strengthPrescription(raw)),/unsupported_prescription/);
  }
});
test('FIT fuerza conserva repeticiones y kilos observados y propone solo con índice y ejercicio explícitos',()=>{
  const a=garminFitObservation(file(),meta) as ObservedStrengthActivity;
  assert.equal(a.schemaVersion,2);assert.equal(a.distanceMeters,null);assert.equal(a.sets[2].loadKg,22.5);assert.equal(a.sets[2].repetitions,9);
  assert.equal(a.sets[0].exerciseCode,'bench_press_barbell');assert.equal(a.sets[1].kind,'rest');
  const reviewed=activityReview({snapshot:recipe(),activity:a});
  assert.deepEqual((reviewed.rows as any[]).map(r=>r.lap_indices),[[0],[2],[4]]);
  const uncertain=activityReview({snapshot:recipe(),activity:{...a,sets:a.sets.map(s=>({...s,workoutStepIndex:null}))}});
  assert.deepEqual((uncertain.rows as any[]).map(r=>r.lap_indices),[[],[],[]]);
});
test('datos ausentes quedan ausentes, nunca se copian las diez repeticiones o veinte kilos pautados',()=>{
  const a=garminFitObservation(file(true),meta) as ObservedStrengthActivity;
  assert.equal(a.sets[0].repetitions,null);assert.equal(a.sets[0].loadKg,null);assert.equal(a.sets[0].exerciseCode,null);
  assert.throws(()=>validateStrengthObservation({...a,sets:a.sets.map(s=>({...s,loadKg:-1}))}),/invalid_activity/);
});
test('ejercicio propio conserva nombre, notas, tiempo, repeticiones y carga sin inventar equivalencia',()=>{
  const raw=recipe();
  const item=raw.blocks[0].items[0] as any;
  item.exercise_code=null;item.exercise_name='Front lever hold';item.notes='PDF: 4–7 s; base editable. Descanso libre.';
  item.sets=[{order_index:0,target_duration_seconds:4,rest_after_seconds:0},
    {order_index:1,target_reps:5,target_load_kg:7.5,rest_after_seconds:30}];
  const original=JSON.stringify(raw),out=garminStrengthWorkout(strengthPrescription(raw));
  assert.equal(JSON.stringify(raw),original);
  const steps=out.segments[0].steps;
  assert.equal(steps.length,3);
  assert.equal(steps[0].durationType,'TIME');assert.equal(steps[0].durationValue,4);
  assert.equal(steps[1].durationType,'REPS');assert.equal(steps[1].durationValue,5);assert.equal(steps[1].weightValue,7.5);
  assert.equal(steps[0].description,'Front lever hold · PDF: 4–7 s; base editable. Descanso libre.');
  for(const step of steps){assert.equal(Object.hasOwn(step,'exerciseCategory'),false);assert.equal(Object.hasOwn(step,'exerciseName'),false);}
  // Ausencia accidental del campo no es una declaración explícita de ejercicio genérico.
  delete item.exercise_code;assert.throws(()=>strengthPrescription(raw),/invalid_prescription/);
});
test('dos códigos desconocidos nunca proponen una correspondencia automática de resultados',()=>{
  const raw=recipe();(raw.blocks[0].items[0] as any).exercise_code=null;
  const activity=garminFitObservation(file(true),meta) as ObservedStrengthActivity;
  const reviewed=activityReview({snapshot:raw,activity});
  assert.deepEqual((reviewed.rows as any[]).map(r=>r.lap_indices),[[],[],[]]);
});
test('actualizar y retirar fuerza usa las referencias existentes y mantiene su deporte',async()=>{
  const calls:{method:string;url:string;body:any}[]=[];
  const client=new GarminTrainingClient(async(url,options)=>{
    calls.push({url:String(url),method:options?.method??'GET',body:options?.body?JSON.parse(String(options.body)):null});
    return options?.method==='POST'?Response.json({workoutId:123}):new Response(null,{status:204});
  });
  const p=strengthPrescription(recipe());
  assert.equal(await client.create('fixture',p),123);
  await client.update('fixture',123,p);await client.removeSchedule('fixture',456);await client.remove('fixture',123);
  assert.equal(calls[1].method,'PUT');assert.equal(calls[1].body.sport,'STRENGTH_TRAINING');assert.equal(calls[1].body.workoutId,123);
  assert.equal(calls[2].method,'DELETE');assert.equal(calls[2].url.endsWith('/schedule/456'),true);
  assert.equal(calls[3].method,'DELETE');assert.equal(calls[3].url.endsWith('/workout/v2/123'),true);
});
