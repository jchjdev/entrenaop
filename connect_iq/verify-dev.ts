import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {ciqProbeFit, ciqProbeVersion} from '../supabase/functions/_shared/garmin/ciq_probe.ts';

// Destino fijo Dev: este verificador no acepta URLs ni credenciales de producción.
const endpoint = 'https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-ciq-probe/workout.fit';
const response = await fetch(endpoint, {redirect: 'error', signal: AbortSignal.timeout(20000)});
assert.equal(response.status, 200);
assert.equal(response.headers.get('X-EntrenaOP-Version'), ciqProbeVersion);
assert.equal(response.headers.get('Content-Type'), 'application/vnd.ant.fit');
assert.equal(response.headers.get('Cache-Control'), 'no-store');
const bytes = new Uint8Array(await response.arrayBuffer());
assert.deepEqual(bytes, ciqProbeFit());
for (const [url, method, status] of [[endpoint + '?user_id=otro', 'GET', 404], [endpoint, 'POST', 405]] as const) {
  assert.equal((await fetch(url, {method, redirect: 'error', signal: AbortSignal.timeout(20000)})).status, status);
}
console.log({environment: 'entrenaop-dev', version: ciqProbeVersion, bytes: bytes.length,
  sha256: createHash('sha256').update(bytes).digest('hex'), identical: true});
