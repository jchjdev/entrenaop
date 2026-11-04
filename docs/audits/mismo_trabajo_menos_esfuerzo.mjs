import assert from 'node:assert/strict';

const message = 'En las dos últimas sesiones comparables, anotaste menos esfuerzo para el mismo trabajo.';
const mean = (numbers) => numbers.reduce((sum, value) => sum + value, 0) / numbers.length;
const measured = (value) => Number.isFinite(value) && value >= 0;
const near = (a, b, margin) => measured(a) && measured(b) && Math.abs(a - b) <= margin;
const relativeMargin = (a, b, fraction) => Math.min(a, b) * fraction;
const pace = (rep) => rep.seconds * 1000 / rep.meters;

// Límites de laboratorio para series por distancia. El cálculo no usa datos cardíacos.
function mismatch(a, b) {
  if (!a.completed || !b.completed || !a.recipe || a.recipe !== b.recipe || !a.reps.length ||
      a.reps.length !== b.reps.length || !a.reps.every((rep, i) => {
        const next = b.reps[i];
        return rep.targetMeters > 0 && rep.targetMeters === next.targetMeters &&
          near(rep.meters, rep.targetMeters, rep.targetMeters * 0.02) &&
          near(next.meters, next.targetMeters, next.targetMeters * 0.02);
      })) {
    return 'trabajo distinto o incompleto';
  }
  if (!a.reps.every((rep, i) => {
    const next = b.reps[i];
    return rep.seconds > 0 && next.seconds > 0 &&
      near(pace(rep), pace(next), relativeMargin(pace(rep), pace(next), 0.03));
  })) return 'parciales distintos o desconocidos';

  const aPace = mean(a.reps.map(pace));
  const bPace = mean(b.reps.map(pace));
  if (!near(aPace, bPace, relativeMargin(aPace, bPace, 0.02))) {
    return 'ritmo medio distinto';
  }
  if (a.recoveries.length !== a.reps.length - 1 || b.recoveries.length !== b.reps.length - 1 ||
      !a.recoveries.every((pause, i) => {
        const next = b.recoveries[i];
        return ['quieto', 'caminar', 'trotar'].includes(pause.mode) && pause.mode === next.mode &&
          near(pause.seconds, next.seconds, Math.min(10, relativeMargin(pause.seconds, next.seconds, 0.10))) &&
          near(pause.meters, next.meters, Math.max(10, relativeMargin(pause.meters, next.meters, 0.20)));
      }) || ![a, b].every((run) => measured(run.unassignedPauseSeconds) && run.unassignedPauseSeconds <= 10)) {
    return 'recuperación distinta o sin comprobar';
  }
  if (!a.route || a.route !== b.route || !a.conditions || a.conditions !== b.conditions ||
      !Number.isFinite(a.temperature) || !Number.isFinite(b.temperature) ||
      Math.abs(a.temperature - b.temperature) > 3 || !near(a.wind, b.wind, 10)) {
    return 'condiciones distintas o sin comprobar';
  }
  if (!near(a.warmupSeconds, b.warmupSeconds, 120) || !near(a.cooldownSeconds, b.cooldownSeconds, 120)) {
    return 'preparación o vuelta a la calma distinta';
  }
  return null;
}

function observe(history) {
  // Se eligen las cuatro últimas ejecuciones de la pauta, antes de mirar sus resultados.
  const runs = [...history].sort((a, b) => b.day - a.day).slice(0, 4);
  if (runs.length !== 4 || runs.some((run) => !Number.isInteger(run.day) || !run.id) ||
      new Set(runs.map((run) => run.day)).size !== 4 ||
      new Set(runs.map((run) => run.id)).size !== 4) return 'faltan cuatro días distintos';
  if (runs[0].day - runs[3].day > 56) return 'sesiones demasiado separadas';
  if (runs.some((run) => !Number.isInteger(run.rpe) || run.rpe < 1 || run.rpe > 10 ||
      run.effortScale !== runs[0].effortScale) || !['sesión-1-a-10', 'bloque-1-a-10'].includes(runs[0].effortScale)) {
    return 'esfuerzo ausente o incomparable';
  }
  for (const [i, a] of runs.entries()) {
    for (const b of runs.slice(i + 1)) {
      const reason = mismatch(a, b);
      if (reason) return reason;
    }
  }
  const [firstRecent, secondRecent, firstEarlier, secondEarlier] = runs;
  return Math.max(firstRecent.rpe, secondRecent.rpe) < Math.min(firstEarlier.rpe, secondEarlier.rpe)
    ? message : 'sin descenso repetido';
}

const base = {
  recipe: '8x400', completed: true, route: 'pista-a', conditions: 'seco-mismo-sentido',
  temperature: 16, wind: 5, unassignedPauseSeconds: 0, effortScale: 'sesión-1-a-10',
  warmupSeconds: 900, cooldownSeconds: 600,
  reps: Array.from({length: 8}, () => ({targetMeters: 400, meters: 400, seconds: 92})),
  recoveries: Array.from({length: 7}, () => ({mode: 'caminar', seconds: 90, meters: 72})),
};
const session = (day, rpe, changes = {}) => ({...base, day, id: `test-${day}`, rpe, ...changes});
const history = (firstRecent, secondRecent = firstRecent) => [
  session(1, 7), session(8, 7), session(15, 6, firstRecent), session(22, 6, secondRecent),
];
const alter = (items, index, changes) => items.map((item, i) => i === index ? {...item, ...changes} : item);
const replaceAll = (items, changes) => items.map((item) => ({...item, ...changes}));

const cases = [
  ['Dos esfuerzos menores con las mismas condiciones', history({}), message],
  ['Pequeñas diferencias en parcial y pausa', history({reps: alter(base.reps, 2, {seconds: 94}),
    recoveries: alter(base.recoveries, 3, {seconds: 93})}, {}), message],
  ['Pequeña diferencia en la distancia registrada', history({reps: alter(base.reps, 2, {meters: 398})}), message],
  ['Pequeñas diferencias de temperatura y viento', history({temperature: 17, wind: 8}, {temperature: 18}), message],
  ['Solo una sesión anotada como más fácil', history({}, {rpe: 7}), 'sin descenso repetido'],
  ['Un registro antiguo atípico no define la referencia', [session(1, 9), session(8, 6), session(15, 6), session(22, 6)], 'sin descenso repetido'],
  ['Solo se dispone de una pareja', history({}).slice(2), 'faltan cuatro días distintos'],
  ['Dos actividades del mismo día', history({}, {day: 15}), 'faltan cuatro días distintos'],
  ['Una actividad duplicada en días distintos', history({}, {id: 'test-15'}), 'faltan cuatro días distintos'],
  ['La referencia es de hace varios meses', [session(-100, 7), ...history({}).slice(1)], 'sesiones demasiado separadas'],
  ['Esfuerzo sin registrar', history({}, {rpe: null}), 'esfuerzo ausente o incomparable'],
  ['Esfuerzo de bloque frente a esfuerzo de sesión', history({}, {effortScale: 'bloque-1-a-10'}), 'esfuerzo ausente o incomparable'],
  ['Una repetición menos', history({}, {reps: base.reps.slice(0, 7)}), 'trabajo distinto o incompleto'],
  ['Una repetición acortada', history({}, {reps: alter(base.reps, 7, {meters: 350})}), 'trabajo distinto o incompleto'],
  ['Una sesión interrumpida con parciales registrados', history({}, {completed: false}), 'trabajo distinto o incompleto'],
  ['Un parcial rápido y otro lento se ocultan en la media', history({}, {
    reps: alter(alter(base.reps, 0, {seconds: 88}), 7, {seconds: 96}),
  }), 'parciales distintos o desconocidos'],
  ['Todos los parciales un poco más rápidos y la media cambia', history({
    reps: replaceAll(base.reps, {seconds: 90}),
  }), 'ritmo medio distinto'],
  ['Una pausa larga y otra corta se ocultan en la media', history({}, {
    recoveries: alter(alter(base.recoveries, 0, {seconds: 102}), 1, {seconds: 78}),
  }), 'recuperación distinta o sin comprobar'],
  ['Recuperación más larga', history({recoveries: replaceAll(base.recoveries, {seconds: 120})}), 'recuperación distinta o sin comprobar'],
  ['Misma pausa de reloj, distinta forma de recuperar', history({
    recoveries: replaceAll(base.recoveries, {mode: 'trotar', meters: 180}),
  }), 'recuperación distinta o sin comprobar'],
  ['Pausa de reloj sin conocer el movimiento', history({recoveries: alter(base.recoveries, 0, {meters: null})}), 'recuperación distinta o sin comprobar'],
  ['Pausa fuera del temporizador que no se puede ubicar', history({}, {unassignedPauseSeconds: 65}), 'recuperación distinta o sin comprobar'],
  ['Pausa fuera del temporizador desconocida', history({}, {unassignedPauseSeconds: null}), 'recuperación distinta o sin comprobar'],
  ['Calor distinto', history({temperature: 22}), 'condiciones distintas o sin comprobar'],
  ['Viento distinto', history({wind: 24}), 'condiciones distintas o sin comprobar'],
  ['Cambia el sentido o la superficie', history({conditions: 'mojado-mismo-sentido'}), 'condiciones distintas o sin comprobar'],
  ['Otro recorrido', history({route: 'pista-b'}), 'condiciones distintas o sin comprobar'],
  ['Condiciones sin datos', history({temperature: null}), 'condiciones distintas o sin comprobar'],
  ['Calentamiento más largo con esfuerzo de sesión', history({}, {warmupSeconds: 1200}), 'preparación o vuelta a la calma distinta'],
  ['Una salida antigua favorable no sustituye la última sin datos', [session(-6, 7), ...history({}, {rpe: null})], 'esfuerzo ausente o incomparable'],
];

for (const [label, runs, expected] of cases) {
  assert.equal(observe(runs), expected, label);
  assert.equal(observe([...runs].reverse()), expected, `${label}, orden inverso`);
}

console.table(cases.map(([caso, runs]) => ({caso, resultado: observe(runs)})));
console.log(`${cases.length} casos verificados en ambos órdenes.`);
