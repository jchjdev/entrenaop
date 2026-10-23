import {test} from 'node:test';
import assert from 'node:assert/strict';
import {ActivityReturnService} from '../_shared/device_activity/return_service.ts';
import type {ActivityJob} from '../_shared/device_activity/return_service.ts';
import type {AccessGrant} from '../_shared/device_training/delivery.ts';
const job: ActivityJob = {id:'job',owner:'owner',generation:1,lease:'lease',callback:'callback',metadata:{},
  tokens:'tokens',accessExpiresAt:'2026-10-24T00:00:00Z',refreshExpiresAt:'2026-11-24T00:00:00Z',providerUserId:'provider'};
const grant: AccessGrant = {accessToken:'access',refreshToken:'refresh',expiresInSeconds:3600,refreshExpiresInSeconds:86400,scope:''};
const activity = {schemaVersion:1 as const,externalId:'123',name:'Sintética',startedAt:'2026-10-20T08:00:00Z',offsetSeconds:null,
  elapsedSeconds:100,timerSeconds:100,distanceMeters:400,averageHeartRate:null,maxHeartRate:null,laps:[]};
function fixture(options: {wrongUser?:boolean;deny?:boolean;refreshFails?:boolean;readFails?:boolean;saveFails?:boolean} = {}) {
  const calls: {action:string;input:Record<string,unknown>}[] = [];
  let downloads=0;
  const service = new ActivityReturnService({command:async(action,_owner,_session,input)=>{
    calls.push({action,input}); if(action==='save' && options.saveFails) throw new Error('offline'); return {};
  }}, {refresh:async()=>{ if(options.refreshFails) throw new Error('offline'); return grant; },
    userId:async()=>options.wrongUser?'stranger':'provider',
    permissions:async()=>({canReadActivities:!options.deny,canSendWorkouts:true})},
  {open:async<T>(value:string,context:string)=>{
    assert.equal(context,value==='tokens'?'tokens:owner:1':'activity-callback:job');
    return (value==='tokens'?grant:'https://apis.garmin.com/wellness-api/rest/activityFile?id=1&token=x') as T;
  },seal:async()=> 'rotated'},
  {read:async()=>{ downloads++; if(options.readFails) throw new Error('offline'); return activity; }},
  ()=>Date.parse('2026-10-23T00:00:00Z'));
  return {service,calls,downloads:()=>downloads};
}
test('guarda observación sin completar ninguna ejecución y libera lease',async()=>{
  const f=fixture(); await f.service.process(job);
  assert.deepEqual(f.calls.map(c=>c.action),['downloading','save','release']);
  assert.equal(f.calls[1].input.activity,activity); assert.equal(f.downloads(),1);
});
test('verifica identidad y permiso antes de consumir el archivo',async()=>{
  for(const options of [{wrongUser:true},{deny:true}]) {
    const f=fixture(options);await f.service.process(job);
    assert.equal(f.downloads(),0); assert.equal(f.calls[0].action,'failed');
    assert.equal(f.calls[0].input.uncertain,false);assert.equal(f.calls.at(-1)?.action,'release');
  }
});
test('renueva y persiste el token antes de descargar',async()=>{
  const f=fixture();await f.service.process({...job,accessExpiresAt:'2026-10-22T00:00:00Z'});
  assert.deepEqual(f.calls.map(c=>c.action),['refreshing','rotate','downloading','save','release']);
});
test('una renovación o descarga incierta no se repite ciegamente',async()=>{
  for(const options of [{refreshFails:true},{readFails:true},{saveFails:true}]) {
    const f=fixture(options);await f.service.process({...job,accessExpiresAt:'2026-10-22T00:00:00Z'});
    assert.equal(f.calls.find(c=>c.action==='failed')?.input.uncertain,true);
    assert.equal(f.calls.at(-1)?.action,'release');assert.ok(f.downloads()<=1);
  }
});
