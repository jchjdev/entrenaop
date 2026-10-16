begin;

-- Entrada de apoyos revisados. Las cifras son una familiarización operativa,
-- no marcas inferidas ni una dosis óptima acreditada para todos los usuarios.
create function public.performance_support_recipes_v1() returns jsonb
language sql immutable set search_path='' as $$
 select '[
  {"goal":"push_up_standard","work":"bench_press_barbell","measurement":"LOAD_REPS","load_mode":"external_load","rank":10,
   "instructions":"Prepara un banco estable y los seguros o ayuda necesarios. Si no conoces el ejercicio o no puedes prepararlo con seguridad, omite este apoyo. Empieza con una carga muy ligera que puedas controlar: no hay kilos obligatorios. Haz hasta ocho repeticiones y termina antes si crees que solo podrías hacer tres más con buena técnica. No busques un máximo. Registra las repeticiones, los kilos totales realmente utilizados y el margen que te quedó."},
  {"goal":"push_up_standard","work":"push_up_weighted","measurement":"LOAD_REPS","load_mode":"bodyweight_plus_external","rank":20,
   "instructions":"Utiliza un lastre ligero, estable y seguro. Si no puedes mantener la técnica de tu flexión habitual con lastre, omite este apoyo. Haz hasta ocho repeticiones y termina antes si crees que solo podrías hacer tres más con buena técnica. No busques un máximo. Registra repeticiones, kilos de lastre, peso corporal y margen real; no sumes el peso corporal a los kilos de lastre."},
  {"goal":"front_plank_forearms","work":"dead_bug","measurement":"REPS","load_mode":"bodyweight","rank":10,
   "instructions":"Túmbate boca arriba, con caderas y rodillas flexionadas. Extiende lentamente un brazo y la pierna contraria sin arquear la zona lumbar y vuelve. Cada extensión y vuelta de un lado cuenta una repetición; alterna lados, hasta ocho en total. Acorta el recorrido si lo necesitas, manteniéndolo igual durante la serie. Para antes de perder el control o de quedarte sin tres repeticiones de margen. Registra lo realizado; no es un máximo."},
  {"goal":"shuttle_5_10_5","work":"split_squat","measurement":"REPS","load_mode":"bodyweight","rank":10,
   "instructions":"Con los pies separados en posición de zancada y un apoyo estable cerca, baja y sube con control sin desplazar los pies. Haz hasta cuatro repeticiones por lado, ocho en total. Usa un recorrido cómodo y repetible; detente antes de perder estabilidad o de quedarte sin tres repeticiones de margen. No añadas peso en esta primera práctica. Registra el total realizado con ambos lados."}
 ]'::jsonb
$$;

-- Lee únicamente trabajo del propietario, reciente y de la misma variante.
-- Una marca máxima, una serie incompleta o un dato de otro ejercicio no sirven.
create function public.performance_support_observed_v1(work_code text,version int,mode text,load_mode text,wk date)
returns jsonb language sql stable security definer set search_path='' as $$
 with observations as (
  select es.performance_prescription task,es.performance_result result,
   public.workout_performed_on_v1(e) observed_on,e.id source_id,es.id set_id,'execution' source,0 priority
  from public.workout_executions e join public.workout_execution_sets es on es.execution_id=e.id
  where e.user_id=auth.uid() and e.status in ('completed','abandoned') and es.status='completed'
   and public.workout_block_outcome_v1(e.id,es.block_order)->>'status'='completed'
   and public.workout_performed_on_v1(e) between greatest(wk,current_date)-14 and least(wk+6,current_date)
  union all
  select r.reference->'task',jsonb_build_object('value',r.reference->'targets'->0,
   'rir',r.reference->'reported_rir','load_kg',r.reference->'task'->'external_load_kg',
   'body_mass_kg',r.reference->'task'->'body_mass_kg','technique_valid',true,'conditions_confirmed',true,
   'tolerated',true,'stop_reason','none'),(r.reference->>'observed_on')::date,r.id,null,'reference',1
  from public.performance_training_references r
  where r.user_id=auth.uid() and r.active and not r.reference ? 'automatic_support' and r.reference->>'current_capacity_confirmed'='true'
   and r.reference->>'reference_kind' in ('performed_set','repeated_work')
   and (r.reference->>'observed_on')::date between greatest(wk,current_date)-14 and least(wk+6,current_date)
 ), matching as (
  select * from observations o where task->>'exercise_code'=work_code
   and (task->>'exercise_version')::int=version and task->>'measurement'=mode
   and task->>'load_mode'=load_mode and task->>'intent'='work'
 ), eligible as (
  select * from matching o where not exists(select 1 from matching newer where newer.observed_on>o.observed_on
    and (newer.result->>'stop_reason' in ('difficulty','discomfort') or newer.result->>'technique_valid'='false'
     or newer.result->>'tolerated'='false' or (newer.result->>'rir')::numeric<2))
   and result->>'technique_valid'='true' and result->>'conditions_confirmed'='true'
   and result->>'tolerated'='true' and result->>'stop_reason'='none'
   and (result->>'value')::numeric between 4 and 100 and (result->>'value')::numeric=trunc((result->>'value')::numeric)
   and (result->>'rir')::numeric between 2 and 10
   and (load_mode='bodyweight' or (result->>'load_kg')::numeric>0)
   and (load_mode<>'bodyweight_plus_external' or (result->>'body_mass_kg')::numeric>0)
 ) select jsonb_build_object('task',task,'result',result,'observed_on',observed_on,
   'source',source,'source_id',source_id,'set_id',set_id)
 from eligible order by observed_on desc,priority,source_id,set_id limit 1
$$;

-- Una referencia derivada conserva su origen. Corregir ese origen obliga a
-- reconsiderarla; no usamos una copia derivada como prueba de sí misma.
create function public.performance_support_source_valid_v1(p_reference jsonb) returns boolean
language sql stable security definer set search_path='' as $$
 select case p_reference->'automatic_support'->'observation'->>'source'
 when 'execution' then exists(select 1 from public.workout_execution_sets es
  join public.workout_executions e on e.id=es.execution_id where e.user_id=auth.uid()
   and es.id=(p_reference->'automatic_support'->'observation'->>'set_id')::uuid
   and es.status='completed' and es.performance_result->'value'=p_reference->'targets'->0
   and es.performance_result->'rir'=p_reference->'reported_rir'
   and es.performance_result->>'technique_valid'='true' and es.performance_result->>'conditions_confirmed'='true'
   and es.performance_result->>'tolerated'='true' and es.performance_result->>'stop_reason'='none'
   and (p_reference->'task'->>'load_mode'='bodyweight' or es.performance_result->'load_kg'=p_reference->'task'->'external_load_kg')
   and (p_reference->'task'->>'load_mode'<>'bodyweight_plus_external' or es.performance_result->'body_mass_kg'=p_reference->'task'->'body_mass_kg'))
 when 'reference' then exists(select 1 from public.performance_training_references r where r.user_id=auth.uid()
   and r.id=(p_reference->'automatic_support'->'observation'->>'source_id')::uuid
   and r.reference->'targets'->0=p_reference->'targets'->0 and r.reference->'reported_rir'=p_reference->'reported_rir'
   and ((r.reference->'task')-array['instructions','policy_version','target_value'])=
       ((p_reference->'task')-array['instructions','policy_version','target_value']))
 else false end
$$;

-- La propuesta contiene la futura referencia; calcular no escribe en tablas.
-- Solo la publicación de un bloque realmente colocado la persiste.
create function public.performance_support_candidates_v1(goal uuid,wk date,proposals jsonb)
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
  for recipe in select value from jsonb_array_elements(public.performance_support_recipes_v1())
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
   observed:=public.performance_support_observed_v1(recipe->>'work',(profile->>'definition_version')::int,
     recipe->>'measurement',recipe->>'load_mode',wk);
   -- Una omisión o una práctica no utilizable no se convierte en éxito ni se
   -- vuelve a pedir cada semana. Se deja una ventana antes de reconsiderarla.
   if observed is null and exists(select 1 from public.performance_week_work pw
      join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
      left join public.workout_executions e on e.id=sw.execution_id
      join public.performance_training_references trial_ref on trial_ref.id=pw.reference_id
      where sw.user_id=auth.uid() and sw.preparation_goal_id=goal and trial_ref.objective_key=parent.objective_key
       and pw.dose->'task'->>'policy_version'='support_familiarization_v1'
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
    'policy_version','support_familiarization_v1','target_value',8,'effort_mode','rir','target_rir',3,
    'stimulus_code','SUPPORT-F01','instructions',recipe->>'instructions');
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
     'reported_rir',observed->'result'->'rir','rest_seconds',0,'rep_min',4,'rep_max',8,
     'automatic_support',reference->'automatic_support'||jsonb_build_object('observation',observed-'task'-'result'));
   proposal:=public.performance_task_v5(reference,profile,'[]',wk,target,'{}',wk);
   if proposal->>'status'<>'ready' then continue; end if;
   proposal:=proposal||jsonb_build_object('reason',proposal->>'reason'||' Reutilizamos una práctica reciente de esta misma variante.',
     'support_entry','observed');
  else
   dose:=jsonb_build_object('task',task,'targets','[8]'::jsonb,'rest_seconds',0,
     'model',case when recipe->>'measurement'='LOAD_REPS' then 'load_repetitions' else 'repetitions' end,'stimulus_code','SUPPORT-F01');
   proposal:=jsonb_build_object('status','ready','frequency',1,'phase',main->>'phase','outcome','familiarization',
     'model',dose->>'model','dose',dose,'comparison_dose',dose,'exposure_doses',jsonb_build_array(dose),
     'comparison_exposure_doses',jsonb_build_array(dose),'work_seconds',360,'work_minutes',6,'recovery_days',2,
     'support_entry','guided','reason','Primera práctica opcional para conocer este apoyo. Sin kilos ni resultados inventados; puedes omitirla.',
     'selection_reason','Un único apoyo pertinente, con seis minutos reservados para prepararlo y registrar una práctica submáxima.');
  end if;
  proposal:=proposal||jsonb_build_object('reference_id',rid,'objective_key',parent.objective_key,'role','support',
    'exercise_code',recipe->>'work','name',case when observed is null then 'Primera práctica · ' else '' end||(profile->>'name'),
    'body_regions',profile->'body_regions','movement_patterns',profile->'movement_patterns',
    'automatic_reference',jsonb_build_object('reference',reference,'parent_reference_id',parent.id));
  -- Retirar únicamente candidatos no utilizables de ESTA variante/objetivo.
  select coalesce(jsonb_agg(p),'[]') into result from jsonb_array_elements(result) p
    where not(p->>'objective_key'=parent.objective_key and p->>'exercise_code'=recipe->>'work' and p->>'status'<>'ready');
  result:=result||jsonb_build_array(proposal);
 end loop;
 return result;
end $$;

create function public.persist_automatic_support_v1(goal uuid,work jsonb) returns void
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
 if not found or not exists(select 1 from jsonb_array_elements(public.performance_support_recipes_v1()) recipe
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

-- Excepción acotada para una carga todavía no conocida. Las prescripciones
-- ordinarias siguen exigiendo kilos y masa; el resultado real no se rellena.
create function public.is_support_familiarization_v1(p jsonb) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(p->>'policy_version'='support_familiarization_v1' and p->>'intent'='work'
  and p->>'protocol_key'='support_work_v1:'||(p->>'exercise_code') and p->>'protocol_version'='1'
  and p->>'setup_key'='standard:support_v1:'||(p->>'exercise_code')
  and p->>'stimulus_code'='SUPPORT-F01' and p->>'target_value'='8'
  and p->>'effort_mode'='rir' and p->>'target_rir'='3'
  and exists(select 1 from jsonb_array_elements(public.performance_support_recipes_v1()) recipe
   where recipe->>'work'=p->>'exercise_code' and recipe->>'measurement'=p->>'measurement'
    and recipe->>'load_mode'=p->>'load_mode'),false)
$$;

revoke all on function public.performance_support_recipes_v1(),
 public.performance_support_observed_v1(text,int,text,text,date),public.performance_support_candidates_v1(uuid,date,jsonb),
 public.persist_automatic_support_v1(uuid,jsonb),public.performance_support_source_valid_v1(jsonb) from public,anon,authenticated;
-- El CHECK existente se ejecuta también al editar plantillas propias.
revoke all on function public.is_support_familiarization_v1(jsonb) from public,anon;
grant execute on function public.is_support_familiarization_v1(jsonb) to authenticated;
grant execute on function public.performance_support_recipes_v1() to authenticated;


create or replace function public.valid_performance_prescription(p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; m text;
begin
  if p is null then return true; end if;
  if jsonb_typeof(p) <> 'object' or not p ?& array[
    'schema_version','exercise_code','exercise_version','protocol_key',
    'protocol_version','setup_key','measurement','load_mode','policy_version',
    'target_value','intent'] then return false; end if;
  if exists(select 1 from jsonb_object_keys(p) x where x <> all(array[
    'schema_version','exercise_code','exercise_version','protocol_key',
    'protocol_version','setup_key','measurement','load_mode','policy_version',
    'target_value','intent','fixed_duration_seconds','fixed_distance_meters',
    'external_load_kg','body_mass_kg','target_rir','instructions',
    'records_stimulus_responses','records_penalty_seconds','effort_mode','target_rpe','stimulus_code'])) then return false; end if;
  if p->>'schema_version' <> '1' then return false; end if;
  foreach k in array array['schema_version','measurement','load_mode','intent','target_value'] loop
    if p->>k is null then return false; end if;
  end loop;
  foreach k in array array['exercise_code','protocol_key','setup_key','policy_version'] loop
    if jsonb_typeof(p->k) <> 'string' or length(btrim(p->>k)) not between 1 and 500 then return false; end if;
  end loop;
  foreach k in array array['exercise_version','protocol_version'] loop
    if jsonb_typeof(p->k) <> 'number' or (p->>k)::numeric < 1
      or (p->>k)::numeric <> trunc((p->>k)::numeric) then return false; end if;
  end loop;
  foreach k in array array['target_value','fixed_duration_seconds','fixed_distance_meters',
      'external_load_kg','body_mass_kg','target_rir'] loop
    if p->>k is not null and (jsonb_typeof(p->k) <> 'number'
        or (p->>k)::numeric < 0 or (p->>k)::numeric > 1000000) then return false; end if;
  end loop;
  if coalesce((p->>'target_value')::numeric,0) <= 0 then return false; end if;
  m := p->>'measurement';
  if m <> all(array['REPS','LOAD_REPS','DURATION','REPS_IN_TIME','MAX_LOAD',
    'TIME_FOR_DISTANCE','TIME_FOR_COURSE','DISTANCE','HEIGHT','PASS_FAIL','REACTIVE_METRICS']) then return false; end if;
  if p->>'load_mode' <> all(array['bodyweight','external_load','bodyweight_plus_external','assisted'])
    or p->>'intent' <> all(array['work','control','practice']) then return false; end if;
  if m in ('REPS','LOAD_REPS','REPS_IN_TIME','PASS_FAIL')
      and (p->>'target_value')::numeric <> trunc((p->>'target_value')::numeric) then return false; end if;
  if m = 'PASS_FAIL' and (p->>'target_value')::numeric <> 1 then return false; end if;
  if m = 'REPS_IN_TIME' and coalesce((p->>'fixed_duration_seconds')::numeric,0) <= 0 then return false; end if;
  if m = 'TIME_FOR_DISTANCE' and coalesce((p->>'fixed_distance_meters')::numeric,0) <= 0 then return false; end if;
  if p->>'load_mode' in ('external_load','bodyweight_plus_external')
    and ((p->>'external_load_kg' is null and not public.is_support_familiarization_v1(p))
      or (p->>'external_load_kg')::numeric<=0) then return false; end if;
  if p->>'load_mode' = 'bodyweight_plus_external'
    and ((p->>'body_mass_kg' is null and not public.is_support_familiarization_v1(p))
      or (p->>'body_mass_kg')::numeric<=0) then return false; end if;
  if p->>'target_rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (p->>'target_rir')::numeric > 10) then return false; end if;
  foreach k in array array['records_stimulus_responses','records_penalty_seconds'] loop
    if p ? k and jsonb_typeof(p->k)<>'boolean' then return false; end if;
  end loop;
  if p->>'records_stimulus_responses'='true' and m not in ('TIME_FOR_COURSE','PASS_FAIL') then return false; end if;
  if p->>'records_penalty_seconds'='true' and m<>'TIME_FOR_COURSE' then return false; end if;
  if p ? 'effort_mode' and coalesce(p->>'effort_mode','') not in ('none','rir','rpe') then return false; end if;
  if p->>'effort_mode'='rir' and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME') or p->>'intent'<>'work') then return false; end if;
  if p->>'target_rpe' is not null and (jsonb_typeof(p->'target_rpe')<>'number'
    or (p->>'target_rpe')::numeric not between 1 and 10 or p->>'effort_mode' is distinct from 'rpe') then return false; end if;
  if p ? 'stimulus_code' and (jsonb_typeof(p->'stimulus_code')<>'string' or length(p->>'stimulus_code') not between 1 and 80) then return false; end if;
  return true;
exception when others then return false;
end $$;

create or replace function public.performance_work_seconds_v2(dose jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare seconds numeric; m text:=dose->'task'->>'measurement';
begin
 if public.is_support_familiarization_v1(dose->'task') then return 360; end if;
 select sum(case
  when m='DURATION' then value::numeric
  when m='REPS_IN_TIME' then (dose->'task'->>'fixed_duration_seconds')::numeric
  when m in ('TIME_FOR_DISTANCE','TIME_FOR_COURSE') then greatest(30,value::numeric)
  when m in ('REPS','LOAD_REPS') then value::numeric*5
  when m='DISTANCE' and dose->>'model'='carry' then value::numeric*2
  else 30 end) into seconds from jsonb_array_elements_text(dose->'targets');
 return ceil(seconds+greatest(0,jsonb_array_length(dose->'targets')-1)*(dose->>'rest_seconds')::int+60)::int;
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
       or (main.p->>'exercise_code'='front_plank_forearms' and candidate.p->>'exercise_code'='dead_bug'))
     and coalesce(main.p->>'outcome','initial')<>'reduce')
   and jsonb_array_length(candidate.p->'dose'->'targets')<=2)
  union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) select coalesce(jsonb_agg(p order by coalesce((p->>'selection_rank')::int,0),p->>'reference_id'),'[]') from selected
$$;

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
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and coalesce(r.reference->>'reference_kind','')<>'guided_pending'
    and (not r.reference ? 'automatic_support' or public.performance_support_source_valid_v1(r.reference)) and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
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

 if p_scope<>'running' then proposals:=public.performance_support_candidates_v1(p_goal_id,p_week_start,proposals); end if;
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
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
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
   'policy_version','preparation_coordinator_v3','evidence_policy_version','adaptive_evidence_v1','frequency_policy_version','performance_frequency_v2','support_policy_version','support_v1','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

create or replace function public.materialize_preparation_week_scoped(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb,p_activation boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); plan jsonb; saved public.preparation_week_decisions%rowtype;
  d_id uuid; t_id uuid; b_id uuid; i_id uuid; sw_id uuid; ex_id uuid; s jsonb; warm_step jsonb; warm_idx int; w jsonb; v jsonb;
  run_session jsonb; run_schedule uuid; p jsonb; idx int; block_idx int; refs jsonb; goal_lock uuid; running_result jsonb;
begin
 if u is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
 -- Un único candado por deportista evita publicaciones simultáneas de dos
 -- preparaciones que consuman el mismo tiempo libre.
 perform 1 from public.profiles where id=u for update;
 select id into goal_lock from public.preparation_goals where id=p_goal_id and user_id=u and status='active' for update;
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into saved from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 if found then return saved.decision||jsonb_build_object('decision_id',saved.id,'already_published',true); end if;
 if not p_activation and exists(select 1 from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null)
   and current_date<p_week_start-1 and not public.preparation_can_advance(p_goal_id,p_week_start) then raise exception 'Cierra la semana anterior antes de adaptar y publicar.' using errcode='22023'; end if;
 if not p_activation and exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id and auto_advance)
  and exists(select 1 from public.preparation_week_decisions d where d.preparation_goal_id=p_goal_id and d.week_start<p_week_start and d.superseded_at is null
    and not public.preparation_week_closed(p_goal_id,d.week_start)) then
  raise exception 'Resuelve las sesiones pendientes antes de continuar el programa.' using errcode='22023'; end if;
 plan:=public.calculate_preparation_week(p_goal_id,p_week_start);
 if plan->>'status'<>'ready' then raise exception 'Resuelve los datos o conflictos pendientes antes de publicar.' using errcode='22023'; end if;
 if p_expected_proposal is null or plan is distinct from p_expected_proposal then
   raise exception 'Los datos o la agenda han cambiado. Revisa la propuesta actualizada.' using errcode='22023'; end if;
 insert into public.preparation_week_decisions(user_id,preparation_goal_id,week_start,policy_version,decision,input_snapshot)
 values(u,p_goal_id,p_week_start,plan->>'policy_version',plan,jsonb_build_object(
   'program',(select to_jsonb(a) from public.adaptive_program_states a where a.preparation_goal_id=p_goal_id),
   'target_date',(select target_date from public.preparation_goals where id=p_goal_id),
   'context',(select to_jsonb(c) from public.performance_training_contexts c where c.user_id=u),
   'references',(select jsonb_agg(to_jsonb(r)) from public.performance_training_references r where r.preparation_goal_id=p_goal_id and r.active)))
 returning id into d_id;
 if plan->'running' is not null and plan->'running'<>'null'::jsonb then
   running_result:=public.materialize_running_week_plan(p_goal_id,p_week_start,plan->'running');
   plan:=jsonb_set(plan,'{running}',running_result);
 end if;
 for s in select value from jsonb_array_elements(plan->'sessions') loop
   insert into public.workout_templates(name,description,origin,owner_user_id,visibility,status,estimated_duration_minutes,version)
   values('Fuerza y rendimiento','Semana coordinada. Calentamiento, práctica específica y registro real. Detén la práctica si aparecen molestias.',
     'algorithm',u,'private','published',(s->>'minutes')::int,1) returning id into t_id;
   insert into public.workout_blocks(template_id,order_index,name,format)
     values(t_id,0,'Calentamiento','warm_up') returning id into b_id;
   warm_idx:=0;
   for warm_step in select value from jsonb_array_elements(public.performance_warm_up_steps_v3(s)) loop
    insert into public.workout_items(block_id,exercise_id,order_index,notes)
     values(b_id,'21000000-0000-4000-8000-000000000001',warm_idx,warm_step->>'name'||E'\n'||(warm_step->>'instructions')) returning id into i_id;
    insert into public.workout_sets(item_id,order_index,target_duration_seconds,rest_after_seconds)
     values(i_id,0,(warm_step->>'seconds')::int,0);
    warm_idx:=warm_idx+1;
   end loop;
   block_idx:=1;
   insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,estimated_duration_minutes,
     preparation_goal_id,scheduled_date,source,status,order_index)
   values(u,t_id,'Fuerza y rendimiento',1,(s->>'minutes')::int,p_goal_id,(s->>'date')::date,'algorithm','planned',case when s->>'session_order'='performance_first' then 0 else 1 end) returning id into sw_id;
   if s->>'session_order'='performance_first' then
     update public.scheduled_workouts sw set order_index=1 from public.running_week_sessions rs
       where rs.scheduled_workout_id=sw.id and sw.preparation_goal_id=p_goal_id and sw.scheduled_date=(s->>'date')::date
         and sw.status='planned';
   end if;
   for w in select value from jsonb_array_elements(s->'work') loop
     perform public.persist_automatic_support_v1(p_goal_id,w);
     p:=w->'dose'->'task';
     select id into ex_id from public.exercises where training_profile_code=p->>'exercise_code'
       and training_profile_version=(p->>'exercise_version')::int and is_public order by id limit 1;
     if ex_id is null then raise exception 'Un ejercicio de la propuesta ya no está disponible.'; end if;
     insert into public.workout_blocks(template_id,order_index,name,format)
       values(t_id,block_idx,w->>'name','straight_sets') returning id into b_id;
     insert into public.workout_items(block_id,exercise_id,order_index,notes)
       values(b_id,ex_id,0,w->>'reason') returning id into i_id;
     idx:=0;
     for v in select value from jsonb_array_elements(w->'dose'->'targets') loop
       insert into public.workout_sets(item_id,order_index,performance_prescription,rest_after_seconds)
       values(i_id,idx,jsonb_set(p,'{target_value}',v),case when idx=jsonb_array_length(w->'dose'->'targets')-1
         then 60 else (w->'dose'->>'rest_seconds')::int end);
       idx:=idx+1;
     end loop;
     insert into public.performance_week_work(decision_id,scheduled_workout_id,reference_id,block_order,dose)
       select d_id,sw_id,r::uuid,block_idx,w->'dose' from jsonb_array_elements_text(coalesce(w->'covered_reference_ids',jsonb_build_array(w->>'reference_id'))) r;
     block_idx:=block_idx+1;
   end loop;
   insert into public.workout_blocks(template_id,order_index,name,format)
     values(t_id,block_idx,'Vuelta a la calma','cool_down') returning id into b_id;
   insert into public.workout_items(block_id,exercise_id,order_index)
     values(b_id,'21000000-0000-4000-8000-000000000002',0) returning id into i_id;
   insert into public.workout_sets(item_id,order_index,target_duration_seconds,rest_after_seconds)
     values(i_id,0,180,0);
   if s->>'combined'='true' then
     select value into run_session from jsonb_array_elements(plan->'running'->'sessions') r where r->>'date'=s->>'date';
     select rs.scheduled_workout_id into run_schedule from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
       where rs.decision_id=(running_result->>'decision_id')::uuid and sw.scheduled_date=(s->>'date')::date and sw.status='planned';
     perform public.materialize_shared_preparation_day_v3(sw_id,run_schedule,s,run_session);
   end if;
 end loop;
 update public.preparation_week_decisions set decision=plan where id=d_id;
 return plan||jsonb_build_object('decision_id',d_id,'already_published',false);
end $$;

create or replace function public.get_preparation_training_setup(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare setup jsonb; a public.adaptive_program_states%rowtype; scope text; active_program jsonb; latest jsonb; started_on date; path jsonb;
begin
 setup:=public.get_preparation_training_setup_base(p_goal_id);
 -- Una primera práctica pendiente o un origen corregido no son capacidad acreditada.
 setup:=jsonb_set(setup,'{references}',coalesce((select jsonb_agg(r) from jsonb_array_elements(setup->'references') r
   where r->'reference'->>'reference_kind' is distinct from 'guided_pending'
    and (not (r->'reference') ? 'automatic_support' or public.performance_support_source_valid_v1(r->'reference'))),'[]'));
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

commit;
