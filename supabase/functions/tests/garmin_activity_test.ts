import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Encoder, Profile} from '@garmin/fitsdk';
import {garminFitActivity, garminActivityCallback, downloadGarminFit} from '../_shared/garmin/activity_fit.ts';
import {historicalSeconds, proposeLapMapping, validateRunningObservation} from '../_shared/device_activity/running_result.ts';

function syntheticFit(sport = 'running', lapStartOffsets: readonly number[] = [], distanceScale = 1) {
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
    encoder.onMesg(Profile.MesgNum.LAP, {messageIndex: index, startTime: new Date(start.getTime() + (elapsed + (lapStartOffsets[index] ?? 0)) * 1000),
      totalElapsedTime: p.time, totalTimerTime: p.time, totalDistance: p.distance * distanceScale, intensity: p.intensity, wktStepIndex: index});
    elapsed += p.time;
  });
  encoder.onMesg(Profile.MesgNum.SESSION, {sport, startTime: start, totalElapsedTime: elapsed, totalTimerTime: elapsed,
    totalDistance: 712.5 * distanceScale, avgHeartRate: 130, maxHeartRate: 170});
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

test('una grabación FIT sin desplazamiento conserva cero, tiempos y vueltas sin inventar distancia', () => {
  const value = garminFitActivity(syntheticFit('running', [], 0), metadata);
  assert.equal(value.distanceMeters, 0);
  assert.equal(value.timerSeconds, 297.3);
  assert.equal(value.averageHeartRate, 130);
  assert.deepEqual(value.laps.map(lap => lap.distanceMeters), [0, 0, 0, 0]);
  for (const distanceMeters of [-1, NaN, Infinity, -Infinity, 1000001, null]) {
    assert.throws(() => validateRunningObservation({...value, distanceMeters: distanceMeters as number}), /invalid_activity/);
  }
  assert.throws(() => validateRunningObservation({...value, laps: value.laps.map((lap, index) =>
    index === 0 ? {...lap, distanceMeters: -1} : lap)}), /invalid_activity/);
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

test('admite el desfase acotado entre marcas FIT y tiempos medidos sin alterar la evidencia', () => {
  const activity = garminFitActivity(syntheticFit('running', [0, 0, -1]), metadata);
  assert.equal(activity.laps[2].startedAt, '2026-10-20T08:02:26.000Z');
  assert.equal(activity.laps[1].timerSeconds, 87.3);
  assert.equal(activity.laps[2].timerSeconds, 50);
  assert.equal(activity.timerSeconds, 297.3);
  assert.deepEqual(activity.laps.map(lap => lap.workoutStepIndex), [0, 1, 2, 3]);
});

test('el margen de marcas horarias no admite más de dos segundos ni invierte vueltas cortas', () => {
  const activity = garminFitActivity(syntheticFit(), metadata);
  const end = Date.parse(activity.laps[1].startedAt) + activity.laps[1].elapsedSeconds * 1000;
  const shifted = (milliseconds: number) => ({...activity, laps: activity.laps.map((lap, index) =>
    index === 2 ? {...lap, startedAt: new Date(end - milliseconds).toISOString()} : lap)});
  assert.doesNotThrow(() => validateRunningObservation(shifted(2000)));
  assert.throws(() => validateRunningObservation(shifted(2001)), /invalid_activity/);
  const short = {...activity, laps: activity.laps.map((lap, index) => index === 1
    ? {...lap, elapsedSeconds: .5, timerSeconds: .5} : index === 2
      ? {...lap, startedAt: new Date(Date.parse(activity.laps[1].startedAt) - 100).toISOString()} : lap)};
  assert.throws(() => validateRunningObservation(short), /invalid_activity/);
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

test('una serie recortada con índice nativo conserva el mapa y sus mediciones reales', () => {
  const activity = garminFitActivity(syntheticFit(), metadata);
  const steps = [{kind:'warmup',measure:'manual' as const,value:null},
    {kind:'run',measure:'meters' as const,value:400},
    {kind:'rest',measure:'seconds' as const,value:50},
    {kind:'cooldown',measure:'manual' as const,value:null}];
  const laps = activity.laps.map(lap => lap.index===1
    ? {...lap,distanceMeters:17.25,timerSeconds:8.125} : lap);
  const original = structuredClone(laps);
  assert.deepEqual(proposeLapMapping(steps,laps),[[0],[1],[2],[3]]);
  assert.deepEqual(laps,original);
  // Mismo número de vueltas sin identidad no permite adivinar una serie corta.
  assert.deepEqual(proposeLapMapping(steps,laps.map(lap=>({...lap,workoutStepIndex:null}))),[null,null,null,null]);
  assert.deepEqual(proposeLapMapping(steps,laps.map(lap=>lap.index===1?{...lap,intensity:'rest'}:lap)),[null,null,null,null]);
});

test('Auto Lap y series recortadas conservan todos los segmentos del mismo paso', () => {
  const activity=garminFitActivity(syntheticFit(),metadata);
  const laps=[{...activity.laps[0],timerSeconds:30,distanceMeters:50},
    {...activity.laps[0],index:1,timerSeconds:30,distanceMeters:50},
    ...activity.laps.slice(1).map(lap=>({...lap,index:lap.index+1,distanceMeters:lap.index===1?2.25:lap.distanceMeters}))];
  const steps=[{kind:'warmup',measure:'manual' as const,value:null},
    {kind:'run',measure:'meters' as const,value:400},
    {kind:'rest',measure:'seconds' as const,value:50},
    {kind:'cooldown',measure:'manual' as const,value:null}];
  assert.deepEqual(proposeLapMapping(steps,laps),[[0,1],[2],[3],[4]]);
  assert.deepEqual(proposeLapMapping(steps,laps.map(lap=>lap.index===2?{...lap,workoutStepIndex:99}:lap)),[null,null,null,null]);
});
