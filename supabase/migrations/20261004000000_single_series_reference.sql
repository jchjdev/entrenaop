begin;
create or replace function public.save_performance_reference(p_goal_id uuid,p_reference jsonb,p_test_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare g public.preparation_goals%rowtype; target public.exercise_training_profiles%rowtype;
  work public.exercise_training_profiles%rowtype; task jsonb:=p_reference->'task';
  goal_code text:=p_reference->>'goal_code'; goal_mode text:=p_reference->>'goal_measurement';
  role text; key text; new_reference_id uuid:=gen_random_uuid(); n numeric; r jsonb; x jsonb;
  observed date; min_reps int; max_reps int; legacy public.performance_legacy_objectives%rowtype;
begin
  select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active' for update;
  if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
  select * into target from public.exercise_training_profiles where code=goal_code and definition_version=(p_reference->>'goal_version')::int;
  if not found or not exists(select 1 from jsonb_array_elements(target.definition->'measurement_options') opt where opt->>'mode'=goal_mode) then
    raise exception 'Objetivo deportivo no compatible con el catálogo.' using errcode='22023'; end if;
  if p_test_id is not null and not exists(select 1 from public.program_test_training_bindings b
    where b.test_id=p_test_id and b.program_id=g.program_id and b.profile_code=goal_code
      and b.profile_version=target.definition_version and b.measurement_mode=goal_mode) then
    raise exception 'La prueba no corresponde a este objetivo.' using errcode='22023'; end if;
  key:=coalesce(p_test_id::text,goal_code||':'||goal_mode);
  if p_reference->>'program_objective_key' is not null then
    select * into legacy from public.performance_legacy_objectives o where o.program_id=g.program_id
      and o.objective_key=p_reference->>'program_objective_key';
    if not found or p_test_id is not null or legacy.profile_code<>goal_code
      or legacy.profile_version<>target.definition_version or legacy.measurement<>goal_mode then
      raise exception 'La prueba no corresponde al programa.' using errcode='22023'; end if;
    key:=legacy.objective_key;
  end if;
  task:=task||jsonb_build_object('schema_version',1,'policy_version','performance_v1');
  if task is null or not public.valid_performance_prescription(task) then raise exception 'Tarea de trabajo incompleta.' using errcode='22023'; end if;
  select * into work from public.exercise_training_profiles where code=task->>'exercise_code'
    and definition_version=(task->>'exercise_version')::int;
  if not found or not exists(select 1 from jsonb_array_elements(work.definition->'measurement_options') opt
    where opt->>'mode'=task->>'measurement' and opt->'load_modes' ? (task->>'load_mode'))
    or not exists(select 1 from public.exercises where training_profile_code=work.code
      and training_profile_version=work.definition_version and is_public) then
    raise exception 'Variante, medición o carga no disponibles.' using errcode='22023'; end if;
  if goal_code=work.code then role:='specific'; else
    select q.role into role from public.performance_exercise_relations q
      where q.policy_version='performance_v1' and q.goal_code=goal_code and q.work_code=work.code;
    if role is null then raise exception 'No hay una relación deportiva revisada para esta variante.' using errcode='22023'; end if;
  end if;
  if role='specific' and goal_mode<>task->>'measurement'
    and not (goal_mode='MAX_LOAD' and task->>'measurement'='LOAD_REPS')
    and not (goal_mode='REPS_IN_TIME' and task->>'measurement'='REPS') then
    raise exception 'La referencia necesita la medición de trabajo pertinente.' using errcode='22023'; end if;
  if goal_mode='REPS_IN_TIME' and task->>'measurement'='REPS' then role:='support'; end if;
  if legacy.objective_key is not null and role='specific' then
    if task->>'protocol_key' is distinct from legacy.protocol_key
      or (task->>'protocol_version')::int is distinct from legacy.protocol_version
      or (legacy.measurement='REPS_IN_TIME' and task->'fixed_duration_seconds' is distinct from legacy.parameters->'fixed_duration_seconds') then
      raise exception 'Conserva el protocolo y las condiciones de la prueba.' using errcode='22023'; end if;
  end if;
  observed:=(p_reference->>'observed_on')::date;
  if observed is null or observed>current_date or observed<current_date-14
    or p_reference->>'current_capacity_confirmed' is distinct from 'true' then
    raise exception 'Confirma una referencia real de los últimos catorce días.' using errcode='22023'; end if;
  if jsonb_typeof(p_reference->'targets') is distinct from 'array'
    or jsonb_array_length(p_reference->'targets') not between 1 and 6 then
    raise exception 'Registra entre una y seis series reales de referencia.' using errcode='22023'; end if;
  for x in select value from jsonb_array_elements(p_reference->'targets') loop
    if jsonb_typeof(x)<>'number' or x::text::numeric not between 0.01 and 3600
      or (task->>'measurement' in ('REPS','LOAD_REPS','REPS_IN_TIME','PASS_FAIL') and x::text::numeric<>trunc(x::text::numeric)) then
      raise exception 'Una serie de referencia tiene una medición no válida.' using errcode='22023'; end if;
  end loop;
  -- Una sola serie no acredita ningún descanso entre series.
  if (jsonb_array_length(p_reference->'targets')>1 and
      ((p_reference->>'rest_seconds') is null or (p_reference->>'rest_seconds')::int not between 30 and 600))
    or (p_reference->>'frequency') is null or (p_reference->>'frequency')::int not between 1 and 2 then
    raise exception 'Confirma descansos y frecuencia actual, de una o dos exposiciones.' using errcode='22023'; end if;
  n:=(p_reference->>'reported_rir')::numeric;
  if task->>'measurement' in ('REPS','LOAD_REPS','REPS_IN_TIME') and task->>'intent'='work'
    and (n is null or n not between 2 and 4) then
    raise exception 'Calibra trabajo submáximo conservando entre dos y cuatro repeticiones.' using errcode='22023'; end if;
  min_reps:=coalesce((p_reference->>'rep_min')::int,4); max_reps:=coalesce((p_reference->>'rep_max')::int,6);
  if min_reps not between 3 and 10 or max_reps not between min_reps+1 and 12 then
    raise exception 'Horquilla de trabajo no válida.' using errcode='22023'; end if;
  if task->>'measurement'='LOAD_REPS' and exists(select 1 from jsonb_array_elements_text(p_reference->'targets') val
    where val::numeric not between min_reps and max_reps) and not work.definition->'movement_modes' ? 'plyometric'
    and work.code<>'kettlebell_swing' then raise exception 'Las series deben estar dentro de la horquilla calibrada.' using errcode='22023'; end if;
  if p_reference->>'load_step_kg' is not null and (p_reference->>'load_step_kg')::numeric<=0 then
    raise exception 'El escalón disponible de carga debe ser positivo.' using errcode='22023'; end if;
  task:=jsonb_set(task,'{target_value}',p_reference->'targets'->0);
  r:=jsonb_build_object('id',new_reference_id,'task',task,'targets',p_reference->'targets',
    'observed_on',observed,'current_capacity_confirmed',true,'reported_rir',n,
    'rest_seconds',case when jsonb_array_length(p_reference->'targets')=1 then 0 else (p_reference->>'rest_seconds')::int end,'frequency',(p_reference->>'frequency')::int,
    'rep_min',min_reps,'rep_max',max_reps,'load_step_kg',(p_reference->>'load_step_kg')::numeric,
    'program_objective_key',legacy.objective_key,'role',role,'goal_code',goal_code,'goal_measurement',goal_mode,'objective_key',key);
  update public.performance_training_references set active=false where preparation_goal_id=p_goal_id
    and objective_key=key and reference->'task'->>'exercise_code'=work.code and active;
  insert into public.performance_training_references(id,user_id,preparation_goal_id,test_id,objective_key,
    target_profile_code,target_profile_version,target_measurement,reference)
    values(new_reference_id,auth.uid(),p_goal_id,p_test_id,key,goal_code,target.definition_version,goal_mode,r);
  -- Confirmar material de esta referencia no renueva la declaración global de salud.
  if p_reference->>'equipment_confirmed'='true' then
    update public.performance_training_contexts set equipment=array(select distinct e from
      unnest(equipment||array(select jsonb_array_elements_text(work.definition->'required_equipment'))) e)
      where user_id=auth.uid();
  end if;
  return new_reference_id;
end $$;
commit;
