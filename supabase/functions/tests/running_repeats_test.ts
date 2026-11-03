import {test} from 'node:test';
import assert from 'node:assert/strict';
import {findRunningRepeats, validatedRunningRepeats} from '../_shared/device_training/running_repeats.ts';
import {runningPrescription} from '../_shared/device_training/prescription.ts';
import type {RunningPrescription,RunningStep} from '../_shared/device_training/prescription.ts';
import {garminRunningWorkout} from '../_shared/garmin/training.ts';

const work:RunningStep={kind:'run',measure:'meters',value:400,description:'Carrera',pace:{fast:230,slow:240}};
const recovery:RunningStep={kind:'rest',measure:'seconds',value:45,description:'Recuperación pasiva'};
const warmup:RunningStep={kind:'warmup',measure:'seconds',value:1200,description:'Calentamiento'};
const cooldown:RunningStep={kind:'cooldown',measure:'seconds',value:600,description:'Enfriamiento'};
function prescription(steps:RunningStep[]):RunningPrescription {
 return {name:'Series de prueba',description:'',source:'coach',date:'2026-11-04',steps,
  repeatBlocks:findRunningRepeats(steps,[[0,steps.length]])};
}
function expand(steps:any[]):any[] {
 return steps.flatMap(step=>step.type==='WorkoutRepeatStep'
  ? Array.from({length:step.repeatValue},(_,round)=>expand(step.steps)
      .slice(0,step.skipLastRestStep&&round===step.repeatValue-1?-1:undefined)).flat()
  : [{...step,stepOrder:undefined}]);
}
test('diez series de 400 con 45 s son diez vueltas nativas sin perder la pauta',()=>{
 const steps=[warmup,{...recovery,kind:'jog' as const,value:60},...Array.from({length:10},()=>[work,recovery]).flat(),cooldown];
 const p=prescription(steps),before=JSON.stringify(steps),out=garminRunningWorkout(p);
 assert.deepEqual(p.repeatBlocks,[{start:2,stepCount:2,iterations:10,omitLastRecovery:false}]);
 const repeat=out.segments[0].steps[2];
 assert.equal(repeat.type,'WorkoutRepeatStep');
 if(repeat.type!=='WorkoutRepeatStep')throw Error('Falta repetición');
 assert.equal(repeat.repeatType,'REPEAT_UNTIL_STEPS_CMPLT');assert.equal(repeat.repeatValue,10);
 assert.deepEqual(repeat.steps.map(s=>[s.durationType,s.durationValue]),[['DISTANCE',400],['TIME',45]]);
 assert.deepEqual(expand(out.segments[0].steps),expand(garminRunningWorkout({...p,repeatBlocks:[]}).segments[0].steps));
 assert.equal(JSON.stringify(steps),before);
});
test('omitir la última recuperación conserva diez vueltas en Garmin',()=>{
 const p=prescription([warmup,...Array.from({length:9},()=>[work,recovery]).flat(),work,cooldown]);
 assert.equal(p.repeatBlocks?.[0].iterations,10);assert.equal(p.repeatBlocks?.[0].omitLastRecovery,true);
 const out=garminRunningWorkout(p);
 assert.deepEqual(expand(out.segments[0].steps),expand(garminRunningWorkout({...p,repeatBlocks:[]}).segments[0].steps));
 assert.equal(expand(out.segments[0].steps).filter(s=>s.intensity==='REST').length,9);
});
test('ni ritmo, ni notas, ni medida distintos se absorben en una repetición',()=>{
 const variants=[{...work,value:800},{...work,pace:{fast:235,slow:245}},{...work,description:'Otra indicación'}];
 for(const other of variants){const p=prescription([work,recovery,work,recovery,other,recovery]);
  assert.equal(p.repeatBlocks?.[0].iterations,2);
  assert.deepEqual(expand(garminRunningWorkout(p).segments[0].steps),expand(garminRunningWorkout({...p,repeatBlocks:[]}).segments[0].steps));}
});
test('se preservan las fronteras de elementos aunque sus dosis sean iguales',()=>{
 const set={target_distance_meters:400,target_duration_seconds:null,rest_after_seconds:0,recovery_type:'passive',recovery_duration_seconds:45};
 const item=(order_index:number)=>({order_index,exercise_id:'20000000-0000-4000-8000-000000000004',notes:null,
   sets:[0,1,2].map(order_index=>({...set,order_index}))});
 const raw={name:'Bloques',source:'coach',date:'2026-11-04',blocks:[{order_index:0,name:'Carrera',format:'running',rounds:1,rest_after_seconds:0,time_cap_seconds:null,items:[item(0),item(1)]}]};
 const p=runningPrescription(raw);
 assert.deepEqual(p.repeatBlocks?.map(g=>[g.start,g.iterations]),[[0,3],[6,3]]);
});
test('fartlek con patrón compuesto conserva cada trabajo y recuperación',()=>{
 const other={...work,value:800};const pattern=[work,recovery,other,{...recovery,value:90}];
 const p=prescription([warmup,...Array.from({length:3},()=>pattern).flat(),cooldown]);
 assert.deepEqual(p.repeatBlocks,[{start:1,stepCount:4,iterations:3,omitLastRecovery:false}]);
 assert.deepEqual(expand(garminRunningWorkout(p).segments[0].steps),expand(garminRunningWorkout({...p,repeatBlocks:[]}).segments[0].steps));
});
test('se rechazan metadatos solapados, fuera de límites o que cambian la dosis',()=>{
 const p=prescription([work,recovery,work,recovery]);
 for(const groups of [
  [{start:0,stepCount:2,iterations:3,omitLastRecovery:false}],
  [{start:0,stepCount:1,iterations:4,omitLastRecovery:false}],
  [p.repeatBlocks![0],p.repeatBlocks![0]],
  [{start:-1,stepCount:2,iterations:2,omitLastRecovery:false}],
 ]) assert.throws(()=>validatedRunningRepeats({...p,repeatBlocks:groups}),/unsupported_prescription/);
});
test('la compresión conserva exactamente secuencias variadas y sus objetivos',()=>{
 let seed=17;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;};
 for(let run=0;run<150;run++){
  const steps:RunningStep[]=[warmup];
  for(let group=0;group<4;group++){
   const count=2+random()%5;const active={...work,value:200+(random()%5)*100};
   const rest={...recovery,value:30+(random()%4)*15};
   for(let i=0;i<count;i++){steps.push(active);if(i<count-1||random()%2)steps.push(rest);}
  }
  steps.push(cooldown);const p=prescription(steps);
  assert.deepEqual(expand(garminRunningWorkout(p).segments[0].steps),expand(garminRunningWorkout({...p,repeatBlocks:[]}).segments[0].steps));
 }
});
