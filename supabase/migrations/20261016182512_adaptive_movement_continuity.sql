begin;

-- Correcciones de continuidad: no convertir una etiqueta o una región anatómica
-- amplia en permiso para perder trabajo acreditado. Guardas operativas, no
-- promesas de resultados ni umbrales biológicos universales.
create function public.performance_same_isometric_work_v1(a jsonb,b jsonb) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(a->>'measurement'='DURATION' and b->>'measurement'='DURATION'
  and a->>'exercise_code'=b->>'exercise_code' and a->'exercise_version'=b->'exercise_version'
  and a->>'protocol_key'=b->>'protocol_key' and a->'protocol_version'=b->'protocol_version'
  and a->>'setup_key'=b->>'setup_key' and a->>'load_mode'=b->>'load_mode'
  and a->'external_load_kg' is not distinct from b->'external_load_kg'
  and a->>'intent'='work' and b->>'intent'='work'
  and a->>'effort_mode'=b->>'effort_mode' and a->'target_rpe'=b->'target_rpe',false)
$$;

create function public.performance_coordinate_progression_v3(proposals jsonb,running jsonb,wk date) returns jsonb
language sql immutable set search_path='' as $$
 -- Cada estrategia ya limita su incremento y no aumenta simultáneamente dosis
 -- y frecuencia. El colocador comprueba recuperación, series compartidas y
 -- tiempo. Compartir «trunk» no justifica congelar otro objetivo indefinidamente.
 select coalesce(jsonb_agg(p||jsonb_build_object('progression_coordination_version','independent_bounded_work_v1')
  order by ord),'[]') from jsonb_array_elements(proposals) with ordinality x(p,ord)
$$;

create function public.running_capacity_observed_v1(goal uuid,wk date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare ctx public.running_intake_contexts%rowtype; proven int; trial int; samples int; adverse boolean;
begin
 if not exists(select 1 from public.preparation_goals where id=goal and user_id=auth.uid()) then
  raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=goal;
 if not found then return '{}'::jsonb; end if;
 select exists(select 1 from public.workout_executions e join public.scheduled_workouts sw on sw.execution_id=e.id
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  join public.workout_execution_sets affected_set on affected_set.execution_id=e.id and affected_set.block_format='running'
  where e.user_id=auth.uid() and public.workout_performed_on_v1(e) between wk-14 and wk-1
   and (public.workout_block_outcome_v1(e.id,affected_set.block_order)->>'abandonment_reason' in ('discomfort','too_difficult') or exists(
    select 1 from public.workout_execution_sets es where es.execution_id=e.id and es.block_format='running'
     and es.status='completed' and es.actual_rpe>coalesce((rs.prescription->>'rpe_ceiling')::numeric,5)))) into adverse;
 with observed as (
  select public.workout_performed_on_v1(e) performed_on,
   floor(sum(es.actual_duration_seconds)/60.0)::int minutes,
   coalesce(max(es.actual_rpe),case when not exists(select 1 from public.performance_week_work pw
     where pw.scheduled_workout_id=sw.id) then e.final_rpe end) rpe
  from public.workout_executions e join public.scheduled_workouts sw on sw.execution_id=e.id
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  join public.workout_execution_sets es on es.execution_id=e.id and es.block_format='running'
  where e.user_id=auth.uid() and sw.preparation_goal_id=goal
   and e.status in ('completed','abandoned') and public.workout_block_outcome_v1(e.id,es.block_order)->>'status'='completed'
   and es.status='completed' and rs.prescription->>'family'='E'
   and jsonb_array_length(rs.prescription->'segments')=1
   and rs.prescription->'segments'->0->>'role'='work'
   and public.workout_performed_on_v1(e) between wk-28 and least(wk-1,current_date)
  group by e.id,sw.id,performed_on
 ), distinct_days as (
  select performed_on,max(minutes) minutes,max(rpe) rpe from observed group by performed_on
 ), latest as (select * from distinct_days order by performed_on desc limit 2)
 select count(*),min(minutes) into samples,proven from latest where rpe between 1 and 5 and minutes>=25;
 trial:=ctx.comfortable_continuous_minutes;
 if samples=2 and not adverse and not ctx.reports_pain and not ctx.requires_professional_review
  and ctx.health_observed_at>=now()-interval '30 days'
  and (select target_date-wk>14 from public.preparation_goals where id=goal)
  and coalesce(trial,30)>=30 then
  -- Cinco minutos de ensayo siguiente, no cinco minutos ya demostrados.
  trial:=greatest(coalesce(trial,30),least(60,proven+5));
 end if;
 return jsonb_build_object('version','running_capacity_observed_v1','declared_minutes',ctx.comfortable_continuous_minutes,
  'observed_continuous_minutes',case when samples=2 then proven end,'trial_minutes',trial,
  'comparable_easy_days',samples,'recent_adverse_response',adverse,
  'reason',case when trial>ctx.comfortable_continuous_minutes then
   'Dos rodajes fáciles registrados permiten probar un pequeño aumento, sujeto al resto de reglas de carrera.'
   else 'Se conserva la entrada declarada: falta evidencia suficiente para ampliar el ensayo.' end);
end $$;

create function public.performance_support_recipes_v2() returns jsonb
language sql immutable set search_path='' as $$
 select coalesce(jsonb_agg(r),'[]')||jsonb_build_array(jsonb_build_object(
  'goal','front_plank_forearms','work','front_plank_high','measurement','DURATION','load_mode','bodyweight','rank',10,
  'instructions','Apoya las manos bajo los hombros y mantén el cuerpo alineado, respirando. Prueba hasta quince segundos, sin superar un esfuerzo moderado de 6 sobre 10. Termina antes si pierdes la postura o aparecen molestias. Es una variante distinta: su tiempo no equivale al de la plancha de antebrazos. Registra solo segundos válidos y el esfuerzo real; puedes omitir este apoyo.'))
 from jsonb_array_elements(public.performance_support_recipes_v1()) r where r->>'work'<>'dead_bug'
$$;

create function public.is_support_familiarization_v2(p jsonb) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(p->>'policy_version'='support_familiarization_v2' and p->>'exercise_code'='front_plank_high'
  and p->'exercise_version'='1'::jsonb and p->>'measurement'='DURATION' and p->>'load_mode'='bodyweight'
  and p->>'protocol_key'='support_work_v2:front_plank_high' and p->'protocol_version'='1'::jsonb
  and p->>'setup_key'='standard:support_v2:front_plank_high' and p->>'intent'='work'
  and p->>'stimulus_code'='SUPPORT-ISO-F01' and p->'target_value'='15'::jsonb
  and p->>'effort_mode'='rpe' and p->'target_rpe'='6'::jsonb and not p ? 'target_rir',false)
$$;

create function public.performance_support_observed_v2(work_code text,version int,mode text,load_mode text,wk date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare found_observation jsonb;
begin
 if mode<>'DURATION' then return public.performance_support_observed_v1(work_code,version,mode,load_mode,wk); end if;
 with observations as (
  select es.performance_prescription task,es.performance_result result,public.workout_performed_on_v1(e) observed_on,
   e.id source_id,es.id set_id,'execution' source
  from public.workout_executions e join public.workout_execution_sets es on es.execution_id=e.id
  where e.user_id=auth.uid() and e.status in ('completed','abandoned') and es.status='completed'
   and public.workout_block_outcome_v1(e.id,es.block_order)->>'status'='completed'
  union all
  select r.reference->'task',jsonb_build_object('value',r.reference->'targets'->0,'rpe',r.reference->'reported_rpe',
   'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none'),
   (r.reference->>'observed_on')::date,r.id,null,'reference'
  from public.performance_training_references r where r.user_id=auth.uid() and r.active
   and not r.reference ? 'automatic_support' and r.reference->>'current_capacity_confirmed'='true'
   and r.reference->>'reference_kind' in ('performed_set','repeated_work')
 ), matching as (
  select * from observations where task->>'exercise_code'=work_code and (task->>'exercise_version')::int=version
   and task->>'measurement'=mode and task->>'load_mode'=load_mode and task->>'intent'='work'
   and observed_on between greatest(wk,current_date)-14 and least(wk+6,current_date)
 ), eligible as (
  select * from matching o where result->>'technique_valid'='true' and result->>'conditions_confirmed'='true'
   and result->>'tolerated'='true' and result->>'stop_reason'='none'
   and (result->>'value')::numeric between 6 and 3600 and (result->>'rpe')::numeric between 1 and 7
   and not exists(select 1 from matching newer where newer.observed_on>o.observed_on
    and (newer.result->>'stop_reason' in ('difficulty','discomfort') or newer.result->>'technique_valid'='false'
     or newer.result->>'tolerated'='false' or (newer.result->>'rpe')::numeric>7))
 ) select jsonb_build_object('task',task,'result',result,'observed_on',observed_on,
   'source',source,'source_id',source_id,'set_id',set_id) into found_observation from eligible order by observed_on desc,source_id,set_id limit 1;
 return found_observation;
end $$;

create function public.performance_support_source_valid_v2(r jsonb) returns boolean
language sql stable security definer set search_path='' as $$
 select case when r->'task'->>'measurement'<>'DURATION' then public.performance_support_source_valid_v1(r)
 when r->'automatic_support'->'observation'->>'source'='execution' then exists(
  select 1 from public.workout_execution_sets es join public.workout_executions e on e.id=es.execution_id
  where e.user_id=auth.uid() and es.id=(r->'automatic_support'->'observation'->>'set_id')::uuid and es.status='completed'
   and es.performance_prescription->>'exercise_code'=r->'task'->>'exercise_code'
   and es.performance_result->'value'=r->'targets'->0 and es.performance_result->'rpe'=r->'reported_rpe'
   and es.performance_result->>'technique_valid'='true' and es.performance_result->>'conditions_confirmed'='true'
   and es.performance_result->>'tolerated'='true' and es.performance_result->>'stop_reason'='none')
 when r->'automatic_support'->'observation'->>'source'='reference' then exists(
  select 1 from public.performance_training_references src where src.user_id=auth.uid()
   and src.id=(r->'automatic_support'->'observation'->>'source_id')::uuid
   and src.reference->'targets'->0=r->'targets'->0 and src.reference->'reported_rpe'=r->'reported_rpe'
   and ((src.reference->'task')-array['instructions','policy_version','target_value'])=
       ((r->'task')-array['instructions','policy_version','target_value'])) else false end
$$;

create function public.performance_goal_reviews_v1(goal uuid,wk date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare g public.preparation_goals%rowtype; item record; objective jsonb; setup jsonb;
 result jsonb:='[]'; mark numeric; measured date; source_id text; test_key text; fresh boolean; met boolean;
begin
 select * into g from public.preparation_goals where id=goal and user_id=auth.uid();
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 setup:=public.get_preparation_training_setup_base(goal);
 for item in select key,value from jsonb_each(coalesce((select objective_targets from public.adaptive_program_states
    where preparation_goal_id=goal),'{}')) loop
  select value into objective from jsonb_array_elements(setup->'objectives') where value->>'objective_key'=item.key;
  if objective is null or objective->>'measurement'<>item.value->>'measurement' then continue; end if;
  mark:=null; measured:=null; source_id:=null;
  if g.program_id='fas_periodic_assessment' and item.key like 'legacy:%' then
   test_key:=substr(item.key,8);
   select case when item.value->>'measurement' in ('DURATION','TIME_FOR_COURSE') then m.value/1000.0 else m.value end,
    a.completed_at::date,a.id::text into mark,measured,source_id
   from public.fas_periodic_assessments a join public.fas_periodic_marks m on m.assessment_id=a.id
   where a.user_id=auth.uid() and a.preparation_goal_id=goal and m.test_id=test_key
    and a.completed_at::date<=least(current_date,wk+6)
   order by a.completed_at desc,a.id limit 1;
  elsif objective->>'test_id' is not null then
   select (d->>'mark')::numeric,a.assessed_on,a.id::text into mark,measured,source_id
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   where a.user_id=auth.uid() and a.preparation_goal_id=goal and a.program_id=g.program_id
    and d->>'test_id'=objective->>'test_id' and not coalesce((d->>'invalid')::boolean,false)
    and a.assessed_on<=least(current_date,wk+6) order by a.assessed_on desc,a.created_at desc limit 1;
  end if;
  fresh:=mark is not null and measured>=wk-42;
  met:=case when mark is null then null when item.value->>'measurement'='TIME_FOR_COURSE'
    then mark<=(item.value->>'value')::numeric else mark>=(item.value->>'value')::numeric end;
  result:=result||jsonb_build_array(jsonb_build_object('objective_key',item.key,'name',objective->>'name',
   'measurement',item.value->>'measurement','target',item.value->'value','last_protocol_mark',mark,
   'observed_on',measured,'source_id',source_id,'recent_protocol_mark',fresh,
   'last_mark_meets_target',met,'priority',case when fresh and met then 2 when fresh and not met then 0 else 1 end,
   'control_kind','submaximal_work','updates','work_capacity_only',
   'review_reason',case when item.value->>'measurement'='REPS_IN_TIME' and not exists(
     select 1 from public.performance_training_references r where r.preparation_goal_id=goal and r.active
      and r.objective_key=item.key and r.reference->'task'->>'measurement'='REPS_IN_TIME') then
     'Tu trabajo libre mejora el movimiento, pero no acredita el ritmo de la prueba cronometrada. Conservamos su progresión; una práctica cronometrada compatible permitirá trabajar el ritmo sin repetir un máximo.'
    when mark is null then 'Aún no hay una marca compatible del protocolo. Las series de trabajo no se convierten en un máximo.'
    when not fresh then 'Esta es tu última marca del protocolo, no una estimación actual. Los entrenamientos siguen adaptándose desde tus registros; revisaremos la prueba cuando aporte información útil.'
    else 'La meta orienta la prioridad entre opciones compatibles; la dosis se adapta desde tu trabajo real, sin exigir hoy la marca deseada.' end));
 end loop;
 return result;
end $$;

revoke all on function public.performance_same_isometric_work_v1(jsonb,jsonb),
 public.performance_coordinate_progression_v3(jsonb,jsonb,date),public.running_capacity_observed_v1(uuid,date),
 public.performance_support_observed_v2(text,int,text,text,date),public.performance_support_source_valid_v2(jsonb),
 public.performance_goal_reviews_v1(uuid,date)
 from public,anon,authenticated;
revoke all on function public.performance_support_recipes_v2(),public.is_support_familiarization_v2(jsonb) from public,anon;
grant execute on function public.performance_support_recipes_v2(),public.is_support_familiarization_v2(jsonb) to authenticated;


insert into public.performance_exercise_relations(policy_version,goal_code,work_code,role,rationale) values ('performance_v1','front_plank_forearms','front_plank_high','support','Apoyo isométrico con manos y referencia propia; no convertir sus segundos en plancha de antebrazos.') on conflict do nothing;

create or replace function public.performance_task_v3_core(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
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
 phase_bridge boolean:=false; dynamic boolean; power boolean:=profile->'movement_modes' ? 'plyometric' or code in ('kettlebell_swing','medicine_ball_chest_throw');
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
 phase:=coalesce(reference->>'strategy_phase',case when days_left<=7 then 'taper' when days_left<=28 then 'specific'
   when first_on is null or wk-first_on<14 then 'base' else 'development' end);
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
 task:=task||jsonb_build_object('policy_version','performance_v3','intent','work');

 if dynamic then
  block_code:=case when model='load_repetitions' then 'LOAD-S01' when capacity<5 then 'REP-T01' else 'REP-E01' end;
  if capacity<2 and model='repetitions' then return jsonb_build_object('status','needs_calibration',
   'reason','Esta variante deja poco margen. Elige una inclinación o asistencia accesible y registra una serie; no hace falta un máximo.'); end if;
  v:=greatest(1,floor(capacity*case when kind='repeated_work' then 0.70 else 0.50 end));
  if kind='repeated_work' and rir>=3 then v:=greatest(1,floor(capacity*0.85)); end if;
  if model='load_repetitions' then
   if capacity<3 or (kind in ('capacity_test','official_test') and capacity-v<3) then return jsonb_build_object('status','needs_calibration','reason','Registra una serie con una carga menor que permita varias repeticiones con margen.'); end if;
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

  if phase='specific' and (select count(distinct (h->>'completed_on')::date) from jsonb_array_elements(coalesce(history,'[]')) h where (h->>'completed_on')::date between wk-21 and wk-1 and h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') and public.performance_exposure_signal_v2(h,h->'dose')='tolerated')<2 then block_code:='COD-T01'; end if;
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
  selection_reason:=case block_code when 'COD-T01' then 'Practicar y consolidar aproximación y frenada; tu marca del circuito no se convierte en tiempo de este ejercicio.' when 'COD-SP01' then 'Desarrollo del recorrido por sectores; medir calidad antes de exigir velocidad.' else 'Integrar o familiarizar el recorrido conocido, con descansos y sin imponer un récord. La integración se decide por la fase y la calidad reciente, sin un contador de tests.' end;
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

 -- Cambiar el énfasis conservando gesto, protocolo, apoyos y esfuerzo no borra
 -- capacidad acreditada. El descanso nuevo es igual o mayor; no se transfiere
 -- esta dosis a otra variante ni se progresa el mismo día de la transición.
 if model='isometric' and phase='specific' and previous->>'phase'='development'
  and previous->>'reference_id'=reference->>'id'
  and public.performance_same_isometric_work_v1(dose->'task',previous->'dose'->'task')
  and (dose->>'rest_seconds')::int>=(previous->'dose'->>'rest_seconds')::int
  and last_on>=wk-14 and public.performance_exposure_signal_v2(
   (select h from jsonb_array_elements(history) h order by h->>'completed_on' desc limit 1),previous->'dose') in ('tolerated','difficulty') then
  phase_bridge:=true;
  dose:=dose||jsonb_build_object('targets',previous->'dose'->'targets',
   'task',(dose->'task')||jsonb_build_object('target_value',previous->'dose'->'targets'->0));
  selection_reason:=selection_reason||' Conservamos el trabajo reciente: el cambio de fase no reinicia la referencia.';
 end if;
 baseline:=dose; targets:=dose->'targets'; task:=dose->'task';
 reason:=selection_reason;
 for e in select value from jsonb_array_elements(coalesce(history,'[]'))
  where (value->>'completed_on')::date between greatest(observed,wk-21) and wk-1 order by value->>'completed_on' desc loop
  if (e->>'completed_on')::date=any(last_dates) then continue; end if;
  signal:=public.performance_exposure_signal_v2(e,dose);
  if phase_bridge and public.performance_same_isometric_work_v1(e->'dose'->'task',dose->'task')
    and (e->'dose'->>'rest_seconds')::int<=(dose->>'rest_seconds')::int then
   -- Una dificultad real no desaparece al cambiar de etiqueta. La tolerancia
   -- anterior conserva dosis, pero no acredita una subida con el nuevo énfasis.
   signal:=case public.performance_exposure_signal_v2(e,e->'dose')
    when 'difficulty' then 'difficulty' when 'pain' then 'pain' else 'different_dose' end;
  end if;
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
 return jsonb_build_object('status','ready','policy_version','performance_v3','reference_id',reference->>'id','reference_kind',kind,
  'model',model,'phase',phase,'outcome',outcome,'reason',reason,'stimulus',block,'selection_reason',selection_reason,
  'name',coalesce(new_name,profile->>'name'),'comparison_dose',baseline,'dose',dose,'frequency',freq,
  'work_seconds',work_seconds,'work_minutes',ceil(work_seconds/60.0),'body_regions',regions,'movement_patterns',patterns,
  'running_leg_load',regions ? 'lower_body' and block_code not in ('COD-T01','COD-SP01'),
  'evidence',evidence,'review_due',bad>0 or (previous->>'phase' is not null and previous->>'phase'<>phase),
  'review_reason',case when bad>0 then 'La respuesta reciente requiere revisar recuperación y dosis. No añadir un test máximo.'
    when previous->>'phase' is not null and previous->>'phase'<>phase then 'Cambia el énfasis del programa: revisa la respuesta y si falta información relevante. No exige un test.' end,
  'review_policy','need_based_v1',
  'weeks_since_review',case when coalesce((previous->>'weeks_since_review')::int,0)>=3 then 0 else coalesce((previous->>'weeks_since_review')::int,0)+1 end,
  'parameter_status',cfg->>'parameter_status');
end $$;

create or replace function public.performance_task_v5(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
 previous jsonb default '{}'::jsonb,started_on date default null) returns jsonb
language plpgsql immutable set search_path='' as $$
declare p jsonb; cfg jsonb; baseline jsonb; doses jsonb; comparison jsonb; redistributed jsonb;
 h jsonb; signal text; dates date[]:='{}'; good int:=0; bad int:=0; last_week int:=0;
 freq int:=greatest(1,coalesce((previous->>'frequency')::int,(reference->>'frequency')::int,1));
 known_frequency int; n int; d jsonb; changed boolean; qualified boolean:=true; difficult_exposure jsonb;
 capacity numeric; fraction numeric; minimum_quantity int;
begin
 p:=public.performance_task_v3(reference,profile,history,wk,target_date,previous,started_on);
 p:=p||jsonb_build_object('frequency_policy_version','performance_frequency_v2','rep_min',coalesce((reference->>'rep_min')::int,4));
 if p->>'status'<>'ready' then return p; end if;
 select min(v::numeric) into capacity from jsonb_array_elements_text(reference->'targets') v;
 -- Conservar una magnitud practicable de la entrada calibrada. No convertir
 -- una serie útil en repeticiones o segundos testimoniales para llenar días.
 fraction:=case when reference->>'reference_kind'='repeated_work' then
   case when p->>'model'='isometric' and (reference->>'reported_rpe')::numeric<=7 then 0.80
     when p->>'model' in ('repetitions','load_repetitions') and (reference->>'reported_rir')::numeric>=3 then 0.85
     when p->>'model' in ('repetitions','load_repetitions') then 0.70 else 0.50 end else 0.50 end;
 minimum_quantity:=case when p->>'model'='load_repetitions' then coalesce((reference->>'rep_min')::int,4)
   when p->>'model'='timed_repetitions' then greatest(1,floor(capacity*(p->'dose'->'task'->>'fixed_duration_seconds')::numeric/(reference->'task'->>'fixed_duration_seconds')::numeric*0.80)::int)
   when p->>'model'='isometric' then greatest(3,floor(capacity*fraction)::int)
   when p->>'model'='repetitions' then greatest(1,floor(capacity*fraction)::int)
   when p->>'model'='carry' then greatest(1,floor(capacity*0.70)::int) end;
 p:=p||jsonb_build_object('minimum_quantity_from_reference',minimum_quantity);
 baseline:=p->'comparison_dose'; cfg:=public.performance_frequency_strategy_v2(p);
 changed:=previous->'dose' is not null
  and not (public.performance_same_isometric_work_v1(previous->'dose'->'task',baseline->'task')
    and (baseline->>'rest_seconds')::int>=(previous->'dose'->>'rest_seconds')::int) and ((previous->'dose'->'task')-array['target_value','instructions','policy_version'])
   is distinct from ((baseline->'task')-array['target_value','instructions','policy_version']);
 -- Una tarea nueva vuelve a su entrada calibrada, sin heredar práctica de otra.
 if changed then freq:=greatest(1,coalesce((reference->>'frequency')::int,1)); end if;
 known_frequency:=freq;
 if cfg->>'allocation'='attempts' and not changed and jsonb_array_length(coalesce(previous->'exposure_doses','[]'))=freq then
   -- Conservar la distribución irregular conocida al mantener la frecuencia.
   for d in select value from jsonb_array_elements(previous->'exposure_doses') loop
     select jsonb_agg(v order by ord) into doses from jsonb_array_elements(p->'dose'->'targets') with ordinality x(v,ord)
       where ord<=least(jsonb_array_length(d->'targets'),jsonb_array_length(p->'dose'->'targets'));
     comparison:=coalesce(comparison,'[]')||jsonb_build_array(d);
     redistributed:=coalesce(redistributed,'[]')||jsonb_build_array((p->'dose')||jsonb_build_object('targets',doses,
       'task',(p->'dose'->'task')||jsonb_build_object('target_value',doses->0)));
   end loop;
   doses:=redistributed;
 else
   select jsonb_agg(p->'dose'),jsonb_agg(baseline) into doses,comparison from generate_series(1,freq);
 end if;
 if p->>'phase'='taper' then
   freq:=case when previous->>'phase'='taper' then freq else greatest(1,ceil(freq/2.0)::int) end;
   select jsonb_agg(value order by ord) into doses from jsonb_array_elements(doses) with ordinality x(value,ord) where ord<=freq;
   p:=p||jsonb_build_object('frequency_reason','taper_from_known_frequency');
 else
   -- Cada exposición se evalúa contra SU prescripción; 2+1 no equivale a 2+2.
   for h in select value from jsonb_array_elements(coalesce(history,'[]'))
     where (value->>'completed_on')::date between greatest((reference->>'observed_on')::date,wk-21) and wk-1
       and ((value->'dose'->'task')-array['target_value','instructions','policy_version'])=((baseline->'task')-array['target_value','instructions','policy_version'])
     order by value->>'completed_on' desc loop
     if (h->>'completed_on')::date=any(dates) then continue; end if;
     dates:=array_append(dates,(h->>'completed_on')::date);
     signal:=public.performance_exposure_signal_v2(h,h->'dose');
     if signal='pain' then return p||jsonb_build_object('status','blocked','reason','Confirma tu situación después de las molestias registradas.'); end if;
     if signal='difficulty' then bad:=bad+1; difficult_exposure:=coalesce(difficult_exposure,h); end if;
     if signal<>'tolerated' then qualified:=false;
     else
       good:=good+1;
       if (h->>'completed_on')::date>=wk-7 then last_week:=last_week+1; end if;
     end if;
     exit when cardinality(dates)>=greatest(2,freq);
   end loop;
   if bad>0 then
     -- Una dificultad de una exposición corta tampoco puede ocultarse detrás
     -- de otra dosis distinta de la misma semana.
     if p->>'outcome'<>'reduce' then
       p:=public.performance_task_v3(reference,profile,history,wk,target_date,
         previous||jsonb_build_object('dose',difficult_exposure->'dose'),started_on)||jsonb_build_object('frequency_policy_version','performance_frequency_v2','rep_min',coalesce((reference->>'rep_min')::int,4));
       if p->>'status'<>'ready' then return p; end if;
       select jsonb_agg(p->'dose') into doses from generate_series(1,freq);
     end if;
     if bad>=2 and freq>1 then
       freq:=freq-1;
       select jsonb_agg(value order by ord) into doses from jsonb_array_elements(doses) with ordinality x(value,ord) where ord<=freq;
     end if;
     p:=p||jsonb_build_object('frequency_reason','recent_difficulty');
   elsif qualified and not changed and previous->'dose' is not null and target_date-wk>14
     and p->>'phase' in ('development','specific') and p->>'outcome'<>'reduce'
     and good>=greatest(2,freq) and last_week>=freq
     and (freq>1 or dates[1]-dates[2]>=7)
     and freq<(select count(*) from generate_series(wk,wk+6,interval '1 day')) then
     -- Acreditar la semana entregada completa antes de añadir otra exposición.
     -- Repartimos la comparación tolerada, no la dosis ya incrementada por v3.
     redistributed:=public.performance_redistribute_v2(p,comparison,freq+1);
     if redistributed is not null then
       p:=p||jsonb_build_object('frequency_fallback_dose',p->'dose','frequency_fallback_outcome',p->'outcome',
         'frequency_fallback_reason',p->>'reason','frequency_fallback_exposures',doses,
         'outcome','redistribute','frequency_reason','complete_tolerated_week',
         'reason','Repartimos el trabajo semanal acreditado en otra exposición, sin aumentar también su volumen, carga o velocidad.');
       doses:=redistributed; freq:=freq+1;
     else p:=p||jsonb_build_object('frequency_reason','minimum_useful_dose'); end if;
   else p:=p||jsonb_build_object('frequency_reason','consolidate_current_distribution'); end if;
 end if;
 p:=p||jsonb_build_object('frequency',freq,'frequency_reference_count',known_frequency,
   'exposure_doses',doses,'comparison_exposure_doses',comparison,'dose',doses->0,'frequency_strategy',cfg,
   'recovery_days',cfg->'recovery_days');
 return p||jsonb_build_object('work_seconds',public.performance_work_seconds_v2(p->'dose'),
   'work_minutes',ceil(public.performance_work_seconds_v2(p->'dose')/60.0));
end $$;

create or replace function public.performance_select_v4(proposals jsonb) returns jsonb
language sql immutable set search_path='' as $$
 -- Mantener una práctica principal y como máximo un apoyo opcional por objetivo.
 -- Una referencia libre puede ser la única cobertura de una prueba cronometrada.
 with ranked as (
  select p,row_number() over(partition by p->>'objective_key' order by
   case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
   case p->>'exercise_code' when 'push_up_standard' then 0 when 'push_up_weighted' then 1
    when 'bench_press_barbell' then 2 else 3 end,p->>'reference_id') n
  from jsonb_array_elements(proposals) p where p->>'status'='ready'
 ), selected as (
  select candidate.p||jsonb_build_object('selection_rank',n,'optional',n>1,
    'role',case when n>1 then 'support' else candidate.p->>'role' end,
    'frequency',(candidate.p->>'frequency')::int,
    'selection_reason',coalesce(candidate.p->>'selection_reason','')||case when n>1
      then ' Apoyo opcional con referencia propia; se retira si desplaza trabajo prioritario.' else '' end) p
  from ranked candidate where n=1 or (n=2
   and exists(select 1 from ranked main where main.n=1 and main.p->>'objective_key'=candidate.p->>'objective_key'
     and main.p->>'phase'='development' and (
       (main.p->>'exercise_code'='push_up_standard' and candidate.p->>'role'='support')
       or (main.p->>'model'='course' and candidate.p->>'role'='support' and (candidate.p->>'model'='load_repetitions' or candidate.p->>'exercise_code'='split_squat'))
       or (main.p->>'exercise_code'='front_plank_forearms' and candidate.p->>'exercise_code'='front_plank_high'))
     and coalesce(main.p->>'outcome','initial')<>'reduce')
   and jsonb_array_length(candidate.p->'dose'->'targets')<=2)
  union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) select coalesce(jsonb_agg(p order by coalesce((p->>'selection_rank')::int,0),p->>'reference_id'),'[]') from selected
$$;

create or replace function public.performance_place_v4(proposals jsonb,availability jsonb,occupied jsonb,
 prior_loads jsonb,rotation int,wk date,target_date date) returns jsonb
language plpgsql immutable set search_path='' as $$
declare days jsonb:='{}'; placed jsonb:='[]'; missing jsonb:='[]'; p jsonb; root jsonb; day jsonb; old jsonb;
 n int; d int; used int; cost int; wanted int; assigned int; blocked boolean; same_demand boolean;
 lower_days jsonb:='[]'; remaining jsonb:='{}'; score int:=0; actual_days int[]; rounds int;
begin
 for d in 1..7 loop days:=days||jsonb_build_object(d::text,jsonb_build_object('minutes',0,'work','[]'::jsonb)); end loop;
 -- Primero cubrir cada objetivo una vez; después distribuir su segunda exposición.
 for rounds in 1..coalesce((select max((q->>'frequency')::int) from jsonb_array_elements(proposals) q where q->>'status'='ready'),0) loop
 for root in select value from jsonb_array_elements(proposals) where value->>'status'='ready'
  order by case when value->>'required_for_objective'='true' then 0 else 1 end,
   case when value->>'model' in ('course','power','rope','reactive_agility') then 0 else 1 end,
   coalesce((value->>'goal_priority')::int,1),value->>'objective_key',value->>'reference_id' loop
  p:=public.performance_exposure_v2(root,rounds-1);
  wanted:=(p->>'frequency')::int;
  select coalesce(array_agg((q->>'day')::int),'{}') into actual_days from jsonb_array_elements(placed) q where q->>'reference_id'=p->>'reference_id';
  assigned:=cardinality(actual_days); if rounds>wanted or assigned<>rounds-1 then continue; end if;
  for n in 0..6 loop
   d:=1+(n+rotation)%7;
   if coalesce(occupied,'[]') @> to_jsonb(array[d]) or wk+d-1>=target_date-1 then continue; end if;
   if exists(select 1 from unnest(actual_days) ad where abs(ad-d)<coalesce((p->>'recovery_days')::int,2)) then continue; end if;
   blocked:=false;
   for old in select value from jsonb_array_elements(placed||coalesce(prior_loads,'[]')) loop
    if (old->>'day')::int<>d and abs((old->>'day')::int-d)<greatest(coalesce((p->>'recovery_days')::int,2),coalesce((old->>'recovery_days')::int,2)) and exists(select 1 from jsonb_array_elements_text(p->'body_regions') reg
     where coalesce(old->'body_regions','["upper_body","lower_body","trunk"]') ? reg) then blocked:=true; exit; end if;
   end loop;
   if blocked then continue; end if;
   day:=days->d::text; used:=(day->>'minutes')::int;
   -- No apilar apoyos equivalentes o dos bloques fuertes del mismo patrón por ser ejercicios distintos.
   same_demand:=exists(select 1 from jsonb_array_elements(day->'work') q where
    exists(select 1 from jsonb_array_elements_text(p->'movement_patterns') pat where q->'movement_patterns' ? pat) and not ((p->>'objective_key'=q->>'objective_key' or p->'covered_objective_keys' ? (q->>'objective_key') or q->'covered_objective_keys' ? (p->>'objective_key')) and (p->>'optional'='true') is distinct from (q->>'optional'='true') and jsonb_array_length(p->'dose'->'targets')+jsonb_array_length(q->'dose'->'targets')<=4)
    or (p->'body_regions' ? 'upper_body' and q->'body_regions' ? 'upper_body'
       and (p->>'model'='isometric' or q->>'model'='isometric')
       and jsonb_array_length(p->'dose'->'targets') + coalesce((select sum(jsonb_array_length(t->'dose'->'targets')) from jsonb_array_elements(day->'work') t where t->'body_regions' ? 'upper_body'),0)>(public.performance_bank_v2()->>'maximum_shared_upper_sets')::int));
   if same_demand then continue; end if;
   cost:=coalesce((p->>'reservation_minutes')::int,(p->>'work_minutes')::int)+case when used=0 then 10 else 0 end;
   if used+cost>coalesce((availability->>d::text)::int,0) then continue; end if;
   day:=day||jsonb_build_object('minutes',used+cost,'work',day->'work'||jsonb_build_array(p));
   days:=jsonb_set(days,array[d::text],day);
   placed:=placed||jsonb_build_array(jsonb_build_object('day',d,'reference_id',p->>'reference_id','body_regions',p->'body_regions','recovery_days',p->'recovery_days'));
   score:=score+case when rounds=1 and p->>'required_for_objective'='true' then 1000 when p->>'required_for_objective'='true' then 100 else 10 end;
   exit;
  end loop;
 end loop;
 end loop;
 for p in select value from jsonb_array_elements(proposals) where value->>'status'='ready' loop
  select count(*) into assigned from jsonb_array_elements(placed) q where q->>'reference_id'=p->>'reference_id';
  wanted:=coalesce((p->>'requested_frequency')::int,(p->>'frequency')::int);
  if assigned<wanted then missing:=missing||jsonb_build_array(jsonb_build_object('reference_id',p->>'reference_id',
   'required_for_objective',p->'required_for_objective','objective_key',p->>'objective_key','name',p->>'name','role',p->>'role','requested',wanted,'scheduled',assigned,
   'reason',case when assigned=0 then 'No cabe este estímulo con tiempo y recuperación suficientes. Amplía días o revisa prioridades.' else 'Se pautan '||assigned||' exposiciones; las demás no caben respetando tiempo y recuperación.' end)); end if;
 end loop;
 for d in 1..7 loop
  day:=days->d::text; remaining:=remaining||jsonb_build_object(d::text,greatest(0,coalesce((availability->>d::text)::int,0)-(day->>'minutes')::int));
  if exists(select 1 from jsonb_array_elements(day->'work') x where coalesce((x->>'running_leg_load')::boolean,x->'body_regions' ? 'lower_body')) then lower_days:=lower_days||to_jsonb(d); end if;
 end loop;
 return jsonb_build_object('days',days,'remaining',remaining,'lower_days',lower_days,'missing',missing,'score',score);
end $$;

create or replace function public.performance_support_candidates_v2(goal uuid,wk date,proposals jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb:=proposals; main jsonb; recipe jsonb; observed jsonb; profile jsonb;
 parent public.performance_training_references%rowtype; ctx public.performance_training_contexts%rowtype;
 target date; rid uuid; reference jsonb; task jsonb; dose jsonb; proposal jsonb; best_recipe jsonb; best_observed jsonb;
begin
 select target_date into target from public.preparation_goals where id=goal and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into ctx from public.performance_training_contexts where user_id=auth.uid();
 if not found or ctx.reports_pain or not ctx.capacity_confirmed or ctx.observed_at<now()-interval '30 days' then return result; end if;
 for main in select value from jsonb_array_elements(public.performance_select_v4(proposals))
   where value->>'status'='ready' and value->>'optional'='false' and value->>'phase'='development'
    and value->>'outcome'<>'reduce' loop
  -- No multiplicar accesorios: una opción ya practicable tiene prioridad.
  if exists(select 1 from jsonb_array_elements(public.performance_select_v4(proposals)) p
    where p->>'objective_key'=main->>'objective_key' and p->>'optional'='true') then continue; end if;
  select * into parent from public.performance_training_references where id=(main->>'reference_id')::uuid
   and user_id=auth.uid() and preparation_goal_id=goal and active;
  if not found then continue; end if;
  best_recipe:=null; best_observed:=null;
  for recipe in select value from jsonb_array_elements(public.performance_support_recipes_v2())
    where value->>'goal'=parent.target_profile_code order by (value->>'rank')::int loop
   if exists(select 1 from public.performance_training_references retired where retired.preparation_goal_id=goal
      and retired.user_id=auth.uid() and retired.objective_key=parent.objective_key and not retired.active
      and retired.reference->'task'->>'exercise_code'=recipe->>'work')
    and not exists(select 1 from public.performance_training_references active_ref where active_ref.preparation_goal_id=goal
      and active_ref.objective_key=parent.objective_key and active_ref.active
      and active_ref.reference->'task'->>'exercise_code'=recipe->>'work') then continue; end if;
   select definition||jsonb_build_object('definition_version',definition_version) into profile from public.exercise_training_profiles ep where code=recipe->>'work'
     order by definition_version desc limit 1;
   if profile is null or not exists(select 1 from public.performance_exercise_relations rel
      where rel.policy_version='performance_v1' and rel.goal_code=parent.target_profile_code and rel.work_code=recipe->>'work')
    or not exists(select 1 from public.exercises ex where ex.training_profile_code=recipe->>'work'
      and ex.training_profile_version=(profile->>'definition_version')::int and ex.is_public)
    or not exists(select 1 from jsonb_array_elements(profile->'measurement_options') opt
      where opt->>'mode'=recipe->>'measurement' and opt->'load_modes' ? (recipe->>'load_mode'))
    or exists(select 1 from jsonb_array_elements_text(profile->'required_equipment') eq where not eq=any(ctx.equipment)) then continue; end if;
   observed:=public.performance_support_observed_v2(recipe->>'work',(profile->>'definition_version')::int,
     recipe->>'measurement',recipe->>'load_mode',wk);
   -- Una omisión o una práctica no utilizable no se convierte en éxito ni se
   -- vuelve a pedir cada semana. Se deja una ventana antes de reconsiderarla.
   if observed is null and exists(select 1 from public.performance_week_work pw
      join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
      left join public.workout_executions e on e.id=sw.execution_id
      join public.performance_training_references trial_ref on trial_ref.id=pw.reference_id
      where sw.user_id=auth.uid() and sw.preparation_goal_id=goal and trial_ref.objective_key=parent.objective_key
       and pw.dose->'task'->>'policy_version' in ('support_familiarization_v1','support_familiarization_v2')
       and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date) between wk-14 and wk-1) then continue; end if;
   if best_recipe is null or (best_observed is null and observed is not null) then
    best_recipe:=recipe; best_observed:=observed;
   end if;
  end loop;
  if best_recipe is null then continue; end if;
  recipe:=best_recipe; observed:=best_observed;
  select definition||jsonb_build_object('definition_version',definition_version) into profile from public.exercise_training_profiles where code=recipe->>'work' order by definition_version desc limit 1;
  rid:=md5('support-v1:'||goal::text||':'||parent.objective_key||':'||(recipe->>'work'))::uuid;
  task:=jsonb_build_object('schema_version',1,'exercise_code',recipe->>'work','exercise_version',profile->'definition_version',
    'protocol_key','support_work_v1:'||(recipe->>'work'),'protocol_version',1,'setup_key','standard:support_v1:'||(recipe->>'work'),
    'measurement',recipe->>'measurement','load_mode',recipe->>'load_mode','intent','work',
    'policy_version',case when recipe->>'measurement'='DURATION' then 'support_familiarization_v2' else 'support_familiarization_v1' end,
    'target_value',case when recipe->>'measurement'='DURATION' then 15 else 8 end,
    'effort_mode',case when recipe->>'measurement'='DURATION' then 'rpe' else 'rir' end,
    'stimulus_code',case when recipe->>'measurement'='DURATION' then 'SUPPORT-ISO-F01' else 'SUPPORT-F01' end,
    'instructions',recipe->>'instructions');
  if recipe->>'measurement'='DURATION' then
   task:=task||jsonb_build_object('protocol_key','support_work_v2:'||(recipe->>'work'),
    'setup_key','standard:support_v2:'||(recipe->>'work'),'target_rpe',6);
  else task:=task||'{"target_rir":3}'::jsonb; end if;
  reference:=jsonb_build_object('id',rid,'task',task,'reference_kind','guided_pending','role','support',
    'objective_key',parent.objective_key,'goal_code',parent.target_profile_code,'goal_measurement',parent.target_measurement,
    'program_objective_key',parent.reference->'program_objective_key','frequency',1,
    'automatic_support',jsonb_build_object('version','support_v1','parent_reference_id',parent.id,'recipe',recipe->>'work'));
  if observed is not null then
   task:=((observed->'task')-array['external_load_kg','body_mass_kg'])||jsonb_build_object(
     'policy_version','reference_v2','target_value',observed->'result'->'value',
     'instructions',case when observed->'task'->>'policy_version'='support_familiarization_v1' and recipe->>'load_mode'<>'bodyweight'
       then 'Repite la colocación y técnica de tu práctica registrada. Utiliza la carga pautada; no busques un máximo.'
       else coalesce(observed->'task'->>'instructions','') end);
   if recipe->>'load_mode'<>'bodyweight' then task:=task||jsonb_build_object('external_load_kg',observed->'result'->'load_kg'); end if;
   if recipe->>'load_mode'='bodyweight_plus_external' then task:=task||jsonb_build_object('body_mass_kg',observed->'result'->'body_mass_kg'); end if;
   reference:=reference||jsonb_build_object('task',task,'reference_kind','performed_set','current_capacity_confirmed',true,
     'observed_on',observed->'observed_on','targets',jsonb_build_array(observed->'result'->'value'),
     'reported_rir',observed->'result'->'rir','reported_rpe',observed->'result'->'rpe','rest_seconds',0,'rep_min',4,'rep_max',8,
     'automatic_support',reference->'automatic_support'||jsonb_build_object('observation',observed-'task'-'result'));
   proposal:=public.performance_task_v5(reference,profile,'[]',wk,target,'{}',wk);
   if proposal->>'status'<>'ready' then continue; end if;
   proposal:=proposal||jsonb_build_object('reason',proposal->>'reason'||' Reutilizamos una práctica reciente de esta misma variante.',
     'support_entry','observed');
  else
   dose:=jsonb_build_object('task',task,'targets',jsonb_build_array(task->'target_value'),'rest_seconds',0,
     'model',case when recipe->>'measurement'='LOAD_REPS' then 'load_repetitions' when recipe->>'measurement'='DURATION' then 'isometric' else 'repetitions' end,'stimulus_code',task->>'stimulus_code');
   proposal:=jsonb_build_object('status','ready','frequency',1,'phase',main->>'phase','outcome','familiarization',
     'model',dose->>'model','dose',dose,'comparison_dose',dose,'exposure_doses',jsonb_build_array(dose),
     'comparison_exposure_doses',jsonb_build_array(dose),'work_seconds',360,'work_minutes',6,'recovery_days',2,
     'support_entry','guided','reason','Primera práctica opcional para conocer este apoyo. Sin kilos ni resultados inventados; puedes omitirla.',
     'selection_reason','Un único apoyo pertinente, con seis minutos reservados para prepararlo y registrar una práctica submáxima.');
  end if;
  proposal:=proposal||jsonb_build_object('reference_id',rid,'objective_key',parent.objective_key,'role','support',
    'exercise_code',recipe->>'work','name',case when observed is null then 'Primera práctica · ' else '' end||(profile->>'name'),
    'body_regions',case when recipe->>'work'='front_plank_high' then profile->'body_regions'||'"upper_body"'::jsonb else profile->'body_regions' end,'movement_patterns',profile->'movement_patterns',
    'automatic_reference',jsonb_build_object('reference',reference,'parent_reference_id',parent.id));
  -- Retirar únicamente candidatos no utilizables de ESTA variante/objetivo.
  select coalesce(jsonb_agg(p),'[]') into result from jsonb_array_elements(result) p
    where not(p->>'objective_key'=parent.objective_key and p->>'exercise_code'=recipe->>'work' and p->>'status'<>'ready');
  result:=result||jsonb_build_array(proposal);
 end loop;
 return result;
end $$;

create or replace function public.persist_automatic_support_v1(goal uuid,work jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare parent public.performance_training_references%rowtype; r jsonb:=work->'automatic_reference'->'reference'; entry jsonb;
begin
 if jsonb_array_length(coalesce(work->'automatic_references','[]'))>0 then
  for entry in select value from jsonb_array_elements(work->'automatic_references') loop
   perform public.persist_automatic_support_v1(goal,jsonb_build_object('automatic_reference',entry));
  end loop;
  return;
 end if;
 if r is null then return; end if;
 select * into parent from public.performance_training_references where id=(work->'automatic_reference'->>'parent_reference_id')::uuid
  and preparation_goal_id=goal and user_id=auth.uid() and active;
 if not found or not exists(select 1 from jsonb_array_elements(public.performance_support_recipes_v2()) recipe
   where recipe->>'goal'=parent.target_profile_code and recipe->>'work'=r->'task'->>'exercise_code') then
  raise exception 'El apoyo no corresponde a esta preparación.' using errcode='42501'; end if;
 update public.performance_training_references set active=false where preparation_goal_id=goal and objective_key=parent.objective_key
  and reference->'task'->>'exercise_code'=r->'task'->>'exercise_code' and active and id<>(r->>'id')::uuid;
 insert into public.performance_training_references(id,user_id,preparation_goal_id,test_id,objective_key,target_profile_code,
   target_profile_version,target_measurement,reference)
 values((r->>'id')::uuid,auth.uid(),goal,parent.test_id,parent.objective_key,parent.target_profile_code,
   parent.target_profile_version,parent.target_measurement,r)
 on conflict(id) do update set reference=excluded.reference,active=true
 where performance_training_references.user_id=auth.uid() and performance_training_references.preparation_goal_id=goal;
end $$;

create or replace function public.performance_work_seconds_v2(dose jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare seconds numeric; m text:=dose->'task'->>'measurement';
begin
 if public.is_support_familiarization_v1(dose->'task') or public.is_support_familiarization_v2(dose->'task') then return 360; end if;
 select sum(case
  when m='DURATION' then value::numeric
  when m='REPS_IN_TIME' then (dose->'task'->>'fixed_duration_seconds')::numeric
  when m in ('TIME_FOR_DISTANCE','TIME_FOR_COURSE') then greatest(30,value::numeric)
  when m in ('REPS','LOAD_REPS') then value::numeric*5
  when m='DISTANCE' and dose->>'model'='carry' then value::numeric*2
  else 30 end) into seconds from jsonb_array_elements_text(dose->'targets');
 return ceil(seconds+greatest(0,jsonb_array_length(dose->'targets')-1)*(dose->>'rest_seconds')::int+60)::int;
end $$;

create or replace function public.calculate_running_week_constrained(
 p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean,p_constraints jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 ctx public.running_intake_contexts%rowtype; ref record; age integer;
 revise boolean:=coalesce((p_constraints->>'revise_week')::boolean,false);
 excluded uuid[]:=array(select value::uuid from jsonb_array_elements_text(coalesce(p_constraints->'excluded_session_ids','[]')));
 last_sunday date:=current_date-extract(isodow from current_date)::integer;
 prev public.running_week_decisions%rowtype; existing public.running_week_decisions%rowtype;
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb; capacity_evidence jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<last_sunday-6 or p_week_start>current_date+28 then
   raise exception 'Choose a current or upcoming complete week'; end if;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 if not p_replay_initial then
   select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
   if found and not revise then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
   select * into prev from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null order by week_start desc limit 1;
 end if;
 if prev.id is not null and current_date<p_week_start-1 and not p_preview_future then
   raise exception 'Close the previous week before adapting'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=p_goal_id;
 if not found then raise exception 'Update the current running context'; end if;
 -- Solo cambia la proyección de carga; conserva las fechas de salud y el motor v5.
 ctx:=jsonb_populate_record(ctx,public.running_context_observed_v1(p_goal_id,current_date));
 if ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
   or (prev.id is null and ctx.recent_weeks_end_on<>last_sunday) then
   raise exception 'Update the current running context'; end if;
 if ctx.reports_pain or ctx.requires_professional_review then raise exception 'Health flag pauses the automatic proposal'; end if;
 select * into ref from jsonb_to_record(public.resolve_program_running_reference(p_goal_id))
   as x(reference_source text,reference_record_id text,continuity_confirmed_at timestamptz,completed_at timestamptz,value numeric,standard jsonb,controls jsonb);
 standard:=ref.standard; controls:=ref.controls;
 age:=current_date-ref.completed_at::date;
 if age<0 or ref.completed_at>now() then raise exception 'The selected 2 km mark is outside the reuse window'; end if;
 if age>30 and age<=45 and (ref.continuity_confirmed_at is null
   or ctx.recent_weeks_end_on<>last_sunday or 0=any(ctx.running_days_last_four_weeks)) then
   raise exception 'Confirm uninterrupted running before reuse'; end if;
 -- Fuera de ventana no se derivan ritmos. La semana fácil de mantenimiento
 -- solicita un control nuevo; no inventa una mejora ni perpetúa un ancla vieja.
 select coalesce(jsonb_agg(extract(isodow from public.workout_load_on_v1(scheduled_workouts))::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(excluded)
   and (not revise or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)))
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),'scheduled_date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',coalesce(public.workout_block_outcome_v1(e.id)->>'status',sw.status),'rpe',case when exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id)
   then (select max(r.actual_rpe) from public.workout_execution_sets r where r.execution_id=e.id and r.block_format='running') else e.final_rpe end,'abandonment_reason',public.workout_block_outcome_v1(e.id)->>'abandonment_reason',
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),e.id),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id and es.block_format='running') sets on true
 where sw.user_id=u and sw.status not in ('cancelled') and wd.policy_version in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56
   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(public.workout_load_on_v1(sw)-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(excluded)
   and (not revise or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and exists(select 1 from public.workout_blocks b
     where b.template_id=sw.template_id and b.format not in ('running','warm_up','cool_down')
       and exists(select 1 from public.workout_items wi join public.exercises ex on ex.id=wi.exercise_id
         left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
         where wi.block_id=b.id and (ep.code is null or ep.definition->'body_regions' ? 'lower_body')));
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') then
   previous:=previous||jsonb_build_object('normal_budget',
     (select sum(planned_minutes) from public.running_week_sessions where decision_id=prev.id),
     'load_weeks',0,'rotation',0);
 end if;
 capacity_evidence:=public.running_capacity_observed_v1(p_goal_id,p_week_start);
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,
   'capacity_minutes',capacity_evidence->'trial_minutes','capacity_evidence',capacity_evidence,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 -- El coordinador puede solicitar otra propuesta con el tiempo restante.
 -- La selección deportiva sigue en v5; la evidencia usa la realización real.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 result:=public.running_plan_v5(input);
 return result||jsonb_build_object('capacity_evidence',capacity_evidence,'evidence_policy_version','adaptive_evidence_v1','goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

create or replace function public.calculate_preparation_week_for_scope(p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype; ctx public.performance_training_contexts%rowtype;
  existing public.preparation_week_decisions%rowtype; previous public.preparation_week_decisions%rowtype;
  ref record; history jsonb; prior jsonb; proposal jsonb; proposals jsonb:='[]'; pending jsonb:='[]';
  occupied jsonb; loads jsonb; candidate jsonb; best jsonb; running jsonb; best_running jsonb;
  started_on date; include_support boolean; frequency_limit int; candidates jsonb; expected_running jsonb; minimum_runs int:=1; expected_runs int:=0; actual_runs int:=0;
  shared_credit int; rotation int; score int; best_score int:=-2147483647; d int; session jsonb; blocked boolean; has_running boolean;
  running_cache jsonb:='{}'; running_constraints jsonb; cache_key text; running_error text; best_error text; coordinated jsonb; sessions jsonb:='[]'; required_missing boolean; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u and status='active';
 if not found then raise exception 'Preparación activa no disponible.' using errcode='42501'; end if;
 select * into existing from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 if found and not p_revision then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<current_date-extract(isodow from current_date)::int+1
   or p_week_start>current_date+28 then raise exception 'Elige una semana actual o próxima.' using errcode='22023'; end if;
 select * into previous from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null order by week_start desc limit 1;
 select * into ctx from public.performance_training_contexts where user_id=u;
 if not found or ctx.observed_at<now()-interval '30 days' or not ctx.capacity_confirmed or ctx.reports_pain then
   return jsonb_build_object('status','needs_context','reason','Actualiza disponibilidad, material y capacidad actual antes de planificar.','sessions','[]'::jsonb); end if;
 if exists(select 1 from public.workout_executions e left join public.workout_execution_sets es on es.execution_id=e.id
   where e.user_id=u and coalesce(es.completed_at,e.completed_at,e.started_at)>ctx.observed_at
     and (e.abandonment_reason='discomfort' or es.performance_result->>'stop_reason'='discomfort' or es.performance_result->>'tolerated'='false')) then
   return jsonb_build_object('status','needs_context','reason','Has registrado molestias después de confirmar el contexto. Revisa tu situación actual antes de planificar.','sessions','[]'::jsonb); end if;
 if g.target_date<current_date then return jsonb_build_object('status','blocked','reason','Actualiza la fecha objetivo.','sessions','[]'::jsonb); end if;
 select coalesce(min(week_start),p_week_start) into started_on from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;
 for ref in select r.*,ep.definition from public.performance_training_references r
   join public.exercise_training_profiles ep on ep.code=r.reference->'task'->>'exercise_code'
     and ep.definition_version=(r.reference->'task'->>'exercise_version')::int
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and not (r.target_profile_code='front_plank_forearms' and r.reference->'task'->>'exercise_code'='dead_bug')
    and coalesce(r.reference->>'reference_kind','')<>'guided_pending'
    and (not r.reference ? 'automatic_support' or public.performance_support_source_valid_v2(r.reference)) and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
   select coalesce(jsonb_agg(jsonb_build_object('execution_id',e.id,'completed_on',public.workout_performed_on_v1(e),'scheduled_date',sw.scheduled_date,
     'status',public.workout_block_outcome_v1(e.id,pw.block_order)->>'status',
     'abandonment_reason',public.workout_block_outcome_v1(e.id,pw.block_order)->>'abandonment_reason','dose',pw.dose,'sets',sets.items) order by coalesce(e.performed_at,e.completed_at),e.id),'[]') into history
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   join public.workout_executions e on e.id=sw.execution_id
   join lateral(select jsonb_agg(jsonb_build_object('status',es.status,'prescription',es.performance_prescription,
     'result',es.performance_result) order by es.set_order) items from public.workout_execution_sets es
     where es.execution_id=e.id and es.block_order=pw.block_order) sets on true
   where pw.reference_id=ref.id and public.workout_performed_on_v1(e)<p_week_start and public.workout_performed_on_v1(e)>=p_week_start-56;
   select value into prior from jsonb_array_elements(coalesce(previous.decision->'proposals','[]'))
     where value->>'reference_id'=ref.id::text or value->'covered_reference_ids' ? ref.id::text limit 1;
   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) then
     proposal:=jsonb_build_object('status','needs_equipment','reason','Falta material para esta variante; usa una alternativa calibrada compatible.');
   else proposal:=public.performance_task_v5(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end,started_on); end if;
   -- Cualquier molestia posterior al contexto pausa, aunque haya resultados buenos después.
   if exists(select 1 from jsonb_array_elements(history) h
     where (h->>'completed_on')::date>=ctx.observed_at::date and
       (h->>'abandonment_reason'='discomfort' or exists(select 1 from jsonb_array_elements(h->'sets') rs
         where rs->'result'->>'stop_reason'='discomfort' or rs->'result'->>'tolerated'='false'))) then
     proposal:=jsonb_build_object('status','blocked','reason','Actualiza el contexto después de las molestias registradas.'); end if;
   proposal:=proposal||jsonb_build_object('reference_id',ref.id,'objective_key',ref.objective_key,
     'name',coalesce(proposal->>'name',ref.definition->>'name'),'role',ref.reference->>'role','exercise_code',coalesce(proposal->'dose'->'task'->>'exercise_code',ref.definition->>'code'));
   proposals:=proposals||jsonb_build_array(proposal);
 end loop;

 if p_scope<>'running' then proposals:=public.performance_support_candidates_v2(p_goal_id,p_week_start,proposals); end if;

 select coalesce(jsonb_agg(p||jsonb_build_object('goal_review',review,'goal_priority',coalesce((review->>'priority')::int,1))),'[]')
  into proposals from jsonb_array_elements(proposals) p left join lateral(
   select value review from jsonb_array_elements(public.performance_goal_reviews_v1(p_goal_id,p_week_start))
    where value->>'objective_key'=p->>'objective_key') r on true;
 proposals:=public.performance_select_v4(proposals);
 -- Seleccionar específico accesible; la regresión conserva visible la práctica
 -- específica pendiente. No pautar dos regresiones para el mismo objetivo.
 select coalesce(jsonb_agg(p),'[]') into proposals from jsonb_array_elements(proposals) p
 where p->>'role'<>'regression' or not exists(select 1 from jsonb_array_elements(proposals) q
   where q->>'objective_key'=p->>'objective_key' and q->>'status'='ready'
     and (q->>'role'='specific' or (q->>'role'='regression' and q->>'reference_id'<p->>'reference_id')));
 select coalesce(jsonb_agg(case when exists(select 1 from jsonb_array_elements(proposals) q
   where q->>'objective_key'=p->>'objective_key' and q->>'status'='ready' and q->>'role' in ('specific','regression'))
   then p||'{"role":"support"}'::jsonb else p end),'[]') into pending
   from jsonb_array_elements(proposals) p where p->>'status'<>'ready';
 -- Una misma tarea calibrada sirve a varios objetivos sin duplicar su volumen.
 select coalesce(jsonb_agg(x.proposal),'[]') into proposals from (
   select (jsonb_agg(p order by case when p->>'role'='specific' then 0 when p->>'role'='regression' then 1 else 2 end,p->>'reference_id')->0)
     ||jsonb_build_object('automatic_references',coalesce(jsonb_agg(p->'automatic_reference') filter(where p ? 'automatic_reference'),'[]'),
     'goal_priority',min(coalesce((p->>'goal_priority')::int,1)),
     'covered_reference_ids',jsonb_agg(p->'reference_id'),'covered_objective_keys',jsonb_agg(p->'objective_key'),'frequency',max((p->>'frequency')::int)) proposal
   from jsonb_array_elements(proposals) p where p->>'status'='ready' group by p->'dose',p->'exposure_doses',p->'frequency'
   union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) x;
 if p_scope<>'running' then
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=p_goal_id order by a.assessed_on desc,a.created_at desc limit 1;
 if selected_category is null and exists(select 1 from public.program_assessment_tests where program_id=g.program_id and (category<>'both' or min_age<>0 or max_age<>120)) then
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_assessment','name','Categoría de las pruebas',
     'reason','Completa la evaluación de esta preparación para identificar las pruebas que te corresponden.')); end if;
 for ref in select b.test_id,t.name from public.program_test_training_bindings b
   join public.program_assessment_tests t on t.id=b.test_id
   where b.program_id=g.program_id and public.performance_test_applies(g.id,t.id) and (t.category='both' or t.category=selected_category)
     and not exists(select 1 from public.performance_training_references r where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and r.test_id=b.test_id) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_calibration','objective_key',ref.test_id,
     'name',ref.name,'reason','Esta prueba del programa aún no tiene referencia de trabajo.'));
 end loop;
 for ref in select o.* from public.performance_legacy_objectives o where o.program_id=g.program_id
   and (o.max_age_exclusive is null or coalesce((select extract(year from age(coalesce(g.target_date,current_date),fecha_nacimiento)) from public.profiles where id=u),0)<o.max_age_exclusive)
   and not exists(select 1 from public.performance_training_references r where r.preparation_goal_id=g.id and r.active and r.objective_key=o.objective_key) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_calibration','name',ref.name,'objective_key',ref.objective_key,'reason','Falta la referencia de trabajo de esta prueba del programa.'));
 end loop;
 for ref in select t.name from public.program_assessment_tests t where t.program_id=g.program_id and public.performance_test_applies(g.id,t.id)
   and t.category in ('both',selected_category)
   and not exists(select 1 from public.program_test_training_bindings b where b.test_id=t.id)
   and not exists(select 1 from public.program_training_modules m where m.test_id=t.id) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_strategy','name',ref.name,'reason','ADMIN debe configurar una estrategia compatible para esta prueba.'));
 end loop;
 end if;
 select coalesce(jsonb_agg(extract(isodow from public.workout_load_on_v1(scheduled_workouts))::int),'[]') into occupied
   from public.scheduled_workouts where user_id=u and public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6 and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(p_excluded)
   and (not p_revision or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)));
 select coalesce(jsonb_agg(jsonb_build_object('day',public.workout_load_on_v1(sw)-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'),
   'recovery_days',coalesce((select max((public.performance_frequency_strategy_v2(jsonb_build_object('dose',pw.dose))->>'recovery_days')::int)
     from public.performance_week_work pw where pw.scheduled_workout_id=sw.id),2))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-7 and p_week_start+13
     and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',public.workout_load_on_v1(sw)-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-7 and p_week_start+13
   and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=p_scope<>'performance' and (exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry'));
 -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and (q->>'objective_key'=p->>'objective_key' or q->'covered_objective_keys' ? (p->>'objective_key') or p->'covered_objective_keys' ? (q->>'objective_key'))
   and (case q->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
        coalesce((q->>'selection_rank')::int,1),q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,coalesce((p->>'selection_rank')::int,1),p->>'reference_id')))),'[]') into proposals
 from jsonb_array_elements(proposals) p;
 if has_running then
  begin
   expected_running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
    jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),'availability',ctx.availability,'strength_days','[]'::jsonb,'leg_load_days','[]'::jsonb));
   expected_runs:=jsonb_array_length(coalesce(expected_running->'sessions','[]')); minimum_runs:=least(2,greatest(1,expected_runs));
  exception when others then expected_running:=null; end;
 end if;
 for include_support in select unnest(array[true,false]) loop
 for frequency_limit in reverse coalesce((select max((p->>'frequency')::int) from jsonb_array_elements(proposals) p where p->>'status'='ready'),1)..0 loop
 select coalesce(jsonb_agg(public.performance_frequency_candidate_v2(p,frequency_limit)),'[]') into candidates from jsonb_array_elements(proposals) p where include_support or p->>'optional' is distinct from 'true';
 for rotation in 0..6 loop
   candidate:=public.performance_place_v4(candidates,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
   -- Ensayar reservas sin ahorro, con activación compartida y con cierre.
   -- Cada alternativa pasa el coste exacto antes de puntuar.
   for shared_credit in select unnest(array[0,4,7]) loop
   running:=null; running_error:=null;
   if has_running then
     begin
       running_constraints:=jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),
         'availability',public.preparation_running_budget_v1(candidate,ctx.availability,shared_credit),'strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days');
       cache_key:=running_constraints::text;
       -- Las alternativas repetidas no vuelven a leer y evaluar el historial.
       -- Caché local a esta llamada; el coste conjunto se valida siempre abajo.
       if running_cache ? cache_key then running:=running_cache->cache_key;
       else
        running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,running_constraints);
        running_cache:=running_cache||jsonb_build_object(cache_key,running);
       end if;
     if jsonb_array_length(coalesce(running->'sessions','[]'))=0 then
         running_error:='No cabe una sesión de carrera compatible. Revisa disponibilidad y referencias.'; running:=null;
       elsif exists(select 1 from jsonb_array_elements(running->'sessions') rs where
         (case when coalesce((candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text->>'minutes')::int,0)>0
           then public.preparation_shared_minutes_v2(candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text,rs)
           else (rs->>'minutes')::int end)>coalesce((ctx.availability->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)) then
         running_error:='La carrera ya publicada supera la disponibilidad actual. Revisa la agenda antes de añadir fuerza.'; running:=null;
       end if;
     exception when others then
       running_error:=case
         when sqlerrm like '%current running context%' then 'Confirma tu contexto actual de carrera; recuperamos los entrenamientos que ya has registrado.'
         when sqlerrm like '%Health flag%' then 'Has indicado molestias en carrera. Actualiza tu situación antes de planificar.'
         when sqlerrm like '%compatible 2 km mark%' or sqlerrm like '%reuse window%' then 'Elige una marca vigente de 2 km para esta preparación.'
         when sqlerrm like '%Confirm uninterrupted%' then 'Confirma la continuidad de carrera para reutilizar esta marca.'
         when sqlerrm like '%standard or margin%' then 'Falta un mínimo oficial aplicable; elige una meta concreta o mejorar sin cifra.'
         else 'No se ha podido proponer carrera. Revisa la referencia, el cuestionario y los días disponibles.' end;
     end;
   end if;
   -- Una redistribución a medias no es una pauta: comparar la alternativa completa.
   if exists(select 1 from jsonb_array_elements(candidate->'missing') m
      join jsonb_array_elements(candidates) c on c->>'reference_id'=m->>'reference_id'
      where c->>'outcome'='redistribute') then continue; end if;
   score:=(candidate->>'score')::int;
   -- Cobertura antes que minutos: evita premiar accesorios por desplazar carrera.
   score:=score - 10000*(select count(*) from jsonb_array_elements(candidate->'missing') q where q->>'required_for_objective'='true' and (q->>'scheduled')::int=0);
   if running is not null then score:=score+1000+300*jsonb_array_length(running->'sessions')
     +100*(select count(*) from jsonb_array_elements(running->'sessions') q where q->>'kind'<>'easy'); end if;
   if frequency_limit=0 then score:=score-50; end if;
   if has_running and jsonb_array_length(coalesce(running->'sessions','[]'))<minimum_runs then score:=score-10000; end if;
   if score>best_score then best:=candidate; best_running:=running; best_score:=score; best_error:=running_error; end if;
 end loop;
 end loop;
 end loop;
 end loop;
 -- El trabajo descartado no consume el permiso de progresar de lo publicado.
 select coalesce(jsonb_agg(w),'[]') into coordinated from (select distinct on (w->>'reference_id') w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w order by w->>'reference_id',(w->>'exposure_index')::int) chosen;
 -- Persistir exposiciones entregadas, no una frecuencia deseada que no cupo.
 select coalesce(jsonb_agg(p||jsonb_build_object('frequency',
   (select count(*) from jsonb_each(best->'days') d,jsonb_array_elements(d.value->'work') w
    where w->>'reference_id'=p->>'reference_id'),
   'exposure_doses',(select jsonb_agg(w->'dose' order by (w->>'exposure_index')::int) from jsonb_each(best->'days') d,
     jsonb_array_elements(d.value->'work') w where w->>'reference_id'=p->>'reference_id'))),'[]') into coordinated
 from jsonb_array_elements(coordinated) p;
 coordinated:=public.performance_coordinate_progression_v3(coordinated,best_running,p_week_start);
 select coalesce(jsonb_agg(public.performance_reconcile_exposures_v2(p)),'[]') into coordinated from jsonb_array_elements(coordinated) p;
 select coordinated||coalesce(jsonb_agg(p||jsonb_build_object('allocation_status','not_scheduled','allocation_reason','Se conserva la referencia, pero esta semana tiene prioridad la cobertura específica, carrera y recuperación.')),'[]') into coordinated from jsonb_array_elements(proposals) p
 where not exists(select 1 from jsonb_array_elements(coordinated) c where c->>'reference_id'=p->>'reference_id');
 -- Mantener una dosis solo reduce el coste ya reservado; nunca rellena ese margen.
 for d in 1..7 loop
   select coalesce(jsonb_agg(c order by w.ordinality),'[]') into session from jsonb_array_elements(best->'days'->d::text->'work') with ordinality w(value,ordinality)
     join lateral(select public.performance_exposure_v2(value,coalesce((w.value->>'exposure_index')::int,0)) c from jsonb_array_elements(coordinated) c where c->>'reference_id'=w.value->>'reference_id') q on true;
   best:=jsonb_set(best,array['days',d::text,'work'],session);
 end loop;
 proposals:=coordinated;
 pending:=pending||coalesce(best->'missing','[]');
 if best_error is not null then pending:=pending||jsonb_build_array(jsonb_build_object('status','running_pending','name','Carrera','reason',best_error)); end if;
 for d in 1..7 loop
   session:=best->'days'->d::text;
   if (session->>'minutes')::int>0 then sessions:=sessions||jsonb_build_array(session||jsonb_build_object(
     'date',p_week_start+d-1,'kind','performance','name','Fuerza y rendimiento','session_order',case when exists(select 1 from jsonb_array_elements(session->'work') w where w->>'model' in ('power','course','reactive_agility','rope')) then 'performance_first' else 'running_first' end,'warm_up_seconds',420,'cool_down_seconds',180,'warm_up_instructions',public.performance_warm_up_instructions_v1(session),'warm_up_protocol_version','warm_up_v1_1')); end if;
 end loop;
 sessions:=public.performance_controls_v3(sessions,coalesce(previous.decision,'{}'));
 -- Una misma sesión física comparte preparación general y vuelta a la calma.
 select coalesce(jsonb_agg(case when r.item is null then f else f||jsonb_build_object(
   'combined',true,'standalone_minutes',f->'minutes',
   'minutes',public.preparation_shared_minutes_v2(f,r.item)-(r.item->>'minutes')::int,
   'shared_total_minutes',public.preparation_shared_minutes_v2(f,r.item),
   'warm_up_instructions',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup')
    then 'La activación general se comparte con carrera. Después: 1:00 de movilidad de las articulaciones que usarás y 2:00 de ensayo fácil de los movimientos pautados. Sin máximos.' else f->>'warm_up_instructions' end,
   'warm_up_seconds',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup') then 180 else 420 end
 ) end),'[]') into sessions from jsonb_array_elements(sessions) f
 left join lateral(select value item from jsonb_array_elements(coalesce(best_running->'sessions','[]')) q where q->>'date'=f->>'date') r on true;
 -- Un apoyo puede ser la única entrada de un objetivo; no debe desaparecer sin aviso.
 select coalesce(jsonb_agg(case when p->>'objective_key' is not null and exists(
   select 1 from jsonb_array_elements(sessions) ses,jsonb_array_elements(ses->'work') w
   where w->>'objective_key'=p->>'objective_key' or exists(select 1 from public.performance_training_references r
     where w->'covered_reference_ids' ? r.id::text and r.objective_key=p->>'objective_key'))
   then p||'{"role":"support"}'::jsonb else p||'{"role":"specific"}'::jsonb end),'[]') into pending from jsonb_array_elements(pending) p;
 actual_runs:=jsonb_array_length(coalesce(best_running->'sessions','[]'));
 if actual_runs>0 and actual_runs<expected_runs then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','reduced_running_coverage','name','Frecuencia de carrera',
   'role','support','scheduled',actual_runs,'requested',expected_runs,
   'reason','La semana conjunta conserva '||actual_runs||' de las '||expected_runs||' salidas que cabrían dedicando esos días solo a carrera. Para conservar ambas frecuencias, añade otro día o más tiempo.'));
 end if;
 if has_running and actual_runs<minimum_runs then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_running_frequency','name','Cobertura de carrera','role','specific',
   'reason','La distribución deja menos de '||minimum_runs||' salidas de carrera. Añade tiempo u otro día para cubrir la preparación conjunta.'));
 end if;
 if has_running and actual_runs=0 and not exists(select 1 from jsonb_each(ctx.availability) a where (a.value::text)::int>=25) then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_running_time','name','Tiempo para carrera','role','specific',
   'reason','Carrera v5 necesita al menos 25 minutos para una sesión completa. Ninguno de tus días alcanza ese tiempo. Aumenta al menos un día y vuelve a revisar la semana.'));
 end if;
 required_missing:=(has_running and actual_runs<minimum_runs) or (jsonb_array_length(sessions)=0 and best_running is null) or exists(select 1 from jsonb_array_elements(pending) p
   where coalesce(p->>'role','specific')<>'support' and coalesce((p->>'scheduled')::int,0)=0);
 return jsonb_build_object('status',case when required_missing then 'needs_attention' else 'ready' end,
   'policy_version','preparation_coordinator_v4','evidence_policy_version','adaptive_evidence_v1','frequency_policy_version','performance_frequency_v2','support_policy_version','support_v2','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'goal_reviews',case when p_scope='running' then '[]'::jsonb else public.performance_goal_reviews_v1(p_goal_id,p_week_start) end,'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

create or replace function public.get_preparation_training_setup(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare setup jsonb; a public.adaptive_program_states%rowtype; scope text; active_program jsonb; latest jsonb; started_on date; path jsonb;
begin
 setup:=public.get_preparation_training_setup_base(p_goal_id);
 -- Una primera práctica pendiente o un origen corregido no son capacidad acreditada.
 setup:=jsonb_set(setup,'{references}',coalesce((select jsonb_agg(r) from jsonb_array_elements(setup->'references') r
   where r->'reference'->>'reference_kind' is distinct from 'guided_pending'
    and (not (r->'reference') ? 'automatic_support' or public.performance_support_source_valid_v2(r->'reference'))),'[]'));
 select * into a from public.adaptive_program_states where preparation_goal_id=p_goal_id;
 scope:=coalesce(a.requested_scope,a.training_scope,'full');
 select jsonb_build_object('goal_id',g.id,'name',p.name) into active_program
 from public.adaptive_program_states current_state join public.preparation_goals g on g.id=current_state.preparation_goal_id
 join public.preparation_programs p on p.id=g.program_id
 where current_state.user_id=auth.uid() and current_state.auto_advance and g.status='active';
 setup:=setup||jsonb_build_object('available_running',setup->'has_running',
  'available_performance',jsonb_array_length(setup->'objectives')>0 or jsonb_array_length(setup->'references')>0,
  'training_scope',scope,'active_program',active_program,
  'program_name',(select p.name from public.preparation_goals g join public.preparation_programs p on p.id=g.program_id where g.id=p_goal_id),
  'has_running',(setup->>'has_running')::boolean and scope<>'performance');
 if scope='running' then setup:=setup||jsonb_build_object('objectives','[]'::jsonb,'references','[]'::jsonb); end if;
 if a.status='paused' then setup:=setup||jsonb_build_object('pending_sessions','[]'::jsonb,'update_options','{}'::jsonb); end if;
 select decision into latest from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null order by week_start desc limit 1;
 select min(week_start) into started_on from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;
 path:=latest->'program_path';
 if path is null and latest is not null and scope<>'running' then
   path:=public.performance_program_path_v3(started_on,(setup->>'target_date')::date,(latest->>'week_start')::date,latest->'proposals')
     ||jsonb_build_object('note','Esta semana conserva su pauta anterior. Las fechas orientativas no recalculan sesiones; la nueva estrategia se aplicará en la siguiente adaptación.');
 end if;
 setup:=setup||jsonb_build_object('program_path',coalesce(path,'{}'::jsonb),'calibration_options',case when scope='running' then '[]'::jsonb else public.performance_calibration_options_v3(p_goal_id) end);
 return setup;
end $$;

create or replace function public.performance_calibration_options_v3(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then
   raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select coalesce(jsonb_agg(x.item),'[]') into result from (
  select distinct jsonb_build_object('objective_key',r.objective_key,'goal_code',r.target_profile_code,
   'goal_version',r.target_profile_version,'measurement',r.target_measurement,'test_id',r.test_id,
   'program_objective_key',r.reference->>'program_objective_key','work_code',rel.work_code,
   'name',ep.definition->>'name','optional',true,
   'reason','Opción de apoyo. Registra una práctica real de esta variante; no se deduce de la marca de la prueba.') item
  from public.performance_training_references r
  join public.performance_exercise_relations rel on rel.goal_code=r.target_profile_code
    and (rel.role='support' or (rel.goal_code='front_plank_forearms' and rel.work_code='front_plank_high')) and rel.policy_version='performance_v1'
  join public.exercise_training_profiles ep on ep.code=rel.work_code
  join public.performance_training_contexts ctx on ctx.user_id=r.user_id
  where r.user_id=auth.uid() and r.preparation_goal_id=p_goal_id and r.active
   and ctx.capacity_confirmed and not ctx.reports_pain and ctx.observed_at>=now()-interval '30 days'
   and (select target_date from public.preparation_goals where id=p_goal_id)>current_date+28
   and not exists(select 1 from public.exercise_training_profiles newer where newer.code=ep.code and newer.definition_version>ep.definition_version)
   and not exists(select 1 from jsonb_array_elements_text(ep.definition->'required_equipment') eq where not eq=any(ctx.equipment))
   and exists(select 1 from public.exercises ex where ex.training_profile_code=ep.code and ex.training_profile_version=ep.definition_version and ex.is_public)
   and not exists(select 1 from public.performance_training_references known where known.preparation_goal_id=p_goal_id
    and known.active and known.objective_key=r.objective_key and known.reference->'task'->>'exercise_code'=rel.work_code)
  union
  select distinct jsonb_build_object('objective_key',r.objective_key,'goal_code',r.target_profile_code,
   'goal_version',r.target_profile_version,'measurement',r.target_measurement,'test_id',r.test_id,
   'program_objective_key',r.reference->>'program_objective_key','work_code',r.target_profile_code,
   'preferred_measurement','REPS_IN_TIME','name','Flexiones · práctica cronometrada','optional',true,
   'reason','Si tienes un resultado reciente con el tiempo de la prueba, regístralo. Permite pautar fragmentos de ritmo; no exige repetir un máximo ni convierte tu serie libre en una marca temporal.') item
  from public.performance_training_references r join public.performance_training_contexts ctx on ctx.user_id=r.user_id
  where r.user_id=auth.uid() and r.preparation_goal_id=p_goal_id and r.active
   and r.target_profile_code='push_up_standard' and r.target_measurement='REPS_IN_TIME'
   and ctx.capacity_confirmed and not ctx.reports_pain and ctx.observed_at>=now()-interval '30 days'
   and not exists(select 1 from public.performance_training_references known where known.preparation_goal_id=p_goal_id and known.active
    and known.objective_key=r.objective_key and known.reference->'task'->>'measurement'='REPS_IN_TIME')
 ) x;
 return result;
end $$;

revoke all on function public.performance_support_candidates_v2(uuid,date,jsonb) from public,anon,authenticated;

commit;
