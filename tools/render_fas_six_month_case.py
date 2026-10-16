"""Transcribe las decisiones y los resultados del ensayo, sin crear sesiones."""
import argparse
from collections import defaultdict
from datetime import date
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DAYS = ['lunes','martes','miércoles','jueves','viernes','sábado','domingo']


def num(value):
    return f'{float(value):g}'.replace('.', ',')


def clock(value):
    seconds = round(float(value))
    return f'{seconds//60}:{seconds%60:02}'


def targets(dose):
    task = dose['task']
    values = dose['targets']
    mode = task['measurement']
    if mode == 'PASS_FAIL':
        return f'{len(values)} intento técnico' if len(values)==1 else f'{len(values)} intentos técnicos'
    if mode == 'DURATION':
        return ' + '.join(clock(v) for v in values)
    if mode == 'TIME_FOR_COURSE':
        return ' + '.join(num(v)+' s' for v in values)
    text = ' + '.join(num(v) for v in values)+' repeticiones'
    if task.get('external_load_kg') is not None:
        text += f" con {num(task['external_load_kg'])} kg"
    if mode == 'REPS_IN_TIME':
        text += f" en {clock(task['fixed_duration_seconds'])} por serie"
    return text


def run_description(s):
    parts=[]
    for seg in s.get('segments',[]):
        duration = clock(seg['seconds']) if seg.get('seconds') else str(seg.get('meters'))+' m'
        role = {'warmup':'calentamiento','work':'trabajo','cooldown':'vuelta a la calma'}.get(seg['role'],seg['role'])
        if seg.get('pace_min') is not None:
            duration += f" a {clock(seg['pace_min'])}–{clock(seg['pace_max'])}/km"
        if seg.get('recovery_seconds'):
            duration += f"; recuperación {clock(seg['recovery_seconds'])}"
        parts.append(role+' '+duration)
    return '; '.join(parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,default=ROOT/'build/fas-six-month-case.json')
    parser.add_argument('--output',type=Path,default=ROOT/'docs/audits/FAS_SEIS_MESES_2026_10_16.md')
    args=parser.parse_args()
    data=json.loads(args.input.read_text(encoding='utf-8'))
    if len(data['weeks'])!=26 or not data['rolled_back'] or not data['function_source_restored'] or data.get('error'):
        raise RuntimeError('El ensayo debe estar completo, deshecho y sin errores antes de transcribirlo.')
    baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    total_days=sum(len(w['schedules']) for w in data['weeks'])
    total_sets=sum(len(w['executed']) for w in data['weeks'])
    lines=['# Ensayo FAS de seis meses con cuatro días disponibles','',
      'Ensayo solicitado por Javier el 16/10/2026. Esta transcripción procede de los RPC instalados de desarrollo; no se han escrito rutinas a mano ni cambiado sus políticas deportivas.', '',
      f'Código de partida: `{baseline}`. {len(data["weeks"])} semanas, {total_days} sesiones físicas y {total_sets} registros de series/tramos, incluidos calentamientos. Transacción deshecha con `ROLLBACK`; definiciones originales restauradas y comprobadas.', '',
      '## Entradas y supuestos', '',
      '| Prueba | Marca inicial declarada | Meta solicitada |',
      '| --- | --- | --- |',
      '| 2 km | 9:55 | 8:20 |',
      '| Flexiones en dos minutos | 10 | 50 |',
      '| Plancha | 1:20 | 4:00 |',
      '| Circuito de 16 m con pelota | 14 s | 12,5 s |','',
      'Persona ficticia de 30 años, sin molestias, dos salidas semanales previas (50, 55, 60 y 60 minutos semanales), capaz de correr 30 minutos cómodos. Lunes y viernes: 60 minutos; miércoles y sábado: 75 minutos. Inicio 19/10/2026; examen 19/04/2027.', '',
      'Se ha supuesto acceso al material del circuito y a banco, barra y discos para comprobar la entrada autónoma de accesorios. No se deduce ese material de las marcas. Referencias ficticias de trabajo: 7 y 6 flexiones con RIR 3, planchas de 50 y 45 segundos a RPE 7 y dos intentos del circuito en 14,3 y 14,5 segundos. Estas referencias se distinguen de los máximos declarados.', '',
      'La marca de carrera y su meta intervienen en carrera v5. Las metas numéricas de fuerza se guardan; aún no dirigen por sí mismas dosis ni prioridades. La referencia libre de flexiones no acredita ritmo durante dos minutos: no se ha añadido una calibración temporal manual para ocultar esa limitación.', '',
      '## Resultados ficticios y alcance', '',
      'El deportista completa las series prescritas con técnica válida y sin molestias. En flexiones registra las repeticiones pautadas y un RIR entero creciente, limitado a 10 en el formulario, según la capacidad ficticia. En plancha completa el tiempo submáximo y registra esfuerzo entero. Las prácticas de agilidad se registran como intentos técnicos válidos; no como un tiempo máximo de circuito. En banca, la primera carga elegida por este usuario ficticio es 20 kg; no es una prescripción del motor ni una recomendación universal.', '',
      'Los rodajes se registran a RPE 4 y la calidad a RPE 6, respetando el ritmo y las recuperaciones publicados. En la semana 8 se declara un rodaje más exigente (RPE 6). La capacidad de fondo inventada tiene mesetas, pero no se inyectan máximos semanales en el motor. Que se suponga una mejora no demuestra que la rutina la cause.', '',
      'La curva hipotética solicitada acaba en 50 flexiones y 4:00 de plancha. Son condiciones ficticias del escenario, no un resultado calculado o validado por la app. No se crea un test final ficticio dentro de la agenda para hacer pasar por implementado el programador de pruebas máximas, que sigue pendiente.', '',
      '## Resumen exacto de las 26 semanas','',
      'Las dosis separadas por punto y coma corresponden a exposiciones distintas. Las repeticiones dentro de una exposición se muestran con «+». Los minutos de carrera incluyen sus tramos propios; el detalle por día conserva el presupuesto conjunto.', '',
      '| Semana | Días pautados | Carrera | Flexiones por exposición | Plancha por exposición | Agilidad |',
      '| --- | --- | --- | --- | --- | --- |']
    evidence={'scenario':data['scenario'],'weeks':[],'events':data['events'],
              'rolled_back':data['rolled_back'],'function_source_restored':data['function_source_restored'],
              'source_commit':baseline}
    summary=[]
    for week in data['weeks']:
        p=week['decision']; work=[x for s in p['sessions'] for x in s['work']]
        flex='; '.join(targets(x['dose']) for x in work if x['exercise_code']=='push_up_standard') or '—'
        plank='; '.join(targets(x['dose']) for x in work if x['exercise_code']=='front_plank_forearms') or '—'
        agility='; '.join(x['name']+': '+targets(x['dose']) for x in work if x['objective_key']=='legacy:agility_speed_circuit') or '—'
        runs='; '.join(s['name']+' '+str(s['minutes'])+' min' for s in p['running']['sessions'])
        row=f'| {week["number"]} | {len(week["schedules"])} | {runs} | {flex} | {plank} | {agility} |'
        lines.append(row); summary.append(row)
        work_fields={'name','exercise_code','objective_key','role','phase','outcome','reason','frequency',
                     'exposure_index','dose','stimulus','policy_version','block','work_minutes','selection_reason'}
        evidence['weeks'].append({'number':week['number'],'week_start':week['week_start'],
          'decision':{'running':{k:v for k,v in p['running'].items() if k not in ['input_snapshot','evidence']},
                      'sessions':[{k:v for k,v in s.items() if k!='work'}|{'work':[{k:v for k,v in x.items() if k in work_fields} for x in s['work']]} for s in p['sessions']],
                      'pending':p['pending'],'coverage':p['coverage'],'policy_version':p['policy_version']},
          'executed':week['executed'],'state_after':week['state_after']})
    lines+=['','## Intervenciones explícitas durante el ensayo','',
      'El cierre de sesiones publica la siguiente semana automáticamente cuando puede. Cuando aparece revisión, el usuario ficticio confirma salud y disponibilidad; no reescribe las semanas de carga ya registradas. Se aporta un control de carrera solo si la referencia supera 28 días. Estos controles son entradas añadidas por el ensayo, no pruebas que la app haya pautado autónomamente.','',
      '| Después de la semana | Control ficticio de 2 km | Motivo devuelto antes de confirmar |',
      '| --- | --- | --- |']
    for event in data['events']:
        mark=clock(event['manual_running_control_seconds']) if 'manual_running_control_seconds' in event else 'No se añade'
        lines.append(f'| {event["week"]} | {mark} | {event["before"].get("message","")} |')
    lines+=['','## Sesiones publicadas y registro ficticio','',
      'Cada fecha muestra la composición publicada y después lo registrado. «No pautado» significa que la app no creó una sesión ese día; no se han rellenado cuatro días por obligación. Las tareas comunes de calentamiento y cierre se incluyen en el presupuesto de cada sesión. El detalle de cada tramo, incluidos los calentamientos registrados, se conserva en el JSON adjunto.','']
    for week in data['weeks']:
        p=week['decision']; runs={s['date']:s for s in p['running']['sessions']}; strength={s['date']:s for s in p['sessions']}
        lines += [f'### Semana {week["number"]} desde {week["week_start"]}','']
        for schedule in week['schedules']:
            day=schedule['scheduled_date']; r=runs.get(day); s=strength.get(day)
            total=(r['minutes'] if r else 0)+(s['minutes'] if s else 0)
            weekday=date.fromisoformat(day).weekday()
            lines += [f'**{DAYS[weekday].capitalize()} {day}: {total} min presupuestados.**','']
            if r and s:
                lines += [('Orden indicado por la propuesta: rendimiento antes de carrera.' if s.get('session_order')=='performance_first'
                           else 'Orden indicado por la propuesta: carrera antes de rendimiento.'),
                          'El listado siguiente agrupa el contenido por modalidad.','']
            if r:
                lines.append(f'- Carrera: **{r["name"]}**, {r["minutes"]} min. {run_description(r)}. RPE máximo pautado: {r.get("rpe_ceiling","sin dato")}/10.')
            if s:
                lines.append(f'- Preparación específica de fuerza/rendimiento: {clock(s["warm_up_seconds"])}. {s.get("warm_up_instructions","")}')
                for x in s['work']:
                    task=x['dose']['task']; effort=''
                    if task.get('target_rir') is not None: effort=f'; margen pautado {num(task["target_rir"])} repeticiones'
                    if task.get('target_rpe') is not None: effort=f'; esfuerzo máximo pautado {num(task["target_rpe"])}/10'
                    dose_text=targets(x['dose'])
                    if task.get('policy_version')=='support_familiarization_v1':
                        dose_text='Hasta '+dose_text
                    lines.append(f'- **{x["name"]}**: {dose_text}; descanso {clock(x["dose"]["rest_seconds"])}{effort}. Fase `{x["phase"]}`; decisión `{x["outcome"]}`. {x["reason"]}')
            actual=[x for x in week['executed'] if x['date']==day]
            groups=defaultdict(list)
            for x in actual:
                if x['prescription']:
                    groups[(x['block_order'],x['prescription']['exercise_code'])].append(x)
            lines += ['','Registro inventado del deportista:','']
            if r:
                rr=[x for x in actual if x['format']=='running']
                lines.append(f'- Carrera: {sum(float(x["actual_duration"] or 0) for x in rr)/60:.1f} min de tramos realizados; {sum(float(x["actual_distance"] or 0) for x in rr)/1000:.2f} km; RPE de los tramos {", ".join(str(x["actual_rpe"]) for x in rr)}. Las recuperaciones no se suman a los minutos de trabajo. Datos ficticios.')
            for (_,code),sets in groups.items():
                mode=sets[0]['prescription']['measurement']
                values=[z['result'].get('value') for z in sets]
                actual_text=(str(len(sets))+' intentos válidos') if mode=='PASS_FAIL' else ' + '.join(clock(v) if mode=='DURATION' else num(v) for v in values)
                efforts=['RIR '+str(z['result']['rir']) if z['result'].get('rir') is not None else 'RPE '+str(z['result']['rpe']) for z in sets if z['result'].get('rir') is not None or z['result'].get('rpe') is not None]
                load=sets[0]['result'].get('load_kg')
                lines.append(f'- `{code}`: {actual_text}'+(f'; carga real declarada {num(load)} kg' if load else '')+('; '+', '.join(efforts) if efforts else '')+'. Técnica válida, sin molestias.')
            lines.append('')
    lines += ['## Límites que revela este caso','',
      'Flexiones pasa de 5 + 5 a 6 + 5 en la semana 9 y a 6 + 6 en la 23, pese a registrar margen creciente. Aparece como apoyo de la prueba cronometrada y la razón repetida de mantenimiento es que otra demanda de la misma región progresa. El coordinador ordena específicos antes que apoyos. La combinación de clasificación y exclusión regional deja este movimiento sin una progresión proporcionada a esos registros; requiere corrección y regresión propia.', '',
      'Plancha pasa de dos exposiciones de 36 + 36 segundos a tres de 76 + 75, con redistribución en la semana 9. En la semana 23 cambia el estímulo y vuelve a dos exposiciones de 36 + 36; no consta dificultad previa que explique por sí sola esa caída. Debe revisarse qué dosis se conserva al pasar a especificidad. La última semana reduce a una sola sujeción de 42 segundos.', '',
      'Agilidad practica frenada, pasa a sectores y recupera el recorrido completo en especificidad; el recorrido mantiene 14,3 segundos como referencia de trabajo. Los sectores no acreditan una marca de 12,5 segundos. Carrera alterna sus familias y recalibra desde los controles ficticios; conserva dos salidas, habitualmente 59 minutos semanales en este contexto. La capacidad continua declarada de 30 minutos sigue limitando los rodajes: no se ha renovado a mano para aparentar expansión.', '',
      'Las metas numéricas de fuerza y los controles máximos autónomos siguen incompletos. No hay evidencia de que estas dosis garanticen los objetivos solicitados. La continuidad del programa es una comprobación técnica; no una validación de eficacia deportiva.','',
      'No se han corregido los motores en esta tarea. El ensayo sirve para decidir con datos qué corregir después. No se han cambiado cuentas reales, históricos, migraciones ni producción.','']
    lines += ['## Reproducir y comprobar el ensayo','',
      '`tools/simulate_fas_six_month_case.py` utiliza psycopg 3 y las credenciales temporales en memoria obtenidas mediante `supabase db dump --linked --dry-run`. El cliente de ensayo se instaló aislado en `build/simulation-python` con `psycopg[binary]==3.2.13`; no se cambia ninguna dependencia de Flutter. La conexión persistente evita el tiempo máximo de espera de la consulta HTTP. Referencia de la herramienta: [Supabase CLI](https://supabase.com/docs/reference/cli/supabase-db-dump).','',
      'La transacción sustituye únicamente el reloj para recorrer fechas ficticias y utiliza los RPC instalados para calcular, activar, iniciar, registrar y cerrar sesiones. `finally` ejecuta `ROLLBACK` incluso ante un error. La comprobación posterior encontró cero usuarios con el correo de la fixture y cero referencias al reloj ficticio en las funciones públicas.','',
      'Validaciones: 26 semanas completas, estado final `complete`, 98 fechas únicas sin sesiones duplicadas, máximo diario publicado 60 minutos (dentro de los 60–75 disponibles), 746 registros, RIR entero solo donde corresponde y código de las funciones restaurado. Las 148 migraciones locales y de desarrollo coinciden. Compilación de las dos herramientas Python correcta. No se ha modificado Flutter ni SQL persistente; no corresponde repetir su batería de aplicación como si esta tarea los hubiera cambiado.','']
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text('\n'.join(lines),encoding='utf-8')
    raw=args.output.with_suffix('.json')
    raw.write_text(json.dumps(evidence,ensure_ascii=False,indent=2,default=str),encoding='utf-8')
    (ROOT/'build/fas-six-month-summary.md').write_text('\n'.join(summary),encoding='utf-8')
    print(json.dumps({'report':str(args.output),'evidence':str(raw),'sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),
                      'weeks':len(data['weeks']),'sessions':total_days,'sets_and_segments':total_sets},ensure_ascii=True))


if __name__=='__main__':
    main()
