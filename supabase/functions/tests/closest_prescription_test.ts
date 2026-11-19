import {test} from 'node:test';
import assert from 'node:assert/strict';
import {selectClosestPrescription} from '../_shared/device_activity/return_service.ts';

const activity={startedAt:'2026-11-19T08:31:17.000Z',offsetSeconds:3600};
const candidate=(id:string,date:string,current=true)=>({scheduled_id:id,revision:`version-${id}-${date}`,
  snapshot:{date},current});

test('elige mañana frente a una pauta idéntica de cuatro días antes, sin depender del orden',()=>{
  const choices=[candidate('older','2026-11-15'),candidate('tomorrow','2026-11-20')];
  for(const ordered of [choices,[...choices].reverse()]){
    assert.equal(selectClosestPrescription(ordered,activity).candidate?.scheduled_id,'tomorrow');
  }
});

test('prefiere el mismo día y permite que gane una pauta pasada frente a mañana',()=>{
  assert.equal(selectClosestPrescription([candidate('tomorrow','2026-11-20'),candidate('today','2026-11-19')],activity)
    .candidate?.scheduled_id,'today');
  assert.equal(selectClosestPrescription([candidate('older','2026-11-16'),candidate('yesterday','2026-11-18')],activity)
    .candidate?.scheduled_id,'yesterday');
});

test('el empate entre días anterior y siguiente o citas del mismo día conserva revisión',()=>{
  for(const dates of [['2026-11-18','2026-11-20'],['2026-11-19','2026-11-19']]){
    const answer=selectClosestPrescription(dates.map((date,i)=>candidate(String(i),date)),activity);
    assert.equal(answer.candidate,null);assert.equal(answer.code,'ambiguous_prescription');
  }
});

test('una reprogramación compara la fecha vigente, sin usar la retirada para ganar cercanía',()=>{
  const answer=selectClosestPrescription([candidate('moved','2026-11-17'),candidate('moved','2026-11-19',false),
    candidate('yesterday','2026-11-18')],activity);
  assert.equal(answer.candidate?.scheduled_id,'yesterday');
});

test('versiones de una misma cita no son dos candidatas y se prefiere su versión vigente',()=>{
  const current=candidate('one','2026-11-20');
  const answer=selectClosestPrescription([candidate('one','2026-11-19',false),current],activity);
  assert.equal(answer.candidate,current);
});

test('la receta retirada más cercana bloquea el cierre de otra cita más lejana',()=>{
  const answer=selectClosestPrescription([candidate('retired','2026-11-19',false),candidate('next','2026-11-20')],activity);
  assert.equal(answer.candidate,null);assert.equal(answer.code,'stale_prescription');
  assert.equal(selectClosestPrescription([candidate('retired','2026-11-15',false),candidate('next','2026-11-20')],activity)
    .candidate?.scheduled_id,'next');
});

test('elige con el día local observado al cruzar medianoche en ambos offsets',()=>{
  const choices=[candidate('nineteen','2026-11-19'),candidate('twenty','2026-11-20')];
  assert.equal(selectClosestPrescription(choices,{startedAt:'2026-11-19T23:30:00Z',offsetSeconds:3600})
    .candidate?.scheduled_id,'twenty');
  assert.equal(selectClosestPrescription(choices,{startedAt:'2026-11-20T00:30:00Z',offsetSeconds:-3600})
    .candidate?.scheduled_id,'nineteen');
});

test('un aviso recibido después no cambia el día de realización usado para decidir',(t)=>{
  t.mock.method(Date,'now',()=>Date.parse('2026-11-19T12:00:00Z'));
  const choices=[candidate('performed','2026-11-15'),candidate('next','2026-11-16')];
  assert.equal(selectClosestPrescription(choices,{startedAt:'2026-11-15T10:00:00Z',offsetSeconds:0})
    .candidate?.scheduled_id,'performed');
});

test('compara días civiles también al cambiar de mes y año',()=>{
  assert.equal(selectClosestPrescription([candidate('old','2026-12-28'),candidate('next','2027-01-01')],
    {startedAt:'2026-12-31T10:00:00Z',offsetSeconds:0}).candidate?.scheduled_id,'next');
});

test('no amplía la ventana de un día antes a siete después ni normaliza fechas imposibles',()=>{
  for(const date of ['2026-11-21','2026-11-11','2026-02-30','2026-11-19T00:00:00Z','invalid']){
    const answer=selectClosestPrescription([candidate('bad',date),candidate('good','2026-11-19')],activity);
    assert.equal(answer.candidate,null);assert.equal(answer.code,'review_required');
  }
  assert.equal(selectClosestPrescription([candidate('seventh','2026-11-12')],activity).candidate?.scheduled_id,'seventh');
});

test('sin offset, reloj válido o identidad de cita no inventa un desempate',()=>{
  const choices=[candidate('one','2026-11-19')];
  for(const offsetSeconds of [null,61,50460]){
    assert.equal(selectClosestPrescription(choices,{...activity,offsetSeconds}).code,'review_required');
  }
  assert.equal(selectClosestPrescription(choices,{...activity,startedAt:'invalid'}).code,'review_required');
  assert.equal(selectClosestPrescription([{...choices[0],scheduled_id:null}],activity).code,'review_required');
  assert.equal(selectClosestPrescription([],activity).code,'prescription_not_identified');
});

test('un contexto con dos revisiones vigentes para la misma cita exige revisión',()=>{
  assert.equal(selectClosestPrescription([candidate('same','2026-11-19'),candidate('same','2026-11-20')],activity)
    .code,'review_required');
});
