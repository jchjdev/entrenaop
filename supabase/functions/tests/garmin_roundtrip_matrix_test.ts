import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Encoder,Profile} from '@garmin/fitsdk';
import {garminRunningWorkout} from '../_shared/garmin/training.ts';
import {runningPrescription} from '../_shared/device_training/prescription.ts';
import {garminFitObservation} from '../_shared/garmin/activity_fit.ts';
import {deliveredGarminPrescriptionReference,deliveredGarminLapStepIndices} from '../_shared/garmin/activity_reference.ts';
import {activityReview,ActivityReturnService} from '../_shared/device_activity/return_service.ts';
import type {ObservedRunningActivity} from '../_shared/device_activity/running_result.ts';
import type {ActivityJob} from '../_shared/device_activity/return_service.ts';
type Row=Record<string,any>;
const row=(kind:string,measure:string,value:number|null,recovery?:[string,string,number])=>({
  target_duration_seconds:measure==='time'?value:null,target_distance_meters:measure==='distance'?value:null,
  running_step:{schema_version:2,kind,completion:measure},rest_after_seconds:0,
  ...(kind==='run'?{target_pace_min_seconds_per_km:240,target_pace_max_seconds_per_km:270}:{}),
  ...(recovery?{recovery_type:recovery[0],recovery_duration_seconds:recovery[1]==='time'?recovery[2]:null,
    recovery_distance_meters:recovery[1]==='distance'?recovery[2]:null}:{}),
});
function recipe(groups:Row[][]):Row {
  return {name:'Matriz sintética',source:'coach',date:'2026-11-06',blocks:[{
    order_index:0,name:'Carrera',format:'running',rounds:1,rest_after_seconds:0,time_cap_seconds:null,
    items:groups.map((sets,order_index)=>({order_index,exercise_id:'20000000-0000-4000-8000-000000000004',
      notes:null,sets:sets.map((set,order_index)=>({...set,order_index}))})),
  }]};
}
const warmup=row('warmup','time',900),cooldown=row('cooldown','time',600);
const intervals=(count:number,lastRecovery=true)=>Array.from({length:count},(_,index)=>row('run','distance',400,
  index<count-1||lastRecovery?['passive','time',45]:undefined));
const cases:[string,Row[][]][]=[
  ['diez series con recuperación final',[[warmup,...intervals(10),cooldown]]],
  ['diez series sin recuperación final',[[warmup,...intervals(10,false),cooldown]]],
  ['series por tiempo y recuperación andando',[[warmup,...Array.from({length:4},()=>row('run','time',180,['walking','time',120])),cooldown]]],
  ['series con recuperación por distancia',[[warmup,...Array.from({length:3},()=>row('run','time',180,['jogging','distance',200])),cooldown]]],
  ['repeticiones sin descansos',[[warmup,...Array.from({length:4},()=>row('run','time',60)),cooldown]]],
  ['dos elementos iguales',[[warmup,...intervals(3)],[...intervals(3),cooldown]]],
  ['dos tandas diferentes',[[warmup,...intervals(3),row('rest','time',180),
    ...Array.from({length:3},()=>row('run','distance',800,['jogging','time',90])),cooldown]]],
  ['patrón compuesto',[[warmup,...Array.from({length:3},()=>[row('run','distance',400,['passive','time',30]),
    row('run','time',90,['jogging','distance',100])]).flat(),cooldown]]],
  ['fases manuales',[[row('warmup','manual',null),...intervals(3,false),row('cooldown','manual',null)]]],
  ['rodaje por tiempo',[[row('run','time',1800)]]],
  ['rodaje por distancia',[[row('run','distance',5000)]]],
  ['transiciones explícitas',[[row('walking','time',60),row('run','time',300),row('recovery','distance',200),row('run','distance',800)]]],
];

// La fixture materializa el workout exportado en mensajes FIT reales. En FIT,
// omitir el descanso final se representa con N-1 vueltas y el trabajo restante.
function observed(snapshot:Row,compact:boolean,autoLap:boolean):ObservedRunningActivity {
  const p=runningPrescription(snapshot);
  const exported=garminRunningWorkout(compact?p:{...p,repeatBlocks:[]});
  const native:Row[]=[],sequence:number[]=[];
  function single(step:Row):number {
    const index=native.length;
    native.push({messageIndex:index,intensity:step.intensity.toLowerCase(),durationType:step.durationType.toLowerCase(),
      durationValue:step.durationType==='OPEN'?0:step.durationValue*(step.durationType==='TIME'?1000:step.durationType==='DISTANCE'?100:1),
      targetType:step.targetType==='PACE'?'speed':'open',targetValue:0,
      ...(step.targetType==='PACE'?{customTargetValueLow:Math.round(step.targetValueLow*1000),
        customTargetValueHigh:Math.round(step.targetValueHigh*1000)}:{})});
    return index;
  }
  for(const step of exported.segments[0].steps){
    if(step.type==='WorkoutStep'){sequence.push(single(step));continue;}
    const body=step.steps.map(single),count=step.repeatValue-(step.skipLastRestStep?1:0);
    if(count>1)native.push({messageIndex:native.length,durationType:'repeatUntilStepsCmplt',durationValue:body[0],targetValue:count});
    for(let round=0;round<count;round++)sequence.push(...body);
    if(step.skipLastRestStep)sequence.push(...step.steps.slice(0,-1).map(single));
  }
  const encoder=new Encoder(),start=new Date('2026-11-06T08:00:00Z');
  encoder.onMesg(Profile.MesgNum.FILE_ID,{type:'activity',manufacturer:'garmin',timeCreated:start});
  encoder.onMesg(Profile.MesgNum.WORKOUT,{sport:'running',numValidSteps:native.length});
  native.forEach(step=>encoder.onMesg(Profile.MesgNum.WORKOUT_STEP,step));
  let elapsed=0,distance=0,index=0;
  for(const [position,wktStepIndex] of sequence.entries()){
    const parts=autoLap&&position%3===0?2:1;
    for(let part=0;part<parts;part++){
      const seconds=13+position+part,meters=seconds*2.5;
      encoder.onMesg(Profile.MesgNum.LAP,{messageIndex:index++,startTime:new Date(start.getTime()+elapsed*1000),
        intensity:native[wktStepIndex].intensity,wktStepIndex,totalTimerTime:seconds,totalElapsedTime:seconds,totalDistance:meters});
      elapsed+=seconds;distance+=meters;
    }
  }
  encoder.onMesg(Profile.MesgNum.SESSION,{sport:'running',startTime:start,totalTimerTime:elapsed,totalElapsedTime:elapsed,totalDistance:distance});
  const a=garminFitObservation(encoder.close(),{activityId:'123',activityName:'Matriz sintética'}) as ObservedRunningActivity;
  a.offsetSeconds=3600;
  assert.equal(a.prescriptionReference,deliveredGarminPrescriptionReference(snapshot));
  return a;
}
async function complete(snapshot:Row,activity:ObservedRunningActivity){
  const actions:{action:string;input:Row}[]=[];
  const job:ActivityJob={id:'job',owner:'owner',generation:1,lease:'lease',callback:'callback',metadata:{},tokens:'tokens',
    providerUserId:'provider',accessExpiresAt:'2026-11-07T00:00:00Z',refreshExpiresAt:'2026-12-01T00:00:00Z'};
  const grant={accessToken:'access',refreshToken:'refresh',expiresInSeconds:3600,refreshExpiresInSeconds:86400,scope:''};
  const service=new ActivityReturnService({command:async(action,_owner,_session,input)=>{
    actions.push({action,input});
    if(action==='save')return {activity_id:'activity',activity_revision:'observed'};
    if(action==='automatic.context')return {activity_id:'activity',activity_revision:'observed',
      candidates:[{scheduled_id:'schedule',revision:'version',snapshot,current:true}]};
    return {};
  }},{refresh:async()=>grant,userId:async()=> 'provider',permissions:async()=>({canReadActivities:true,canSendWorkouts:true})},
  {open:async<T>(value:string)=>(value==='tokens'?grant:'callback') as T,seal:async()=> 'rotated'},
  {read:async()=>activity,reference:deliveredGarminPrescriptionReference,lapStepIndices:deliveredGarminLapStepIndices},
  ()=>Date.parse('2026-11-06T10:00:00Z'));
  await service.process(job);return actions;
}
for(const [name,groups] of cases)for(const compact of [false,true])for(const autoLap of [false,true]){
  test(`retorno completo: ${name}, ${compact?'bucle':'expandido'}, ${autoLap?'Auto Lap':'una vuelta por paso'}`,async()=>{
    const snapshot=recipe(groups),activity=observed(snapshot,compact,autoLap);
    const before=JSON.stringify(activity),actions=await complete(snapshot,activity);
    const result=actions.find(a=>a.action==='automatic.complete');
    // Un índice repetido sin recuperación y con Auto Lap no distingue dónde
    // termina una repetición y empieza la siguiente. Esa ambigüedad se revisa.
    if(compact&&autoLap&&name==='repeticiones sin descansos'){
      assert.equal(result,undefined);assert.equal(actions.find(a=>a.action==='automatic.review')?.input.code,'intervals_require_review');return;
    }
    assert.ok(result,JSON.stringify(actions.map(a=>({action:a.action,code:a.input.code}))));
    const rows=result.input.mapping as Row[];
    assert.deepEqual(rows.flatMap(row=>[...row.lap_indices,...row.recovery_lap_indices]),activity.laps.map(lap=>lap.index));
    assert.equal(JSON.stringify(activity),before);
    const review=activityReview({snapshot,activity},deliveredGarminLapStepIndices(snapshot));
    assert.deepEqual((review.rows as Row[]).map(row=>row.lap_indices),rows.map(row=>row.lap_indices));
  });
}

test('índices explícitos contradictorios no se ignoran aunque cuadre el número de vueltas por tiempo',async()=>{
  const snapshot=recipe([[row('run','time',90),row('run','time',120)]]),activity=observed(snapshot,false,false);
  activity.laps[1].workoutStepIndex=0;
  const actions=await complete(snapshot,activity);
  assert.ok(!actions.some(a=>a.action==='automatic.complete'));
});
