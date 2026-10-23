import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Encoder, Profile} from '@garmin/fitsdk';
import {garminFitActivity, garminActivityCallback, downloadGarminFit} from '../_shared/garmin/activity_fit.ts';
import {historicalSeconds, proposeLapMapping, validateRunningObservation} from '../_shared/device_activity/running_result.ts';

function syntheticFit(sport = 'running') {
  const encoder = new Encoder(), start = new Date('2026-10-20T08:00:00Z');
  encoder.onMesg(Profile.MesgNum.FILE_ID, {type: 'activity', manufacturer: 'garmin', product: 1, timeCreated: start});
  const parts = [
    {time: 60, distance: 100, intensity: 'warmup'},
    {time: 87.3, distance: 400, intensity: 'active'},
    {time: 50, distance: 12.5, intensity: 'rest'},
    {time: 100, distance: 200, intensity: 'cooldown'},
  ];
  let elapsed = 0;
  parts.forEach((p, index) => {
    encoder.onMesg(Profile.MesgNum.LAP, {messageIndex: index, startTime: new Date(start.getTime() + elapsed * 1000),
      totalElapsedTime: p.time, totalTimerTime: p.time, totalDistance: p.distance, intensity: p.intensity, wktStepIndex: index});
    elapsed += p.time;
  });
  encoder.onMesg(Profile.MesgNum.SESSION, {sport, startTime: start, totalElapsedTime: elapsed, totalTimerTime: elapsed,
    totalDistance: 712.5, avgHeartRate: 130, maxHeartRate: 170});
  encoder.onMesg(Profile.MesgNum.ACTIVITY, {timestamp: new Date(start.getTime() + elapsed * 1000),
    localTimestamp: Math.floor((start.getTime() + elapsed * 1000 + 7200000 - 631065600000) / 1000)});
  return encoder.close();
}
const metadata = {activityId: '123456', activityName: 'Carrera sintética'};
test('FIT oficial conserva precisión, vueltas y reloj local sin importar coordenadas', () => {
  const value = garminFitActivity(syntheticFit(), metadata);
  assert.equal(value.laps[1].timerSeconds, 87.3);
  assert.equal(value.offsetSeconds, 7200);
  assert.equal(value.averageHeartRate, 130);
  assert.equal(value.laps[2].intensity, 'rest');
  assert.equal(JSON.stringify(value).includes('latitude'), false);
  assert.equal(historicalSeconds(value.laps[1].timerSeconds), 87);
});
test('CRC corrupto y otro deporte no se convierten en carrera válida', () => {
  const file = syntheticFit(); file[file.length - 1] ^= 1;
  assert.throws(() => garminFitActivity(file, metadata), /invalid_activity_file/);
  assert.throws(() => garminFitActivity(syntheticFit('cycling'), metadata), /unsupported_activity/);
});
test('solo propone una correspondencia completa y compatible; nunca reparte el total', () => {
  const value = garminFitActivity(syntheticFit(), metadata);
  const steps = [{kind: 'warmup', measure: 'manual' as const, value: null},
    {kind: 'run', measure: 'meters' as const, value: 400}, {kind: 'rest', measure: 'seconds' as const, value: 50},
    {kind: 'cooldown', measure: 'manual' as const, value: null}];
  assert.deepEqual(proposeLapMapping(steps, value.laps), [[0], [1], [2], [3]]);
  assert.deepEqual(proposeLapMapping(steps, value.laps.slice(1)), [null, null, null, null]);
  assert.deepEqual(proposeLapMapping(steps, value.laps.map(lap => ({...lap, intensity: null}))), [null, null, null, null]);
});
test('rechaza tiempos imposibles, vueltas superpuestas y pulso invertido', () => {
  const value = garminFitActivity(syntheticFit(), metadata);
  assert.throws(() => validateRunningObservation({...value, timerSeconds: value.elapsedSeconds + 10}));
  assert.throws(() => validateRunningObservation({...value, averageHeartRate: 180}));
  assert.throws(() => validateRunningObservation({...value, laps: value.laps.map(l => ({...l, startedAt: value.startedAt}))}));
});
test('descarga solo del recurso Garmin autorizado; bloquea SSRF y redirecciones', async () => {
  for (const url of ['http://apis.garmin.com/wellness-api/rest/activityFile?id=1&token=a',
    'https://apis.garmin.com.evil.example/wellness-api/rest/activityFile?id=1&token=a',
    'https://apis.garmin.com/wellness-api/rest/activityFile?id=1&token=a&token=b',
    'https://apis.garmin.com/wellness-api/rest/activityFile?id=1&token=a&url=https://localhost']) {
    assert.throws(() => garminActivityCallback(url));
  }
  let calls = 0;
  const f: typeof fetch = async (_url, options) => {
    calls++; assert.equal(options?.redirect, 'error'); return new Response(syntheticFit());
  };
  const bytes = await downloadGarminFit('https://apis.garmin.com/wellness-api/rest/activityFile?id=1&token=a', 'PRIVATE', f);
  assert.equal(calls, 1); assert.equal(garminFitActivity(bytes, metadata).laps.length, 4);
});
test('archivo vencido queda identificado sin reintentos ciegos', async () => {
  await assert.rejects(downloadGarminFit('https://apis.garmin.com/wellness-api/rest/activityFile?id=1&token=a',
    'PRIVATE', async () => new Response(null, {status: 410})), /activity_file_expired/);
});

test('agrupa Auto Lap solo con índice nativo continuo y conserva todas las vueltas', () => {
  const activity = garminFitActivity(syntheticFit(), metadata);
  const warmup = activity.laps[0];
  const laps = [{...warmup,timerSeconds:30,distanceMeters:50},
    {...warmup,index:1,timerSeconds:30,distanceMeters:50},
    ...activity.laps.slice(1).map(lap=>({...lap,index:lap.index+1}))];
  const steps=[{kind:'warmup',measure:'manual' as const,value:null},
    {kind:'run',measure:'meters' as const,value:400},
    {kind:'rest',measure:'seconds' as const,value:50},
    {kind:'cooldown',measure:'manual' as const,value:null}];
  assert.deepEqual(proposeLapMapping(steps,laps),[[0,1],[2],[3],[4]]);
  assert.deepEqual(proposeLapMapping(steps,laps.map(lap=>({...lap,workoutStepIndex:null}))),[null,null,null,null]);
});
