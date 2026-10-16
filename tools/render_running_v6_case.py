"""Compara la repetición instalada con STR-041 y transcribe la pauta real."""
from collections import Counter,defaultdict
from datetime import date
import hashlib
import json
from pathlib import Path
from render_fas_six_month_case import clock,targets,run_description

ROOT=Path(__file__).resolve().parents[1]
raw=json.loads((ROOT/'build/fas-six-month-running-v6-installed.json').read_text(encoding='utf8'))
baseline_path=ROOT/'docs/audits/CONTROLES_AUTOMATICOS_SEIS_MESES_2026_10_16.json'
old=json.loads(baseline_path.read_text(encoding='utf8'))
assert raw['scenario']==old['scenario'],'Han cambiado las entradas o las capacidades ficticias'
assert len(raw['weeks'])==26 and raw['rolled_back'] and raw['function_source_restored'] and not raw.get('error')
assert raw['weeks'][-1]['state_after']['status']=='complete'
assert not any(e.get('manual_running_control_seconds') for e in raw['events'])

def count_variants(data):
    return Counter(s['variant_code'] for w in data['weeks'] for s in w['decision']['running']['sessions'])

before=count_variants(old);after=count_variants(raw)
recipes={s['variant_code']:s for d in (old,raw) for w in d['weeks'] for s in w['decision']['running']['sessions']}

def format_label(session):
    if session['family']=='E':return 'Rodaje fácil'
    if session['family']=='C':return 'Control de 2 km'
    work=[x for x in session['segments'] if x['role']=='work']
    pieces=Counter((x.get('seconds'),x.get('meters')) for x in work)
    return ' + '.join(f'{count}×{meters:g} m' if meters is not None else f'{count}×{clock(seconds)}'
                    for (seconds,meters),count in pieces.items())
families=Counter();controls=Counter();sessions=results=0
evidence={'scenario':raw['scenario'],'baseline_sha256':hashlib.sha256(baseline_path.read_bytes()).hexdigest(),
 'migration_sha256':hashlib.sha256((ROOT/'supabase/migrations/20261016202528_running_format_progression_v6.sql').read_bytes()).hexdigest(),
 'control_rotation_migration_sha256':hashlib.sha256((ROOT/'supabase/migrations/20261016205040_running_control_rotation_evidence.sql').read_bytes()).hexdigest(),
 'events':raw['events'],'rolled_back':True,'function_source_restored':True,'weeks':[]}
for w in raw['weeks']:
    p=w['decision'];r=p['running'];assert r['policy_version']=='running_2k_v6'
    assert r['coordination_evidence_policy_version']=='running_control_evidence_v1'
    assert not any(o['session']['family']=='C' for o in r['evidence']['observations'])
    assert len(w['schedules'])<=4
    for s in w['schedules']:
        day=s['scheduled_date'];limit=raw['scenario']['availability'][str(date.fromisoformat(day).isoweekday())]
        total=sum(x['minutes'] for x in p['sessions']+r['sessions'] if x['date']==day)
        assert total<=limit and s['estimated_duration_minutes']==total,(w['number'],day,total,limit)
    for s in r['sessions']:
        families[s['family']]+=1
        if s['family']=='C':
            # El control no tiene ritmo obligatorio: el presupuesto conservador
            # de trabajo está separado del tiempo real que registrará la persona.
            seconds=s['work_seconds']+sum(x.get('seconds',0) for x in s['segments'] if x['role']!='work')
        else:
            seconds=sum(x.get('seconds') or (x['meters']*x['pace_max']+999)//1000 for x in s['segments'])+sum(x.get('recovery_seconds',0) for x in s['segments'])
        assert seconds==s['minutes']*60,(w['number'],s['variant_code'],seconds)
    c=p.get('control_schedule',{}).get('scheduled',[]);assert len(c)<=1
    for x in c:
        controls[x['profile']]+=1
        assert (date.fromisoformat(raw['scenario']['exam'])-date.fromisoformat(x['date'])).days>14
    dimensions={x['dimension'] for x in r['changes']}
    assert not ('easy_minutes' in dimensions and dimensions & {'dose_step','speed','anchor_recalibration','quality_frequency_or_dose'})
    sessions+=len(w['schedules']);results+=len(w['executed'])
    evidence['weeks'].append({'number':w['number'],'week_start':w['week_start'],
      'running':{k:v for k,v in r.items() if k not in ('evidence','input_snapshot')},
      'strength_sessions':p['sessions'],'control_schedule':p.get('control_schedule'),
      'goal_reviews':p.get('goal_reviews'),'schedules':w['schedules'],'executed':w['executed'],
      'state_after':w['state_after']})

target=ROOT/'docs/audits/FAS_SEIS_MESES_CARRERA_V6_2026_10_16.json'
target.write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf8')
lines=['# Caso FAS de seis meses: selección y progresión de carrera v6','',
 'Repetición de STR-041, con las mismas marcas iniciales (9:55, 10 flexiones, 1:20 de plancha y 14 s de circuito), metas (8:20, 50, 4:00 y 12,5 s), cuatro días de 60–75 min, material, contexto inicial y capacidades ficticias. Los resultados responden a lo pautado, sin forzar formatos ni metas ni insertar marcas manuales de carrera.','',
 f'26 semanas, {sessions} sesiones físicas y {results} registros. Estado final completo. Todo el ensayo termina con ROLLBACK y las funciones recuperan su definición instalada. No quedan usuarios ficticios ni se modifican datos de deportistas.','',
 'La trayectoria es favorable y ficticia: verifica decisiones y contratos de software; no acredita eficacia deportiva ni que una persona alcance las metas.','',
 '## Comparación con la política anterior','',
 '| Formato de carrera | STR-041 (v5) | Repetición (v6) |','| --- | --- | --- |']
for key in sorted(set(before)|set(after)):
    lines.append(f'| {format_label(recipes[key])} | {before[key]} | {after[key]} |')
old_minutes=sum(s['minutes'] for w in old['weeks'] for s in w['decision']['running']['sessions'])
new_minutes=sum(s['minutes'] for w in raw['weeks'] for s in w['decision']['running']['sessions'])
lines+=['',f'Minutos totales prescritos de carrera, incluidos calentamiento/cierre y presupuesto de controles: '
 f'{old_minutes} antes y {new_minutes} con v6. El número de salidas cambia al preservar una calidad completa antes de ampliar frecuencia; no indica por sí solo una pérdida o una mejora deportiva.','',
 f'Distribución de carrera: {families["E"]} rodajes fáciles, {families["T"]} sesiones sostenidas, '
 f'{families["V"]} de intervalos aeróbicos, {families["S"]} específicas y {families["C"]} controles de 2 km. '
 f'Controles totales: {controls["push_up_standard"]} de flexiones, {controls["front_plank_forearms"]} de plancha, '
 f'{controls["running_2000m_v1"]} de 2 km y {controls["slalom_ball_course_16m"]} de agilidad.','',
 'Las diferencias corresponden a las decisiones del motor. No se han añadido recetas nuevas ni cambiado ritmos, pausas o calentamiento para fabricar variedad. El repertorio no tiene obligación de aparecer entero en este perfil.','',
 '## Pauta completa por semana','',
 'Los tiempos de carrera incluyen calentamiento y cierre. Los bloques que comparten día se contabilizan con el coste conjunto; no se suman dos calentamientos ficticios. RIR es margen de repeticiones, RPE es esfuerzo; los controles no piden RIR.','']
for w in raw['weeks']:
    p=w['decision'];r=p['running']
    lines += [f'### Semana {w["number"]} · {w["week_start"]}', '',
       f'Carrera: fase {dict(general="general",build="desarrollo",specific="específica",taper="puesta a punto").get(r["phase"],r["phase"])}, '
       f'{dict(normal="trabajo normal",intensity_deload="descarga de intensidad",global_deload="reducción global",reentry="reentrada",taper="puesta a punto").get(r["mode"],r["mode"])}. {r["reason"]}.','']
    days=defaultdict(list)
    for s in r['sessions']:
        days[s['date']].append(f'**Carrera · {format_label(s)} · {s["minutes"]} min:** {run_description(s)}.')
    for s in p['sessions']:
        for work in s['work']:
            dose=work['dose'];task=dose['task']
            text=targets(dose)
            if dose.get('control'):
                match task['measurement']:
                    case 'REPS_IN_TIME':text=f'Repeticiones válidas durante {clock(task["fixed_duration_seconds"])}; sin una cifra objetivo'
                    case 'REPS':text='Repeticiones válidas del protocolo; sin una cifra objetivo'
                    case 'DURATION':text=f'Postura válida, con techo de {clock(task["target_value"])}'
                    case 'TIME_FOR_COURSE':text='Un intento válido del circuito completo; registrar el tiempo real'
                    case _:text='Control del protocolo'
            margin=(f'; margen {task["target_rir"]:g}' if task.get('target_rir') is not None else '')
            effort=(f'; esfuerzo previsto {task["target_rpe"]:g}/10' if task.get('target_rpe') is not None else '')
            rest=f'; descanso {clock(dose["rest_seconds"])}' if dose.get('rest_seconds') else ''
            days[s['date']].append(f'**{work["name"]}:** {text}{rest}{margin}{effort}.')
    for day,items in sorted(days.items()):
        total=next(s['estimated_duration_minutes'] for s in w['schedules'] if s['scheduled_date']==day)
        lines += [f'**{day} · sesión completa {total} min**','']+[f'- {item}' for item in items]+['']
    for c in p.get('control_schedule',{}).get('scheduled',[]):lines += [f'Control: {c["question"]}','']
    for record in w['executed']:
        task=record.get('prescription') or {};result=record.get('result') or {}
        if task.get('policy_version')!='adaptive_protocol_control_v1':continue
        value=result.get('value')
        match task['measurement']:
            case 'REPS_IN_TIME':observed=f'{value:g} repeticiones en {clock(task["fixed_duration_seconds"])}'
            case 'DURATION':observed=clock(value)+' de postura válida'
            case 'TIME_FOR_DISTANCE':observed=clock(value)+' en 2 km'
            case 'TIME_FOR_COURSE':observed=f'{value:g} s en el circuito'
            case _:observed=f'{value:g}'
        lines += [f'Resultado **simulado** del control: {observed}; esfuerzo {result.get("rpe")} / 10.','']
lines += ['## Procedencia','',f'Evidencia compacta: `{target.name}`. SHA-256: `{hashlib.sha256(target.read_bytes()).hexdigest()}`. Los RPC instalados deciden y materializan las sesiones; esta herramienta únicamente verifica y transcribe.']
report=target.with_suffix('.md');report.write_text('\n'.join(lines)+'\n',encoding='utf8')
print(json.dumps({'weeks':26,'sessions':sessions,'records':results,'families':dict(families),
                  'controls':dict(controls),'variants':dict(after),'report':str(report)},ensure_ascii=False))
