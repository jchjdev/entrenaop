import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Encoder,Profile} from '@garmin/fitsdk';
import {garminFitObservation} from '../_shared/garmin/activity_fit.ts';
import {deliveredGarminPrescriptionReference} from '../_shared/garmin/activity_reference.ts';
import {ActivityReturnService} from '../_shared/device_activity/return_service.ts';
import type {ObservedStrengthActivity} from '../_shared/device_activity/strength_result.ts';
import type {ActivityJob} from '../_shared/device_activity/return_service.ts';
type Row=Record<string,any>;
function fixture(code:string,timed:boolean,rest:boolean,compact:boolean){
  const category=code==='bench_press_barbell'?'benchPress':code==='push_up_standard'?'pushUp':'pullUp';
  const name=code==='bench_press_barbell'?1:code==='push_up_standard'?77:38;
  const snapshot={sport:'strength',name:'Fuerza matriz',source:'coach',date:'2026-11-06',blocks:[{
    order_index:0,format:'straight_sets',rounds:1,rest_after_seconds:0,time_cap_seconds:null,
    items:[{order_index:0,exercise_code:code,exercise_name:'Ejercicio',sets:Array.from({length:3},(_,order_index)=>({
      order_index,...(timed?{target_duration_seconds:30}:{target_reps:5}),target_load_kg:20,rest_after_seconds:rest?45:0,
    }))}],
  }]};
  const encoder=new Encoder(),start=new Date('2026-11-06T08:00:00Z');
  encoder.onMesg(Profile.MesgNum.FILE_ID,{type:'activity',manufacturer:'garmin',timeCreated:start});
  const active={intensity:'active',durationType:timed?'time':'reps',durationValue:timed?30000:5,targetType:'open',
    exerciseCategory:category,exerciseName:name,exerciseWeight:20};
  const pause={intensity:'rest',durationType:'time',durationValue:45000,targetType:'open'};
  const pattern=rest?[active,pause]:[active];
  const native:Row[]=compact?[...pattern,{durationType:'repeatUntilStepsCmplt',durationValue:0,targetValue:3}]
    :Array.from({length:3},()=>pattern).flat();
  encoder.onMesg(Profile.MesgNum.WORKOUT,{sport:'training',subSport:'strengthTraining',numValidSteps:native.length});
  native.forEach((step,messageIndex)=>encoder.onMesg(Profile.MesgNum.WORKOUT_STEP,{...step,messageIndex}));
  let elapsed=0,index=0;
  for(let set=0;set<3;set++){
    encoder.onMesg(Profile.MesgNum.SET,{messageIndex:index,startTime:new Date(start.getTime()+elapsed*1000),duration:25+set,
      setType:'active',repetitions:4+set,weight:17.5+set,category:[category],categorySubtype:[name],wktStepIndex:compact?0:index});
    index++;elapsed+=25+set;
    if(rest){encoder.onMesg(Profile.MesgNum.SET,{messageIndex:index,startTime:new Date(start.getTime()+elapsed*1000),duration:43,
      setType:'rest',wktStepIndex:compact?1:index});index++;elapsed+=43;}
  }
  encoder.onMesg(Profile.MesgNum.SESSION,{sport:'training',subSport:'strengthTraining',startTime:start,
    totalTimerTime:elapsed,totalElapsedTime:elapsed,workoutRpe:40});
  const activity=garminFitObservation(encoder.close(),{activityId:'123',activityName:'Fuerza matriz'}) as ObservedStrengthActivity;
  activity.offsetSeconds=3600;
  assert.equal(activity.prescriptionReference,deliveredGarminPrescriptionReference(snapshot));
  return {snapshot,activity};
}
async function run(snapshot:Row,activity:ObservedStrengthActivity){
  const actions:{action:string;input:Row}[]=[];
  const job:ActivityJob={id:'job',owner:'owner',generation:1,lease:'lease',callback:'callback',metadata:{},tokens:'tokens',
    providerUserId:'provider',accessExpiresAt:'2026-11-07T00:00:00Z',refreshExpiresAt:'2026-12-01T00:00:00Z'};
  const grant={accessToken:'access',refreshToken:'refresh',expiresInSeconds:3600,refreshExpiresInSeconds:86400,scope:''};
  const service=new ActivityReturnService({command:async(action,_owner,_session,input)=>{
    actions.push({action,input});
    if(action==='save')return {activity_id:'activity',activity_revision:'revision'};
    if(action==='automatic.context')return {activity_id:'activity',activity_revision:'revision',
      candidates:[{scheduled_id:'schedule',revision:'version',snapshot,current:true}]};
    return {};
  }},{refresh:async()=>grant,userId:async()=> 'provider',permissions:async()=>({canReadActivities:true,canSendWorkouts:true})},
  {open:async<T>(value:string)=>(value==='tokens'?grant:'callback') as T,seal:async()=> 'rotated'},
  {read:async()=>activity,reference:deliveredGarminPrescriptionReference},()=>Date.parse('2026-11-06T10:00:00Z'));
  await service.process(job);return actions;
}
for(const code of ['bench_press_barbell','push_up_standard','pull_up_pronated'])for(const timed of [false,true])
 for(const rest of [false,true])for(const compact of [false,true]){
  test(`fuerza automática: ${code}, ${timed?'tiempo':'repeticiones'}, ${rest?'descanso':'sin descanso'}, ${compact?'bucle':'expandida'}`,async()=>{
    const {snapshot,activity}=fixture(code,timed,rest,compact),before=JSON.stringify(activity),actions=await run(snapshot,activity);
    const result=actions.find(a=>a.action==='automatic.complete');assert.ok(result);
    assert.deepEqual(result.input.mapping.map((row:Row)=>row.lap_indices),rest?[[0],[2],[4]]:[[0],[1],[2]]);
    assert.equal(JSON.stringify(activity),before);assert.equal(activity.perceivedExertion,4);
  });
 }
test('fuerza conserva revisión ante repeticiones, carga o identidad de ejercicio ausentes',async()=>{
  for(const field of ['repetitions','loadKg','exerciseCode','workoutStepIndex']){
    const {snapshot,activity}=fixture('bench_press_barbell',false,true,true);
    (activity.sets[0] as unknown as Row)[field]=null;
    const actions=await run(snapshot,activity);assert.ok(!actions.some(a=>a.action==='automatic.complete'));
  }
});
