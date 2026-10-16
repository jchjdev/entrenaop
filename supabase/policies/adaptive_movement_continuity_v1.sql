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
