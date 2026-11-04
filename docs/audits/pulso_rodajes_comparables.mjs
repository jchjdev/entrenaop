import assert from 'node:assert/strict';

const reference = {
  type: 'rodaje_suave', sensor: 'garmin-a-muneca', route: 'llano-a',
  duration: 1800, pace: 360, temperature: 16, steady: true, coverage: 0.98,
  rpe: 3,
};

function median(values) {
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return (ordered[middle] + ordered[Math.floor((ordered.length - 1) / 2)]) / 2;
}

// Los márgenes son parámetros de laboratorio; el motor no importa este archivo.
function comparable(run, anchor) {
  return run.type === 'rodaje_suave' && run.steady === true &&
    typeof run.sensor === 'string' && run.sensor === anchor.sensor &&
    typeof run.route === 'string' && run.route === anchor.route &&
    Number.isFinite(run.temperature) && Math.abs(run.temperature - anchor.temperature) <= 3 &&
    Number.isFinite(run.duration) && Math.abs(run.duration - anchor.duration) <= 120 &&
    Number.isFinite(run.pace) && Math.abs(run.pace - anchor.pace) <= 5 &&
    run.coverage >= 0.9 && run.coverage <= 1 && run.hr >= 30 && run.hr <= 250 &&
    Number.isFinite(run.rpe) && run.rpe >= 0 && run.rpe <= 10;
}

function observation(runs, anchor, threshold = 5) {
  const copies = Map.groupBy(runs, (run) => run.id);
  const unique = [...copies.values()].flatMap(([first, ...rest]) =>
    rest.every((copy) => Object.keys(first).every((key) => first[key] === copy[key]))
      ? [first] : []);
  const usable = unique.filter((run) => comparable(run, anchor));
  const baseline = usable.filter((run) => run.window === 'before');
  const recent = usable.filter((run) => run.window === 'after');
  if (baseline.length < 3 || recent.length < 3) return 'datos insuficientes';

  const priorHr = median(baseline.map((run) => run.hr));
  const hr = median(recent.map((run) => run.hr)) - priorHr;
  const rpe = median(recent.map((run) => run.rpe)) - median(baseline.map((run) => run.rpe));
  if (hr <= -threshold && rpe <= 0) return 'pulso menor repetido';
  if (hr >= threshold && rpe >= 1) return 'pulso y esfuerzo mayores';
  if (Math.abs(hr) >= threshold) return 'señales discordantes';
  return 'sin señal';
}

function sessions(window, readings, anchor, changes = {}) {
  return readings.map((hr, index) => ({
    ...anchor, window, id: `${window}-${index}`, hr, ...changes,
  }));
}

const scenarios = [
  ['Garmin, pulso menor', [138, 139, 140], {}, 'pulso menor repetido'],
  ['Apple Watch, pulso menor', [138, 139, 140], {}, 'pulso menor repetido', 'apple-a-muneca'],
  ['Garmin, suben pulso y esfuerzo', [152, 153, 154], {rpe: 4}, 'pulso y esfuerzo mayores'],
  ['Apple Watch, suben pulso y esfuerzo', [152, 153, 154], {rpe: 4}, 'pulso y esfuerzo mayores', 'apple-a-muneca'],
  ['Sube pulso con igual esfuerzo', [152, 153, 154], {}, 'señales discordantes'],
  ['Baja pulso con esfuerzo mayor', [138, 139, 140], {rpe: 5}, 'señales discordantes'],
  ['Una lectura aislada', [146, 147, 168], {}, 'sin señal'],
  ['Variación pequeña', [143, 145, 146], {}, 'sin señal'],
  ['Cuatro pulsaciones de diferencia', [141, 142, 143], {}, 'sin señal'],
  ['Más calor', [152, 153, 154], {temperature: 24, rpe: 4}, 'datos insuficientes'],
  ['Temperatura desconocida', [152, 153, 154], {temperature: null}, 'datos insuficientes'],
  ['Cambio de Garmin a Apple Watch', [138, 139, 140], {sensor: 'apple-a-muneca'}, 'datos insuficientes'],
  ['Mismo reloj, cambio a banda', [138, 139, 140], {sensor: 'garmin-a-banda'}, 'datos insuficientes'],
  ['Sensor sin identificar', [138, 139, 140], {sensor: null}, 'datos insuficientes'],
  ['Ruta con cuestas', [152, 153, 154], {route: 'cuestas', rpe: 4}, 'datos insuficientes'],
  ['Ritmo más rápido', [152, 153, 154], {pace: 342, rpe: 4}, 'datos insuficientes'],
  ['Rodaje más largo', [152, 153, 154], {duration: 2400}, 'datos insuficientes'],
  ['Paradas', [138, 139, 140], {steady: false}, 'datos insuficientes'],
  ['Carrera más fuerza', [152, 153, 154], {type: 'mixta'}, 'datos insuficientes'],
  ['Cobertura baja', [138, 139, 140], {coverage: 0.4}, 'datos insuficientes'],
  ['Pulso ausente o inválido', [138, null, 0], {}, 'datos insuficientes'],
  ['Esfuerzo sin registrar', [138, 139, 140], {rpe: null}, 'datos insuficientes'],
  ['Una actividad recibida tres veces', [139, 139, 139], {id: 'after-0'}, 'datos insuficientes'],
  ['Dos recepciones discrepantes', [138, 139, 140], {id: 'after-0'}, 'datos insuficientes'],
  ['Sesgo sostenido invisible en los datos', [138, 139, 140], {}, 'pulso menor repetido'],
];

const results = scenarios.map(([label, readings, changes, expected, sensor = reference.sensor]) => {
  const anchor = {...reference, sensor};
  const runs = [...sessions('before', [145, 146, 147], anchor),
    ...sessions('after', readings, anchor, changes)];
  const result = observation(runs, anchor);
  assert.equal(result, expected, label);
  assert.equal(observation([...runs].reverse(), anchor), expected, `${label}, orden inverso`);
  return {caso: label, '3 lpm': observation(runs, anchor, 3), '5 lpm': result,
    '8 lpm': observation(runs, anchor, 8)};
});

console.table(results);
console.log(`${results.length} casos verificados en ambos órdenes.`);
