"""Comparación reproducible del mismo caso antes y después de las correcciones."""
import argparse
from datetime import date
import hashlib
import json
from pathlib import Path

from render_fas_six_month_case import DAYS, clock, run_description, targets

ROOT=Path(__file__).resolve().parents[1]


def works(week,code):
    return [x for s in week['decision']['sessions'] for x in s['work'] if x['exercise_code']==code]


def doses(week,code):
    return '; '.join(targets(x['dose']) for x in works(week,code)) or '—'


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,default=ROOT/'build/fas-six-month-corrected.json')
    parser.add_argument('--baseline',type=Path,default=ROOT/'docs/audits/FAS_SEIS_MESES_2026_10_16.json')
    parser.add_argument('--output',type=Path,default=ROOT/'docs/audits/FAS_SEIS_MESES_CORREGIDO_2026_10_16.md')
    args=parser.parse_args()
    data=json.loads(args.input.read_text(encoding='utf-8')); old=json.loads(args.baseline.read_text(encoding='utf-8'))
    assert len(data['weeks'])==26 and data['rolled_back'] and data['function_source_restored'] and not data.get('error')
    assert data['scenario']==old['scenario'],'No comparar entradas o capacidad ficticia distintas'
    for w in data['weeks']:
        assert len(w['schedules'])<=4
        all_days={s['scheduled_date'] for s in w['schedules']}
        assert len(all_days)==len(w['schedules'])
        for day in all_days:
            total=sum(s['minutes'] for s in w['decision']['sessions']+w['decision']['running']['sessions'] if s['date']==day)
            assert total<=data['scenario']['availability'][str(date.fromisoformat(day).isoweekday())]
        assert not works(w,'dead_bug')
    n_sessions=sum(len(w['schedules']) for w in data['weeks'])
    n_sets=sum(len(w['executed']) for w in data['weeks'])
    lines=['# Comparación del ensayo FAS de seis meses','',
      f'26 semanas completadas con {n_sessions} sesiones físicas y {n_sets} registros de series/tramos. Entradas, disponibilidad y regla de resultados ficticios iguales al ensayo anterior. La comparación no impone marcas finales ni demuestra eficacia fisiológica.','',
      '## Qué se conserva y qué se ha corregido','',
      'Se conservan las marcas declaradas 9:55, diez flexiones, 1:20 y catorce segundos, las metas 8:20, cincuenta flexiones, 4:00 y 12,5 segundos, las referencias submáximas y cuatro días de 60–75 minutos. Las curvas ficticias y los controles añadidos por la fixture permanecen iguales. No se cambian los resultados para conseguir una respuesta del motor.', '',
      'La coordinación permite incrementos ya acotados de objetivos distintos sin el veto anatómico general. La plancha puede conservar dosis/frecuencia al cambiar de énfasis cuando gesto, protocolo, apoyos, carga y esfuerzo siguen siendo compatibles. La dificultad reduce desde el trabajo conocido; la etiqueta de fase no acredita una subida. Carrera v5 conserva su definición: el adaptador distingue capacidad declarada, trabajo fácil observado y margen para probar un paso pequeño. El dead bug deja de seleccionarse y la plancha alta entra como apoyo separado con segundos y RPE propios.', '',
      'Las metas se contrastan solo con marcas compatibles del protocolo: no con repeticiones con margen, segundos submáximos o sectores. Una marca reciente acreditada permite distinguir metas pendientes y ya alcanzadas al ordenar opciones de igual prioridad deportiva; nunca obliga a prescribir el objetivo máximo. La revisión se muestra en la propuesta. Los controles submáximos conservan su función y sustituyen una exposición ordinaria. No se activa una cadencia de máximos ni se da por implementado un planificador autónomo de exámenes completos.', '',
      'El escenario anterior contiene una evaluación de 2 km y referencias de trabajo de fuerza/agilidad. Los máximos declarados de estas últimas constan como entradas del escenario, pero no se insertan como nuevas evaluaciones oficiales para alterar la comparación. El contraste de metas con evaluaciones completas se verifica además en la batería SQL específica.', '',
      '## Comparación por semana','',
      'Cada dosis separada por punto y coma corresponde a otro día. Los minutos de carrera incluyen sus tramos y recuperaciones publicados. La reducción de una dosis al redistribuir frecuencia se interpreta junto al trabajo semanal completo.','',
      '| Semana | Flexiones antes | Flexiones después | Plancha antes | Plancha después | Carrera antes → después | Días después |',
      '| --- | --- | --- | --- | --- | --- | --- |']
    for before,after in zip(old['weeks'],data['weeks']):
        run_old=sum(s['minutes'] for s in before['decision']['running']['sessions'])
        run_new=sum(s['minutes'] for s in after['decision']['running']['sessions'])
        lines.append(f'| {after["number"]} | {doses(before,"push_up_standard")} | {doses(after,"push_up_standard")} | {doses(before,"front_plank_forearms")} | {doses(after,"front_plank_forearms")} | {run_old} → {run_new} min | {len(after["schedules"])} |')
    lines+=['','## Sesiones publicadas después de la corrección','',
      'El contenido se agrupa por modalidad. El campo de orden muestra la indicación del coordinador; el JSON conserva cada registro ficticio completo.','']
    for w in data['weeks']:
        lines += [f'### Semana {w["number"]} desde {w["week_start"]}','']
        runs={s['date']:s for s in w['decision']['running']['sessions']}; strength={s['date']:s for s in w['decision']['sessions']}
        for scheduled in w['schedules']:
            day=scheduled['scheduled_date']; r=runs.get(day); p=strength.get(day)
            total=(r['minutes'] if r else 0)+(p['minutes'] if p else 0)
            lines += [f'**{DAYS[date.fromisoformat(day).weekday()].capitalize()} {day}: {total} minutos.**','']
            if p and r:lines.append('Orden de propuesta: '+('rendimiento antes de carrera.' if p['session_order']=='performance_first' else 'carrera antes de rendimiento.'))
            if r:lines.append(f'- Carrera: {r["name"]}. {run_description(r)}.')
            if p:
                lines.append(f'- Preparación específica: {clock(p["warm_up_seconds"])}; cierre incluido en el presupuesto.')
                for x in p['work']:
                    first=x['dose']['task'].get('policy_version','').startswith('support_familiarization')
                    effort=x['dose']['task'].get('target_rir'); rpe=x['dose']['task'].get('target_rpe')
                    label=targets(x['dose']); label=('hasta '+label) if first else label
                    lines.append(f'- **{x["name"]}**: {label}; descanso {clock(x["dose"]["rest_seconds"])}'
                      +(f'; RIR pautado {effort}' if effort is not None else '')+(f'; RPE máximo {rpe}' if rpe is not None else '')
                      +f'. {x["phase"]} · {x["outcome"]}. {x["reason"]}')
            lines.append('')
        runs_data=w['decision']['running']
        capacity=runs_data.get('capacity_evidence',{})
        observed=capacity.get('observed_continuous_minutes')
        observed_text=f'{observed} min' if observed is not None else 'sin dos registros comparables'
        lines.append(f'Capacidad de carrera declarada: {capacity.get("declared_minutes")} min. Observación continua comparable: {observed_text}. Límite del ensayo siguiente: {capacity.get("trial_minutes")} min. Este último no se presenta como capacidad ya conseguida.')
        lines.append('')
    lines+=['## Controles y confirmaciones ficticias','',
      'Las confirmaciones de salud y contexto y los controles siguientes fueron aportados por la fixture; no se atribuyen a una programación autónoma de máximos.','',
      '| Tras semana | Control aportado | Estado posterior |','| --- | --- | --- |']
    for e in data['events']:
        lines.append(f'| {e["week"]} | {clock(e["manual_running_control_seconds"]) if e.get("manual_running_control_seconds") else "Sin control nuevo"} | {e["after"]["status"]} |')
    lines += ['','## Verificación y límites','',
      'La prueba usa los RPC reales de desarrollo y siempre termina con ROLLBACK; se comprueba la restauración de funciones. No se modifican sesiones publicadas, marcas reales ni producción. Los registros ficticios acreditan el comportamiento del software, no que una persona alcance las metas. La aceptación física sigue pendiente.','',
      'La revisión deportiva del catálogo activo y sus pendientes se conserva en `docs/CATALOGO_ACTIVO_RENDIMIENTO.md`. La plancha alta no se declara superior al dead bug por evidencia comparativa; responde a la preferencia de Javier y tiene un papel isométrico diferente.','']
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text('\n'.join(lines),encoding='utf-8')
    fields={'name','exercise_code','objective_key','role','phase','outcome','reason','frequency','exposure_index','dose','stimulus','block','goal_review','goal_priority','control'}
    evidence={'scenario':data['scenario'],'baseline':str(args.baseline.relative_to(ROOT)),'rolled_back':data['rolled_back'],
              'function_source_restored':data['function_source_restored'],'events':data['events'],'weeks':[]}
    for w in data['weeks']:
        p=w['decision']
        evidence['weeks'].append({'number':w['number'],'week_start':w['week_start'],
          'decision':{'policy_version':p['policy_version'],'goal_reviews':p.get('goal_reviews'),
                      'running':{k:v for k,v in p['running'].items() if k not in ('input_snapshot','evidence')},
                      'sessions':[{k:v for k,v in s.items() if k!='work'}|{'work':[{k:v for k,v in x.items() if k in fields} for x in s['work']]} for s in p['sessions']]},
          'executed':w['executed'],'state_after':w['state_after']})
    args.output.with_suffix('.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'weeks':26,'sessions':n_sessions,'sets':n_sets,'comparison':str(args.output),
                     'evidence_sha256':hashlib.sha256(args.output.with_suffix('.json').read_bytes()).hexdigest()}))


if __name__=='__main__':main()
