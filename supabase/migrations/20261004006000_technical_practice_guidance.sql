-- Instrucciones específicas para práctica técnica; conserva dosis y política.
begin;
create or replace function public.performance_task_v2(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
 previous jsonb default '{}'::jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare cfg jsonb:=public.performance_bank_v2(); task jsonb:=reference->'task'; source_task jsonb:=reference->'task';
 kind text:=coalesce(reference->>'reference_kind','legacy_unknown'); code text:=profile->>'code';
 m text:=task->>'measurement'; model text; block_code text; block jsonb; phase text; dose jsonb; baseline jsonb;
 targets jsonb; evidence jsonb:='[]'; e jsonb; signal text; good int:=0; bad int:=0; counted int:=0;
 last_dates date[]:='{}'; last_on date; first_on date; observed date:=(reference->>'observed_on')::date;
 days_left int:=target_date-wk; series_count int:=jsonb_array_length(reference->'targets'); sets int; rest int;
 capacity numeric; total numeric; v numeric; idx int; budget numeric; minimum int; maximum int; step numeric; load numeric;
 work_seconds int; outcome text:='initial'; reason text; selection_reason text; instructions text;
 new_code text; new_name text; regions jsonb:=profile->'body_regions'; patterns jsonb:=profile->'movement_patterns';
 freq int:=least(2,greatest(1,coalesce((reference->>'frequency')::int,1))); history_dose jsonb;
 rpe numeric:=(reference->>'reported_rpe')::numeric; rir numeric:=(reference->>'reported_rir')::numeric;
 dynamic boolean; power boolean:=profile->'movement_modes' ? 'plyometric' or code in ('kettlebell_swing','medicine_ball_chest_throw');
begin
 if wk is null or extract(isodow from wk)<>1 then raise exception 'Semana no válida.'; end if;
 if target_date is null or target_date<wk then return jsonb_build_object('status','blocked','reason','Actualiza la fecha objetivo.'); end if;
 if kind in ('legacy_work','legacy_unknown') then return jsonb_build_object('status','needs_calibration',
  'reason','Aclara esta referencia: ¿era tu máximo, una serie con margen o varias series de entrenamiento? No necesitas repetirla si sigue siendo actual.'); end if;
 if reference->>'current_capacity_confirmed' is distinct from 'true' or observed is null or observed>wk+6 then
  return jsonb_build_object('status','needs_calibration','reason','Confirma qué hiciste y cuándo; usa datos actuales y reales.'); end if;
 select max((x->>'completed_on')::date),min((x->>'completed_on')::date) into last_on,first_on
  from jsonb_array_elements(coalesce(history,'[]')) x where (x->>'completed_on')::date<wk;
 if observed<wk-14 and (last_on is null or last_on<wk-21) then return jsonb_build_object('status','needs_calibration',
   'reason','Tras la interrupción necesitamos una práctica reciente. Una sola serie con buena técnica es suficiente.'); end if;
 select min(value::numeric),sum(value::numeric) into capacity,total from jsonb_array_elements_text(reference->'targets');
 if capacity is null or capacity<=0 then return jsonb_build_object('status','needs_calibration','reason','Elige una variante accesible y registra una práctica válida.'); end if;
 phase:=case when days_left<=7 then 'taper' when days_left<=28 then 'specific'
   when first_on is null or wk-first_on<14 then 'base' else 'development' end;
 model:=case when profile->'movement_patterns' ? 'carry' then 'carry' when power then 'power'
   when profile->'movement_patterns' ? 'rope_climb' then 'rope'
   when profile->'movement_patterns' ? 'reactive_agility' then 'reactive_agility'
   when m='TIME_FOR_COURSE' then 'course' when m='LOAD_REPS' then 'load_repetitions'
   when m='REPS' then 'repetitions' when m='REPS_IN_TIME' then 'timed_repetitions'
   when m='DURATION' then 'isometric' else 'skill' end;
 if m='MAX_LOAD' then return jsonb_build_object('status','needs_calibration','reason','Tu máximo queda como control. Registra una serie con carga y repeticiones para elegir el trabajo.'); end if;
 if (model='rope' or power) and kind in ('official_test','capacity_test') then return jsonb_build_object('status','needs_calibration',
  'reason','La marca máxima no acredita intentos repetibles de calidad. Registra una práctica de esta variante sin buscar un récord.'); end if;
 dynamic:=model in ('repetitions','load_repetitions');
 sets:=case when kind='repeated_work' then least(series_count,4) else 2 end;
 budget:=total;
 task:=task-'target_rir'-'target_rpe'-'effort_mode'-'stimulus_code';
 task:=task||jsonb_build_object('policy_version','performance_v2','intent','work');

 if dynamic then
  block_code:=case when model='load_repetitions' then 'LOAD-S01' when capacity<5 then 'REP-T01' else 'REP-E01' end;
  if capacity<2 and model='repetitions' then return jsonb_build_object('status','needs_calibration',
   'reason','Esta variante deja poco margen. Elige una inclinación o asistencia accesible y registra una serie; no hace falta un máximo.'); end if;
  v:=greatest(1,floor(capacity*case when kind='repeated_work' then 0.70 else 0.50 end));
  if kind='repeated_work' and rir>=3 then v:=greatest(1,floor(capacity*0.85)); end if;
  if model='load_repetitions' then
   if capacity<3 then return jsonb_build_object('status','needs_calibration','reason','Registra una serie con una carga menor que permita varias repeticiones con margen.'); end if;
   v:=least(v,coalesce((reference->>'rep_max')::int,6));
  end if;
  select jsonb_agg(v) into targets from generate_series(1,sets);
  selection_reason:='Series submáximas desde una práctica real; la cifra de referencia no se trata como un máximo estimado.';
  instructions:=coalesce(task->>'instructions','')||E'\nHaz hasta las repeticiones pautadas con buena técnica. Conserva al menos tres repeticiones de margen; si llegas a ese esfuerzo antes, para y registra las que hiciste. Puedes terminar con más margen: no añadas repeticiones para agotarte.';
 elsif model='isometric' then
  if capacity<6 then return jsonb_build_object('status','needs_calibration','reason','Usa una posición más accesible que puedas mantener unos segundos con buena técnica y registra esa variante.'); end if;
  block_code:=case when phase='taper' and previous->'dose'->'task'->>'stimulus_code' like 'ISO-%' then previous->'dose'->'task'->>'stimulus_code'
   when capacity<20 then 'ISO-T01' when phase='specific' and kind='repeated_work' and rpe<=7 then 'ISO-E02' else 'ISO-E01' end;
  v:=greatest(3,floor(capacity*case when kind='repeated_work' and rpe<=7 then 0.80 else 0.50 end));
  select jsonb_agg(v) into targets from generate_series(1,sets);
  selection_reason:='Trabajo de postura submáximo. La referencia conserva su tipo; sus segundos no se copian como series al límite.';
  instructions:='Mantén hasta el tiempo indicado, respirando. Termina antes si pierdes la postura o el esfuerzo supera '||case when block_code='ISO-T01' then '5' else '7' end||'/10. Cuenta solo tiempo válido; hoy no medimos tu máximo. 5 es moderado, 7 es difícil pero controlado; 10 sería tu límite.';
 elsif model='timed_repetitions' then
  block_code:=case when phase='specific' then 'TIME-SP02' when phase='taper' then coalesce(previous->'dose'->'task'->>'stimulus_code','TIME-SP01') else 'TIME-SP01' end;
  -- Ritmo de práctica derivado de una medición temporal compatible; no estima RIR ni capacidad de serie libre.
  v:=least(case when block_code='TIME-SP02' then 40 else 20 end,(task->>'fixed_duration_seconds')::numeric/3);
  task:=task||jsonb_build_object('fixed_duration_seconds',v,'protocol_key',task->>'protocol_key'||':fragment:'||v::text);
  v:=greatest(1,floor(capacity*v/(source_task->>'fixed_duration_seconds')::numeric*0.80));
  sets:=case when kind='repeated_work' then least(4,series_count) else 2 end;
  select jsonb_agg(v) into targets from generate_series(1,sets);
  selection_reason:='Fragmentos a ritmo practicable desde tu resultado temporal. No se convierte la marca en RIR ni en una serie máxima libre.';
  instructions:=coalesce(task->>'instructions','')||E'\nDistribuye las repeticiones de forma regular durante el fragmento. Mantén la técnica y no aceleres para recuperar repeticiones perdidas. Registra repeticiones válidas y el tiempo real; no es una marca del examen completo.';
 elsif model='course' and code in ('slalom_ball_course_16m','shuttle_5_10_5') then
  -- La marca del recorrido no permite inventar tiempos de sus sectores.
  block_code:=case when phase='base' then 'COD-T01' when phase='development' then 'COD-SP01' else 'COD-SP02' end;
  -- Consolidar la tarea técnica antes de cambiarla; el calendario no demuestra dominio.
  if phase='development' and (select count(*) from jsonb_array_elements(coalesce(history,'[]')) h
    where h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') and public.performance_exposure_signal_v2(h,h->'dose')='tolerated')<2 then block_code:='COD-T01'; end if;
  -- Familiarización periódica del recorrido ya medido, sin convertirla en un máximo.
  if phase='development' and coalesce((previous->>'weeks_since_review')::int,0)>=3 then block_code:='COD-SP02'; end if;
  if phase='taper' then block_code:=coalesce(previous->'dose'->'task'->>'stimulus_code','COD-SP02'); end if;
  if block_code<>'COD-SP02' then
   new_code:=case when block_code='COD-T01' then 'cod_braking_10m' when code='slalom_ball_course_16m' then 'slalom_ball_course_sector' else 'cod_turn_180_5m' end;
   new_name:=case new_code when 'cod_braking_10m' then 'Aceleración suave y frenada en 10 m' when 'slalom_ball_course_sector' then 'Sector de eslalon y recogida de pelota' else 'Ida y vuelta técnica de 5 metros' end;
   instructions:=case new_code
    when 'cod_braking_10m' then 'Marca 10 metros y deja espacio libre para frenar. Acelera a velocidad cómoda; acorta los pasos para detenerte estable. Vuelve andando. No busques velocidad máxima. Cada serie es un intento.'
    when 'slalom_ball_course_sector' then 'En el circuito medido, practica los últimos tres conos, la recogida de pelota y los primeros pasos de retorno. Velocidad cómoda; termina sin desplazar conos ni perder la pelota. Cada serie es un intento.'
    else 'Marca dos líneas a 5 metros. Avanza a velocidad cómoda, frena antes de la línea, gira y vuelve. Alterna el lado de giro entre intentos. Cada serie es un intento.' end;
   task:=task-'fixed_duration_seconds'-'fixed_distance_meters';
   task:=task||jsonb_build_object('exercise_code',new_code,'exercise_version',1,'measurement','PASS_FAIL','intent','practice',
     'protocol_key',new_code||'_v1','protocol_version',1,'setup_key','standard:'||new_code||'_v1',
     'records_stimulus_responses',false,'records_penalty_seconds',false);
   targets:='[1,1,1,1]';
  else
   targets:=jsonb_build_array(capacity,capacity);
   task:=task||'{"intent":"practice"}'::jsonb;
   instructions:=coalesce(task->>'instructions','')||E'\nIntentos completos de calidad, con recuperación. El tiempo indicado es tu referencia, no una obligación de batirla. Detén los intentos si empeoran claramente la técnica o el control; registra el tiempo real.';
  end if;
  selection_reason:=case block_code when 'COD-T01' then 'Practicar y consolidar aproximación y frenada; tu marca del circuito no se convierte en tiempo de este ejercicio.' when 'COD-SP01' then 'Desarrollo del recorrido por sectores; medir calidad antes de exigir velocidad.' else 'Integrar o familiarizar el recorrido conocido, con descansos y sin imponer un récord. Fuera de la fase específica se revisa periódicamente.' end;
 elsif model='course' then
  return jsonb_build_object('status','needs_strategy','reason','Este recorrido necesita definir sus componentes técnicos antes de planificarlo automáticamente.');
 else
  block_code:=case when model='power' then 'POWER-P01' when model='rope' then 'ROPE-T01' when model='carry' then 'CARRY-E01' else 'SKILL-T01' end;
  sets:=least(series_count,3);
  if model='carry' then v:=greatest(1,floor(capacity*0.70));
  elsif power and m in ('REPS','LOAD_REPS') then v:=least(3,capacity);
  else v:=capacity; end if;
  select jsonb_agg(v) into targets from generate_series(1,sets);
  task:=task||jsonb_build_object('intent',case when model='carry' then 'work' else 'practice' end);
  selection_reason:='Práctica con variante, carga y condiciones conocidas; el resultado no se interpreta como permiso para añadir intentos.';
  instructions:=coalesce(task->>'instructions','')||E'\nConserva la calidad del gesto y descansa lo indicado. La marca es una referencia, no un récord obligatorio. Si se pierde la técnica o la intención del movimiento, detén la práctica.';
 end if;
 select value into block from jsonb_array_elements(cfg->'blocks') where value->>'code'=block_code;
 rest:=(block->>'rest_seconds')::int;
 task:=task||jsonb_build_object('stimulus_code',block_code,'effort_mode',block->>'effort_mode','instructions',instructions,'target_value',targets->0);
 if block->>'effort_mode'='rir' then task:=task||'{"target_rir":3}'::jsonb; end if;
 if block->>'effort_mode'='rpe' then task:=task||jsonb_build_object('target_rpe',case when block_code='ISO-T01' then 5 else 7 end); end if;
 dose:=jsonb_build_object('task',task,'targets',targets,'rest_seconds',rest,'model',model,'stimulus_code',block_code);
 -- Recuperar la dosis publicada de ESTE estímulo, nunca trasladar adaptación entre protocolos.
 select h->'dose' into history_dose from jsonb_array_elements(coalesce(history,'[]')) h
  where h->'dose'->'task'->>'stimulus_code'=block_code and (h->>'completed_on')::date<wk
  order by h->>'completed_on' desc limit 1;
 if previous->'dose'->'task'->>'stimulus_code'=block_code and previous->>'reference_id'=reference->>'id' then dose:=previous->'dose';
 elsif history_dose is not null then dose:=history_dose; end if;
 baseline:=dose; targets:=dose->'targets'; task:=dose->'task';
 reason:=selection_reason;
 for e in select value from jsonb_array_elements(coalesce(history,'[]'))
  where (value->>'completed_on')::date between greatest(observed,wk-21) and wk-1 order by value->>'completed_on' desc loop
  if (e->>'completed_on')::date=any(last_dates) then continue; end if;
  signal:=public.performance_exposure_signal_v2(e,dose);
  evidence:=evidence||jsonb_build_array(jsonb_build_object('execution_id',e->'execution_id','date',e->'completed_on','signal',signal,'exposure',e));
  if signal='pain' then return jsonb_build_object('status','blocked','reason','Actualiza tu situación después de las molestias registradas.','evidence',evidence); end if;
  if signal='different_dose' then continue; end if;
  last_dates:=array_append(last_dates,(e->>'completed_on')::date);
  if signal='tolerated' then good:=good+1; elsif signal='difficulty' then bad:=bad+1; end if;
  counted:=counted+1; exit when counted=2;
 end loop;
 if previous->'dose' is not null or history_dose is not null then outcome:='maintain'; end if;
 if bad>=1 then
  -- Una dificultad reduce prudentemente; no esperar otra exposición al mismo fallo.
  outcome:='reduce'; reason:=reason||' La última respuesta comparable indica dificultad: reducimos trabajo y comprobamos cómo respondes.';
  if model in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') then
   select jsonb_agg(greatest(1,floor(value::numeric*0.85)) order by ordinality) into targets from jsonb_array_elements_text(targets) with ordinality;
   if targets=baseline->'targets' then return jsonb_build_object('status','needs_calibration','reason','La dosis mínima no se tolera: registra una variante o carga más accesible.','evidence',evidence); end if;
  elsif jsonb_array_length(targets)>1 then targets:=targets-(jsonb_array_length(targets)-1);
  else return jsonb_build_object('status','needs_calibration','reason','Revisa la variante y las condiciones antes de repetir ese intento difícil.','evidence',evidence); end if;
 elsif good=2 and phase<>'taper' then
  if model in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') then
   select ordinality::int-1,value::numeric into idx,v from jsonb_array_elements_text(targets) with ordinality order by value::numeric,ordinality limit 1;
   maximum:=coalesce((reference->>'rep_max')::int,6); minimum:=coalesce((reference->>'rep_min')::int,4);
   load:=(task->>'external_load_kg')::numeric; step:=(reference->>'load_step_kg')::numeric;
   if model='load_repetitions' and v>=maximum then
    if step>0 and step<=load*0.10 then
     task:=task||jsonb_build_object('external_load_kg',load+step);
     select jsonb_agg(minimum) into targets from generate_series(1,jsonb_array_length(targets)); outcome:='progress';
    else reason:=reason||' Horquilla consolidada: confirma el siguiente escalón disponible antes de subir carga.'; end if;
   else
    targets:=jsonb_set(targets,array[idx::text],to_jsonb(v+case when model='isometric' then 2 else 1 end)); outcome:='progress';
   end if;
   if outcome='progress' then reason:=reason||' Dos exposiciones comparables con calidad y margen permiten subir una sola demanda.'; end if;
  else reason:=reason||' Calidad consolidada: mantener intentos, sin inventar velocidad ni añadir volumen.'; end if;
 elsif counted>0 then reason:=reason||' Mantenemos hasta disponer de respuesta comparable suficiente; no se completa información desconocida.';
 else reason:=reason||' Primera dosis de este estímulo: registra lo realizado para individualizar la siguiente.'; end if;
 if phase='taper' then
  select jsonb_agg(value order by ordinality) into targets from jsonb_array_elements(targets) with ordinality
   where ordinality<=greatest(1,ceil(jsonb_array_length(targets)/2.0));
  outcome:='maintain'; freq:=1; reason:=reason||' Puesta a punto: menos series, conservar el gesto conocido y evitar máximos.';
 end if;
 -- La práctica técnica de capacidad baja no exige un RIR incompatible con esa capacidad.
 -- Se aplica después de comparar la dosis histórica para conservar sus señales reales.
 if block_code='REP-T01' then
  task:=task||jsonb_build_object('instructions',coalesce(source_task->>'instructions','')||E'\nPractica las repeticiones indicadas de forma controlada. No busques el fallo: detente si pierdes la postura o el gesto deja de ser fluido. No necesitas estimar repeticiones restantes. Si no consigues una repetición limpia, registra una variante con apoyo o ayuda.');
 end if;
 task:=jsonb_set(task,'{target_value}',targets->0);
 dose:=dose||jsonb_build_object('task',task,'targets',targets);
 work_seconds:=public.performance_work_seconds_v2(dose);
 if code in ('front_plank_forearms','front_plank_high','side_plank') and not regions ? 'upper_body' then regions:=regions||'"upper_body"'::jsonb; end if;
 return jsonb_build_object('status','ready','policy_version','performance_v2','reference_id',reference->>'id','reference_kind',kind,
  'model',model,'phase',phase,'outcome',outcome,'reason',reason,'stimulus',block,'selection_reason',selection_reason,
  'name',coalesce(new_name,profile->>'name'),'comparison_dose',baseline,'dose',dose,'frequency',freq,
  'work_seconds',work_seconds,'work_minutes',ceil(work_seconds/60.0),'body_regions',regions,'movement_patterns',patterns,
  'running_leg_load',regions ? 'lower_body' and block_code not in ('COD-T01','COD-SP01'),
  'evidence',evidence,'review_due',coalesce((previous->>'weeks_since_review')::int,0)>=3,
  'weeks_since_review',case when coalesce((previous->>'weeks_since_review')::int,0)>=3 then 0 else coalesce((previous->>'weeks_since_review')::int,0)+1 end,
  'parameter_status',cfg->>'parameter_status');
end $$;
commit;
