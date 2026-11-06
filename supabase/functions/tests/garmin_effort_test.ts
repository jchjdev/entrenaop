import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Encoder,Profile} from '@garmin/fitsdk';
import {garminFitObservation} from '../_shared/garmin/activity_fit.ts';
import {recordedActivityRpe,validateRunningObservation} from '../_shared/device_activity/running_result.ts';
import {activityReview} from '../_shared/device_activity/return_service.ts';

function activity(raw: number|undefined,strength=false){
  const encoder=new Encoder(),start=new Date('2026-11-06T08:00:00Z');
  encoder.onMesg(Profile.MesgNum.FILE_ID,{type:'activity',manufacturer:'garmin',timeCreated:start});
  if(strength)encoder.onMesg(Profile.MesgNum.SET,{messageIndex:0,startTime:start,duration:60,setType:'active',
    repetitions:5,weight:20,category:['benchPress'],categorySubtype:[1],wktStepIndex:0});
  else encoder.onMesg(Profile.MesgNum.LAP,{messageIndex:0,startTime:start,totalTimerTime:60,totalElapsedTime:60,totalDistance:200,
    intensity:'active',wktStepIndex:0});
  encoder.onMesg(Profile.MesgNum.SESSION,{sport:strength?'training':'running',...(strength?{subSport:'strengthTraining'}:{}),
    startTime:start,totalTimerTime:60,totalElapsedTime:60,totalDistance:strength?0:200,...(raw===undefined?{}:{workoutRpe:raw})});
  return garminFitObservation(encoder.close(),{activityId:'123',activityName:'Esfuerzo sintético'});
}
for(const strength of [false,true])test(`RPE FIT en décimas, ausencia y límites: ${strength?'fuerza':'carrera'}`,()=>{
  for(const [raw,expected] of [[undefined,undefined],[0,0],[5,.5],[40,4],[45,4.5],[100,10],[101,undefined],[254,undefined],[255,undefined]]){
    const a=activity(raw,strength);
    assert.equal(a.perceivedExertion,expected);
    assert.equal(recordedActivityRpe(a),expected!==undefined&&Number.isInteger(expected)&&expected>=1?expected:null);
  }
});
test('RPE observado rellena la revisión manual sin tomarlo del objetivo ni inventar redondeos',()=>{
  const snapshot={name:'Carrera',source:'coach',date:'2026-11-06',blocks:[{order_index:0,name:'Carrera',format:'running',
    rounds:1,rest_after_seconds:0,time_cap_seconds:null,items:[{order_index:0,exercise_id:'20000000-0000-4000-8000-000000000004',
      sets:[{order_index:0,target_duration_seconds:60,rest_after_seconds:0,target_rpe:9}]}]}]};
  for(const [raw,rpe] of [[undefined,null],[40,4],[45,null],[0,null]]){
    assert.equal(activityReview({snapshot,activity:activity(raw)}).recorded_rpe,rpe);
  }
  assert.equal(activityReview({snapshot,activity:activity(40),recorded_rpe:6}).recorded_rpe,6);
});
test('metadatos de receta y esfuerzo inválidos no entran como evidencia validada',()=>{
  const a=activity(40);assert.equal(a.schemaVersion,1);
  if(a.schemaVersion!==1)return;
  for(const perceivedExertion of [-1,11,NaN,Infinity])assert.throws(()=>validateRunningObservation({...a,perceivedExertion}),/invalid_activity/);
  for(const prescriptionStepIndices of [[],[-1],[1.5],Array(101).fill(0)]){
    assert.throws(()=>validateRunningObservation({...a,prescriptionReference:'reference',prescriptionStepIndices}),/invalid_activity/);
  }
  assert.throws(()=>validateRunningObservation({...a,prescriptionStepIndices:[0]}),/invalid_activity/);
});
