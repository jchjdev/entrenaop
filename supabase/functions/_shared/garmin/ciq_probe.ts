import {garminStrengthFit} from './strength_fit.ts';

export const ciqProbeName = 'EntrenaOP IQ prueba 01';
export const ciqProbeVersion = 'ciq-probe-1';
const devUrl = 'https://sxbxfjqgoddzhtcyhalw.supabase.co';

// Receta pública inventada: nunca consultar cuentas, citas ni plantillas privadas.
export function ciqProbeFit(): Uint8Array {
  return garminStrengthFit({
    sport: 'strength', name: ciqProbeName, description: 'Ensayo técnico sin cuenta. No es una pauta personal.',
    source: 'coach', date: '2026-10-26',
    blocks: [{order_index: 0, format: 'straight_sets', rounds: 1, rest_after_seconds: 0, time_cap_seconds: null,
      items: [
        {order_index: 0, exercise_code: null, exercise_name: 'Dominada con pausa', notes: 'Prueba de título propio', sets: [
          {order_index: 0, target_reps: 6, target_load_kg: 7.5, rest_after_seconds: 90},
          {order_index: 1, target_reps: 5, rest_after_seconds: 60}]},
        {order_index: 1, exercise_code: null, exercise_name: 'Front lever isométrico', notes: 'Prueba de tiempo', sets: [
          {order_index: 0, target_duration_seconds: 7, rest_after_seconds: 0}]},
      ]}],
  }, {serialNumber: 26010001, createdAt: new Date('2026-10-26T12:00:00Z')});
}

export function ciqProbeHandler(config: {environment: string; supabaseUrl: string}) {
  // Dos condiciones independientes impiden servir el ensayo en producción.
  const enabled = config.environment === 'DEVELOPMENT' && config.supabaseUrl === devUrl;
  const bytes = enabled ? ciqProbeFit() : null;
  return (request: Request): Response => {
    const headers = {'Cache-Control': 'no-store', 'X-EntrenaOP-Version': ciqProbeVersion};
    if (!bytes) return new Response(null, {status: 503, headers});
    if (request.method !== 'GET') return new Response(null, {status: 405, headers: {...headers, Allow: 'GET'}});
    const url = new URL(request.url);
    if (!url.pathname.endsWith('/garmin-ciq-probe/workout.fit') || url.search) {
      return new Response(null, {status: 404, headers});
    }
    return new Response(new Uint8Array(bytes), {headers: {...headers,
      'Content-Type': 'application/vnd.ant.fit',
      'Content-Disposition': 'attachment; filename="entrenaop-iq-prueba-01.fit"',
    }});
  };
}
