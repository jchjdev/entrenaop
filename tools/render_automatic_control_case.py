"""Conserva evidencia del recorrido con controles realmente pautados por la app."""
from collections import Counter
from datetime import date,timedelta
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'build/fas-six-month-automatic-controls-final.json'
data=json.loads(source.read_text(encoding='utf8'))
assert len(data['weeks'])==26 and not data.get('error')
assert data['rolled_back'] and data['function_source_restored']
assert data['weeks'][-1]['state_after']['status']=='complete'
assert not any(e.get('manual_running_control_seconds') for e in data['events'])
counts=Counter(); controls=[]; sessions=0; results=0; guard_inputs={}
guard_weeks=[]
for w in data['weeks']:
    p=w['decision']; planned=p.get('control_schedule',{}).get('scheduled',[])
    running=p['running']
    uncertain=any(o['signal']['status'] in ('unknown','missing') and
      date.fromisoformat(o['date'])>=date.fromisoformat(w['week_start'])-timedelta(days=7)
      for o in running.get('evidence',{}).get('observations',[]))
    hold=running.get('mode') in ('global_deload','reentry') or running.get('rpe_review_required') or (running.get('data_review_required') and uncertain)
    if hold:guard_weeks.append(w['number'])
    guard_inputs[w['number']]={'effective_hold':bool(hold),'mode':running.get('mode'),
      'rpe_review_required':running.get('rpe_review_required'),'data_review_required':running.get('data_review_required'),
      'recent_unknown_or_missing':uncertain}
    assert not (hold and planned),'Un máximo coincide con recuperación global o información insuficiente'
    assert len(planned)<=1
    assert len(w['schedules'])<=4
    for s in w['schedules']:
        day=s['scheduled_date']
        total=sum(d['minutes'] for d in p['sessions']+p['running']['sessions'] if d['date']==day)
        assert total<=data['scenario']['availability'][str(date.fromisoformat(day).isoweekday())]
        assert s['estimated_duration_minutes']==total,(w['number'],day,s['estimated_duration_minutes'],total)
    for c in planned:
        assert (date.fromisoformat(data['scenario']['exam'])-date.fromisoformat(c['date'])).days>14
        counts[c['profile']]+=1; controls.append((w['number'],c))
    sessions+=len(w['schedules']);results+=len(w['executed'])
assert set(counts)=={'running_2000m_v1','push_up_standard','front_plank_forearms','slalom_ball_course_16m'},counts
evidence={'scenario':data['scenario'],'mode':'automatic_controls_no_manual_marks',
 'migration_sha256':hashlib.sha256((ROOT/'supabase/migrations/20261016191546_adaptive_protocol_controls.sql').read_bytes()).hexdigest(),
 'recovery_guard_migration_sha256':hashlib.sha256((ROOT/'supabase/migrations/20261016195705_adaptive_control_shared_recovery_guard.sql').read_bytes()).hexdigest(),
 'external_recovery_migration_sha256':hashlib.sha256((ROOT/'supabase/migrations/20261016200843_adaptive_control_external_load_recovery.sql').read_bytes()).hexdigest(),
 'recovery_guard_weeks':guard_weeks,
 'rolled_back':True,'function_source_restored':True,'events':data['events'],'weeks':[]}
for w in data['weeks']:
    p=w['decision']
    evidence['weeks'].append({'number':w['number'],'week_start':w['week_start'],
     'decision':{k:v for k,v in p.items() if k not in ('input_snapshot','program_path','context_observed_at')}|
       {'running':{k:v for k,v in p['running'].items() if k not in ('input_snapshot','evidence')}},
     'schedules':w['schedules'],'executed':w['executed'],'state_after':w['state_after'],
     'shared_recovery_guard_input':guard_inputs[w['number']]})
target=ROOT/'docs/audits/CONTROLES_AUTOMATICOS_SEIS_MESES_2026_10_16.json'
target.write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf8')
lines=['# Ensayo de controles automáticos · seis meses','',
 f'26 semanas completadas, {sessions} sesiones físicas y {results} registros de series/tramos. Se utilizan las mismas marcas iniciales, metas, cuatro días y capacidades ficticias del caso FAS. Esta variante responde a los controles realmente pautados y **no añade marcas manuales de 2 km**. Las confirmaciones de salud/contexto siguen siendo intervenciones explícitas; no se fabrican desde los entrenamientos.','',
 'Los resultados de los tests son ficticios y explícitos. No prueban que alguien alcance 50 flexiones, cuatro minutos, 8:20 o 12,5 segundos. La prueba verifica programación, registro, reutilización y continuidad, no eficacia fisiológica.','',
 '## Controles pautados','',
 '| Semana | Día | Protocolo | Pregunta |','| --- | --- | --- | --- |']
for n,c in controls:lines.append(f'| {n} | {c["date"]} | {c["name"]} | {c["question"]} |')
lines+=['','No se pauta un test en las demás semanas. El máximo de uno por semana limita carga y no actúa como cadencia. Cada prueba sustituye trabajo y el registro conserva su protocolo. La colocación puede trasladar un control a otro día ya previsto para evitar coincidir con calidad de carrera.','',
 '## Verificación del recorrido','',
 '- Los cuatro protocolos actuales reciben controles cuando existe una oportunidad compatible.',
 '- No se superan cuatro días ni los 60–75 minutos declarados. La estimación de cada sesión materializada coincide con la suma coordinada; se comprueba también el calentamiento al cambiar el orden.',
 '- No hay pruebas de protocolo en los últimos catorce días antes del examen.',
 '- Carrera reutiliza los controles de 2 km antes de continuar. Salud no se renueva automáticamente; la continuidad observada evita volver a declarar entrenamientos ya registrados.',
 '- Una marca submáxima o una prueba interrumpida/nula no se escala a máximo. Alcanzar el techo de una plancha es un límite inferior explícito.',
 '- El ensayo termina con ROLLBACK y las funciones recuperan su definición previa. No deja usuarios ficticios ni modifica sesiones o marcas reales.','',
 '## Confirmaciones de contexto','',
 'Semanas en que la fixture confirmó de nuevo salud/contexto: '+', '.join(str(e['week']) for e in data['events'])+'. No se insertó un control manual al hacerlo.','',
 'La guarda común de recuperación/datos y la protección de cargas manuales externas se contrastan además en las baterías SQL. No cambian esta trayectoria favorable: la fixture no añade esas cargas ni tiene incertidumbre real en las semanas con control. Se conservan las entradas de la guarda para distinguir un control conocido de un dato perdido.','',
 '## Límites','',
 'La aceptación física sigue pendiente. Los umbrales son guardas operativas documentadas, no un calendario científicamente óptimo demostrado. El diagnóstico de formatos ordinarios de carrera se mantiene separado: no se amplía su biblioteca ni se modifica su progresión en este bloque.','',
 f'Evidencia JSON: `{target.name}`. SHA-256: `{hashlib.sha256(target.read_bytes()).hexdigest()}`.','']
target.with_suffix('.md').write_text('\n'.join(lines),encoding='utf8')
print(json.dumps({'weeks':26,'sessions':sessions,'results':results,'controls':dict(counts),'report':str(target.with_suffix('.md'))}))
