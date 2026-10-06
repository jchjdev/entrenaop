"""Renderiza resultados SQL sintéticos; no calcula entrenamientos ni mejoras."""
import json
import re
import sys
from pathlib import Path

source = Path(sys.argv[1])
raw = source.read_bytes()
rows = json.loads(raw.decode('utf-16' if raw[:2] == b'\xff\xfe' else 'utf-8-sig'))['rows']
assert len(rows) > 0 and all('profile' in row and 'plan' in row for row in rows)
versions = {row['plan']['policy_version'] for row in rows}
assert len(versions) == 1, 'No mezclar políticas en un mismo informe.'
version = versions.pop()
assert re.fullmatch(r'running_2k_v\d+', version), 'Versión de política desconocida.'
catalogs = {row['plan']['catalog_version'] for row in rows}
assert len(catalogs) == 1, 'El informe debe identificar un único catálogo.'
suffix = version.removeprefix('running_2k_')
target = Path(f'docs/labs/running_engine_{suffix}.html')
metadata = {
    '__VERSION__': version,
    '__CATALOG__': catalogs.pop(),
    '__PROFILES__': str(len({row['profile'] for row in rows})),
    '__TRAJECTORIES__': str(len({(row['profile'], row['months']) for row in rows})),
    '__WEEKS__': f'{len(rows):,}'.replace(',', '.'),
    '__SQL__': f'running_engine_{suffix}_horizons.sql' if suffix != 'v2' else 'running_engine_horizons.sql',
}
target.parent.mkdir(parents=True, exist_ok=True)
template = '''<!doctype html>
<html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>EntrenaOP · Laboratorio de carrera</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#111210;color:#f4efe7}body{max-width:1260px;margin:auto;padding:32px 22px}h1{font-size:clamp(28px,4vw,48px);letter-spacing:-1.4px;margin:12px 0}h2{font-size:19px}.eyebrow{color:#ffab77;font-weight:650;letter-spacing:2px;font-size:12px}p{line-height:1.6;color:#c7c7bd}.notice{border-left:3px solid #ffab77;padding:12px 20px;background:#24231d}.controls{display:flex;gap:20px;flex-wrap:wrap;margin:28px 0}label{display:grid;gap:8px;font-size:14px}select{padding:12px;border-radius:10px;border:1px solid #595a51;background:#23251f;color:inherit;font:inherit;min-width:200px}.stats{display:flex;gap:14px;flex-wrap:wrap}.stat{flex:1;background:#21231e;padding:18px;border-radius:12px;min-width:130px}.stat strong{display:block;font-size:26px;color:#ffbe96}.stat span{font-size:13px;color:#aaa}.chart{background:#1a1c17;margin:20px 0;padding:18px;border-radius:14px}.chart svg{width:100%;height:150px}.legend{font-size:13px;color:#b5b6aa}.tablewrap{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:14px}th{text-align:left;color:#babcae;font-weight:500;padding:14px 10px;border-bottom:1px solid #4a4d40}td{vertical-align:top;padding:16px 10px;border-bottom:1px solid #30332a}td:nth-child(3){min-width:220px}td:last-child{min-width:240px}.badge{display:inline-block;border-radius:5px;padding:2px 6px;background:#413224;color:#ffc293;font-size:12px;margin-right:5px}details{margin-top:8px}summary{cursor:pointer;color:#ffbe96}small{color:#a7aa9e}.segments{line-height:1.6}footer{margin-top:30px;font-size:13px;color:#a7aa9e}button{font:inherit;background:#ffb383;border:0;border-radius:8px;padding:10px 14px;color:#24180f;cursor:pointer}
</style>
<header><div class="eyebrow">ENTRENAOP / LABORATORIO DE CARRERA</div><h1>Un motor. Distintas trayectorias.</h1>
<p>Decisiones reales de <code>__VERSION__</code> ante respuestas ficticias. __PROFILES__ perfiles, __TRAJECTORIES__ trayectorias y __WEEKS__ semanas.</p></header>
<div class="notice">Las marcas de mejora son <b>entradas de ensayo</b>, no resultados que el motor prediga. Este informe comprueba coherencia y adaptación del software; no demuestra eficacia deportiva ni garantiza aprobar. Los horizontes son planes completos, que pueden contener varios mesociclos.</div>
<div class="controls"><label>Perfil<select id="profile"></select></label><label>Horizonte<select id="months"><option>1</option><option>2</option><option selected>3</option><option>4</option><option>6</option><option>12</option></select></label></div>
<p id="scenario"></p><div class="stats" id="stats"></div><div class="chart"><h2>Minutos pautados por semana</h2><svg id="chart" viewBox="0 0 1000 150" role="img" aria-label="Volumen semanal de carrera"></svg><div class="legend">Cada barra representa minutos totales, incluidos calentamiento, recuperaciones y vuelta a la calma.</div></div>
<p class="legend">E: fácil · T: sostenido controlado · V: intervalos aeróbicos · S: específico 2 km · R: progresivos breves. Abre una sesión para ver todos sus tramos.</p>
<div class="tablewrap"><table><thead><tr><th>Semana / etapa</th><th>Referencia recibida</th><th>Sesiones propuestas</th><th>Decisión y cambios</th></tr></thead><tbody id="weeks"></tbody></table></div>
<footer>01/10/2026 · Catálogo __CATALOG__ · Calibración provisional. Datos procedentes de supabase/tests/__SQL__, ejecutado con ROLLBACK. Este visor no publica sesiones.</footer>
<script id="data" type="application/json">__DATA__</script><script>
const data=JSON.parse(document.getElementById('data').textContent),byId=x=>document.getElementById(x);
const labels={'7:58':'7:58 · dos días','iniciacion_11':'11:00 · inicio con carrera habitual','intermedio_8':'8:00 · cuatro días','avanzado_7_30':'7:30 · tres días','meseta':'Marca estancada','se_excede':'Siempre corre demasiado rápido','fatiga':'Fatiga y dosis incompleta','un_mal_dia':'Un único día difícil','no_entrena':'Omite todas las sesiones','intermitente':'Una semana omitida de cada tres','datos_incompletos':'Completa sin registrar parciales','cambia_agenda':'Pasa de cuatro días a dos','fuerza_concurrente':'Carrera y día reservado de fuerza'};
for(const key of Object.keys(labels)){const o=document.createElement('option');o.value=key;o.textContent=labels[key];byId('profile').append(o)}
const phase={general:'General',build:'Desarrollo',specific:'Específica',taper:'Puesta a punto'};
const descriptions={fulfills:'Cumple la dosis con esfuerzo dentro del rango. Controles cada cuatro semanas: pequeñas mejoras externas con techo del 6 % anual.',plateau:'Cumple las sesiones, pero los controles de 2 km permanecen estables.',overdoes:'Corre un 18 % más rápido que el centro del rango y declara RPE 9. El motor debe recuperar la intención, sin premiar el exceso.',fatigue:'En las semanas 4 y 5 registra RPE 9, menor velocidad y solo el 80 % de la dosis de trabajo. Después vuelve a cumplir.',bad_day:'Solo una sesión de la semana 4 recibe RPE 9. El resto cumple la dosis y el esfuerzo.',inactive:'Omite todo; los controles ficticios empeoran gradualmente. No debe obtener calidad por el mero paso del tiempo.',intermittent:'Omite cada tercera semana y cumple las demás. La vuelta no recupera sesiones perdidas.',incomplete:'Declara las sesiones completadas, sin parciales. No equivale a inactividad ni acredita tolerancia.',availability:'Desde la semana 7 pasa de cuatro días de 60 min a dos de 30 min.',};
function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function clock(n){n=Math.round(n);return Math.floor(n/60)+':'+String(n%60).padStart(2,'0')}
function render(){const rows=data.filter(r=>r.profile===byId('profile').value&&r.months===Number(byId('months').value));const totals=rows.map(r=>r.plan.sessions.reduce((a,s)=>a+s.minutes,0));
byId('scenario').textContent=(descriptions[rows[0].response]||'')+(rows[0].profile==='fuerza_concurrente'?' El martes está reservado a fuerza.':'');
byId('stats').innerHTML=[[rows.length,'semanas'],[rows.reduce((n,r)=>n+r.plan.sessions.length,0),'sesiones'],[Math.max(...totals),'máximo min/semana'],[rows.filter(r=>r.plan.mode!=='normal').length,'semanas de ajuste']].map(([n,t])=>`<div class="stat"><strong>${n}</strong><span>${t}</span></div>`).join('');
const max=Math.max(...totals,1),width=1000/rows.length;byId('chart').innerHTML=totals.map((n,i)=>`<rect x="${i*width+2}" y="${145-130*n/max}" width="${Math.max(1,width-4)}" height="${130*n/max}" rx="3" fill="${rows[i].plan.mode==='normal'?'#ffae7e':'#808f6f'}"><title>Semana ${i+1}: ${n} minutos · ${esc(rows[i].plan.reason)}</title></rect>`).join('');
byId('weeks').innerHTML=rows.map(r=>`<tr><td><b>${r.week_no} · ${esc(r.plan.week_start)}</b><br><small>${phase[r.plan.phase]||esc(r.plan.phase)}</small></td><td>${clock(r.plan.anchor_seconds)}<br><small>Dato supuesto</small></td><td>${r.plan.sessions.map(s=>`<details><summary><span class="badge">${esc(s.family)}</span>${esc(s.name)} · ${s.minutes} min</summary><div class="segments"><small>${esc(s.date)} · RPE orientativo ≤${s.rpe_ceiling}</small><br>${s.segments.map(g=>`${g.role==='warmup'?'Calentar':g.role==='cooldown'?'Vuelta a la calma':'Trabajo'}: ${g.meters?g.meters+' m':clock(g.seconds)+' min'}${g.pace_min?' · '+clock(g.pace_min)+'–'+clock(g.pace_max)+'/km':''}${g.recovery_seconds?' · pausa '+clock(g.recovery_seconds):''}`).join('<br>')}</div></details>`).join('')}<p><b>${r.plan.sessions.reduce((n,s)=>n+s.minutes,0)} min totales</b></p></td><td>${esc(r.plan.reason)}<br><small>${esc(r.plan.mode)} · ${esc(r.plan.outcome)}</small>${r.plan.changes?.length?'<details><summary>Cambios auditados</summary><pre>'+esc(JSON.stringify(r.plan.changes,null,2))+'</pre></details>':''}${r.plan.rpe_review_required?'<p>Revisar interpretación del RPE.</p>':''}</td></tr>`).join('');}
byId('profile').onchange=render;byId('months').onchange=render;render();
</script></html>'''
for key, value in metadata.items():
    template = template.replace(key, value)
target.write_text(template.replace('__DATA__', json.dumps(rows, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c')), encoding='utf-8')
print(f'{len(rows)} semanas -> {target}')
