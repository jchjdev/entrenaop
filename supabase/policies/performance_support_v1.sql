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
