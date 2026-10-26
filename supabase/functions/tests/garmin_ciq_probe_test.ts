import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Decoder, Stream} from '@garmin/fitsdk';
import {ciqProbeFit, ciqProbeHandler, ciqProbeName} from '../_shared/garmin/ciq_probe.ts';

const dev = {environment: 'DEVELOPMENT', supabaseUrl: 'https://sxbxfjqgoddzhtcyhalw.supabase.co'};
const request = (suffix = '/workout.fit', method = 'GET') => new Request(`${dev.supabaseUrl}/functions/v1/garmin-ciq-probe${suffix}`, {method});

test('el ensayo queda cerrado por defecto y fuera de Dev', () => {
  for (const config of [{...dev, environment: ''}, {...dev, environment: 'PRODUCTION'}, {...dev, supabaseUrl: ''},
    {...dev, supabaseUrl: 'https://otro.supabase.co'}]) {
    assert.equal(ciqProbeHandler(config)(request()).status, 503);
  }
});

test('solo sirve una receta sintética fija, sin admitir identificadores o recetas del cliente', async () => {
  const handler = ciqProbeHandler(dev);
  for (const suffix of ['', '/otra.fit', '/workout.fit?user_id=otro', '/workout.fit?recipe=privada']) {
    assert.equal(handler(request(suffix)).status, 404);
  }
  assert.equal(handler(request('/workout.fit', 'POST')).status, 405);
  const response = handler(request());
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'application/vnd.ant.fit');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), ciqProbeFit());
});

test('la descarga es un FIT estable con títulos originales, dosis y descansos comprobables', () => {
  const bytes = ciqProbeFit();
  assert.deepEqual(bytes, ciqProbeFit());
  const decoder = new Decoder(Stream.fromByteArray(bytes));
  assert.equal(decoder.checkIntegrity(), true);
  const {messages, errors} = decoder.read();
  assert.deepEqual(errors, []);
  assert.equal(messages.workoutMesgs[0].wktName, ciqProbeName);
  assert.deepEqual(messages.exerciseTitleMesgs.map((s: any) => s.wktStepName), ['Dominada con pausa', 'Front lever isométrico']);
  assert.deepEqual(messages.workoutStepMesgs.map((s: any) => s.durationReps ?? s.durationTime), [6, 90, 5, 60, 7]);
  assert.equal(messages.workoutStepMesgs[0].exerciseWeight, 7.5);
});
