-- Referencias explícitas, estímulos y coordinación deportiva v2.
begin;

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
  if p->>'load_mode' in ('external_load','bodyweight_plus_external') and coalesce((p->>'external_load_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'load_mode' = 'bodyweight_plus_external' and coalesce((p->>'body_mass_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'target_rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (p->>'target_rir')::numeric > 10) then return false; end if;
  foreach k in array array['records_stimulus_responses','records_penalty_seconds'] loop
    if p ? k and jsonb_typeof(p->k)<>'boolean' then return false; end if;
  end loop;
  if p->>'records_stimulus_responses'='true' and m not in ('TIME_FOR_COURSE','PASS_FAIL') then return false; end if;
  if p->>'records_penalty_seconds'='true' and m<>'TIME_FOR_COURSE' then return false; end if;
  if p ? 'effort_mode' and coalesce(p->>'effort_mode','') not in ('none','rir','rpe') then return false; end if;
  if p->>'effort_mode'='rir' and (m not in ('REPS','LOAD_REPS') or p->>'intent'<>'work') then return false; end if;
  if p->>'target_rpe' is not null and (jsonb_typeof(p->'target_rpe')<>'number'
    or (p->>'target_rpe')::numeric not between 1 and 10 or p->>'effort_mode' is distinct from 'rpe') then return false; end if;
  if p ? 'stimulus_code' and (jsonb_typeof(p->'stimulus_code')<>'string' or length(p->>'stimulus_code') not between 1 and 80) then return false; end if;
  return true;
exception when others then return false;
end $$;

create or replace function public.valid_performance_result(r jsonb, p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; m text := p->>'measurement'; v numeric;
begin
  if r is null then return true; end if;
  if p is null or jsonb_typeof(r) <> 'object' then return false; end if;
  if exists(select 1 from jsonb_object_keys(r) x where x <> all(array[
    'value','technique_valid','conditions_confirmed','tolerated','rir','rpe','load_kg',
    'body_mass_kg','penalty_seconds','correct_responses','total_responses','stop_reason','succeeded','actual_duration_seconds','jump_height_meters','measurement_method'])) then return false; end if;
  foreach k in array array['value','rir','rpe','load_kg','body_mass_kg','penalty_seconds','correct_responses','total_responses','actual_duration_seconds','jump_height_meters'] loop
    if r->>k is not null and (jsonb_typeof(r->k) <> 'number'
      or (r->>k)::numeric < 0 or (r->>k)::numeric > 1000000) then return false; end if;
  end loop;
  foreach k in array array['technique_valid','conditions_confirmed','tolerated','succeeded'] loop
    if r->>k is not null and jsonb_typeof(r->k) <> 'boolean' then return false; end if;
  end loop;
  v := (r->>'value')::numeric;
  if m in ('REPS','LOAD_REPS','REPS_IN_TIME','PASS_FAIL') and v <> trunc(v) then return false; end if;
  if m = 'PASS_FAIL' and v is not null then return false; end if;
  if r->>'rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (r->>'rir')::numeric > 10) then return false; end if;
  if r->>'rpe' is not null and ((r->>'rpe')::numeric not between 1 and 10 or p->>'effort_mode' is distinct from 'rpe') then return false; end if;
  if r->>'body_mass_kg' is not null and (r->>'body_mass_kg')::numeric <= 0 then return false; end if;
  if r->>'penalty_seconds' is not null and m <> 'TIME_FOR_COURSE' then return false; end if;
  if r->>'correct_responses' is not null or r->>'total_responses' is not null then
    if m not in ('TIME_FOR_COURSE','PASS_FAIL') or r->>'correct_responses' is null or r->>'total_responses' is null then return false; end if;
    if (r->>'total_responses')::numeric < 1
      or (r->>'correct_responses')::numeric > (r->>'total_responses')::numeric
      or (r->>'correct_responses')::numeric <> trunc((r->>'correct_responses')::numeric)
      or (r->>'total_responses')::numeric <> trunc((r->>'total_responses')::numeric) then return false; end if;
  end if;
  if r->>'succeeded' is not null and m <> 'PASS_FAIL' then return false; end if;
  if r->>'actual_duration_seconds' is not null and m <> 'REPS_IN_TIME' then return false; end if;
  if r->>'jump_height_meters' is not null and m <> 'REACTIVE_METRICS' then return false; end if;
  if m = 'REACTIVE_METRICS' and (v is not null or r->>'jump_height_meters' is not null)
    and (jsonb_typeof(r->'measurement_method') is distinct from 'string'
      or length(btrim(coalesce(r->>'measurement_method',''))) not between 3 and 200) then return false; end if;
  return coalesce(r->>'stop_reason','unknown') in ('none','time','difficulty','discomfort','unknown');
exception when others then return false;
end $$;

create or replace function public.save_performance_reference(p_goal_id uuid,p_reference jsonb,p_test_id uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare g public.preparation_goals%rowtype; target public.exercise_training_profiles%rowtype;
  work public.exercise_training_profiles%rowtype; task jsonb:=p_reference->'task';
  goal_code text:=p_reference->>'goal_code'; goal_mode text:=p_reference->>'goal_measurement';
  role text; key text; new_reference_id uuid:=gen_random_uuid(); n numeric; r jsonb; x jsonb;
  kind text:=coalesce(p_reference->>'reference_kind','legacy_work'); effort numeric;
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
  if kind not in ('legacy_work','performed_set','repeated_work','capacity_test','official_test') then
    raise exception 'Indica qué dato estás registrando.' using errcode='22023'; end if;
  task:=task||jsonb_build_object('schema_version',1,'policy_version','reference_v2');
  -- Las marcas no tienen un RIR prescrito ni una dosis deportiva implícita.
  if kind in ('capacity_test','official_test') then task:=(task-'target_rir'-'target_rpe'-'effort_mode')||'{"intent":"control"}'::jsonb; end if;
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
  if kind in ('performed_set','capacity_test','official_test') and jsonb_array_length(p_reference->'targets')<>1 then
    raise exception 'Para este tipo registra una sola serie o marca. Usa trabajo repetido para varias series.' using errcode='22023'; end if;
  if kind='repeated_work' and jsonb_array_length(p_reference->'targets')<2 then
    raise exception 'El trabajo repetido necesita al menos dos series realmente realizadas.' using errcode='22023'; end if;
  if kind='official_test' and (role<>'specific' or task->>'measurement'<>goal_mode) then
    raise exception 'Una marca oficial requiere el gesto y protocolo de la prueba.' using errcode='22023'; end if;
  n:=case when kind in ('capacity_test','official_test') then null else (p_reference->>'reported_rir')::numeric end;
  effort:=(p_reference->>'reported_rpe')::numeric;
  if n is not null and (n not between 0 and 10 or task->>'measurement' not in ('REPS','LOAD_REPS','REPS_IN_TIME')) then
    raise exception 'Revisa el margen de repeticiones declarado.' using errcode='22023'; end if;
  if effort is not null and (effort not between 1 and 10 or task->>'measurement'<>'DURATION') then
    raise exception 'Revisa el esfuerzo declarado para esta sujeción.' using errcode='22023'; end if;
  if kind='legacy_work' and task->>'measurement' in ('REPS','LOAD_REPS','REPS_IN_TIME') and task->>'intent'='work'
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
    'observed_on',observed,'current_capacity_confirmed',true,'reported_rir',n,'reported_rpe',effort,'reference_kind',kind,
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

-- Perfiles y ejercicios reales: nunca sustituir un circuito por otro nombre.
do $$ declare p jsonb; begin
 for p in select value from jsonb_array_elements($profiles$[{"code": "cod_braking_10m", "name": "Aceleración suave y frenada en 10 m", "family": "cod_practice", "movement_patterns": ["change_of_direction"], "movement_modes": ["locomotor"], "body_regions": ["lower_body"], "laterality": "bilateral", "technical_level": "initial", "required_equipment": ["cones", "measuring_tape"], "optional_equipment": [], "primary_muscles": ["quadriceps", "gluteals"], "secondary_muscles": ["hamstrings", "trunk_stabilizers"], "measurement_options": [{"mode": "PASS_FAIL", "load_modes": ["bodyweight"]}], "progression_axes": ["technique", "specificity"], "notes": "Marca 10 metros y deja espacio libre para detenerte. Acelera a velocidad cómoda y frena progresivamente con pasos cortos, tronco estable y rodillas orientadas con los pies. Vuelve andando. Cada intento termina al quedar estable; no busques velocidad máxima."}, {"code": "cod_turn_90_5m", "name": "Cambio de dirección de 90 grados", "family": "cod_practice", "movement_patterns": ["change_of_direction"], "movement_modes": ["locomotor"], "body_regions": ["lower_body"], "laterality": "bilateral", "technical_level": "initial", "required_equipment": ["cones", "measuring_tape"], "optional_equipment": [], "primary_muscles": ["quadriceps", "gluteals"], "secondary_muscles": ["hamstrings", "trunk_stabilizers"], "measurement_options": [{"mode": "PASS_FAIL", "load_modes": ["bodyweight"]}], "progression_axes": ["technique", "specificity"], "notes": "Coloca tres conos formando una L con tramos de 5 metros. Acércate a velocidad cómoda, frena antes del cono y cambia de dirección manteniendo el equilibrio. Alterna derecha e izquierda entre intentos; empieza por el lado contrario en la siguiente sesión."}, {"code": "cod_turn_180_5m", "name": "Ida y vuelta técnica de 5 metros", "family": "cod_practice", "movement_patterns": ["change_of_direction"], "movement_modes": ["locomotor"], "body_regions": ["lower_body"], "laterality": "bilateral", "technical_level": "initial", "required_equipment": ["cones", "measuring_tape"], "optional_equipment": [], "primary_muscles": ["quadriceps", "gluteals"], "secondary_muscles": ["hamstrings", "trunk_stabilizers"], "measurement_options": [{"mode": "PASS_FAIL", "load_modes": ["bodyweight"]}], "progression_axes": ["technique", "specificity"], "notes": "Marca dos líneas separadas 5 metros. Avanza a velocidad cómoda, frena antes de la línea, gira y vuelve. Alterna el lado de giro entre intentos; no conviertas la práctica en una carrera al máximo."}, {"code": "slalom_ball_course_sector", "name": "Sector de eslalon y recogida de pelota", "family": "cod_practice", "movement_patterns": ["change_of_direction"], "movement_modes": ["locomotor"], "body_regions": ["lower_body"], "laterality": "bilateral", "technical_level": "initial", "required_equipment": ["cones", "measuring_tape", "tennis_ball"], "optional_equipment": [], "primary_muscles": ["quadriceps", "gluteals"], "secondary_muscles": ["hamstrings", "trunk_stabilizers"], "measurement_options": [{"mode": "PASS_FAIL", "load_modes": ["bodyweight"]}], "progression_axes": ["technique", "specificity"], "notes": "Usa los últimos tres conos del circuito de 16 m ya medido. Practica el eslalon, la recogida de pelota y los primeros pasos de retorno. Empieza a velocidad cómoda; termina estable y con control de la pelota. Registra si completaste el sector sin desplazar conos ni perderla."}]$profiles$::jsonb) loop
  insert into public.exercise_training_profiles(code,definition_version,catalog_version,definition) values(p->>'code',1,3,p);
  insert into public.exercises(name,description,muscle_groups,equipment,difficulty,exercise_type,is_public,created_by,origin,training_profile_code,training_profile_version)
  values(p->>'name',p->>'notes',array['cuádriceps','glúteos'],case when p->>'code'='slalom_ball_course_sector' then array['conos','cinta métrica','pelota de tenis'] else array['conos','cinta métrica'] end,
    'inicial','duración',true,null,'system',p->>'code',1);
 end loop;
end $$;

-- Fuente de la política v2 incorporada a la migración por tools/build_performance_v2_migration.py.
-- Los porcentajes son parámetros de entrada conservadora, no estimaciones de máximos.
create function public.performance_bank_v2() returns jsonb
language sql immutable set search_path='' as $$
select '{"version":"performance_v2","reference_days":14,"return_days":21,"comparable_exposures":2,
 "entry_fraction":0.50,"repeated_fraction":0.70,"reduction_fraction":0.85,
 "specific_days":28,"taper_days":7,"rep_increment":1,"duration_increment":2,
 "transition_seconds":60,"entry_sets":2,"maximum_sets":4,"rir_floor":3,"rpe_ceiling":7,
 "repeated_rir_fraction":0.85,"repeated_isometric_fraction":0.80,"timed_pace_fraction":0.80,
 "maximum_shared_upper_sets":4,"familiarization_review_weeks":4,
 "parameter_status":"operational_requires_outcome_monitoring",
 "blocks":[
  {"code":"REP-T01","name":"Práctica de repeticiones válidas","purpose":"technique","rest_seconds":60,"effort_mode":"none","sources":["FLEX-T01"]},
  {"code":"REP-E01","name":"Resistencia con margen","purpose":"endurance","rest_seconds":90,"effort_mode":"rir","sources":["FLEX-E01"]},
  {"code":"LOAD-S01","name":"Fuerza con carga calibrada","purpose":"strength","rest_seconds":180,"effort_mode":"rir","sources":["FLEX-S01","FLEX-S02","FLEX-S03","RUN-S01","RUN-S02"]},
  {"code":"TIME-SP01","name":"Ritmo en fragmentos cortos","purpose":"specific_pace","rest_seconds":90,"effort_mode":"none","sources":["FLEX-SP01"]},
  {"code":"TIME-SP02","name":"Ritmo en fragmentos medios","purpose":"specific_pace","rest_seconds":120,"effort_mode":"none","sources":["FLEX-SP02"]},
  {"code":"ISO-T01","name":"Control de la posición","purpose":"technique","rest_seconds":60,"effort_mode":"rpe","sources":["PLANK-T01"]},
  {"code":"ISO-E01","name":"Resistencia isométrica submáxima","purpose":"endurance","rest_seconds":75,"effort_mode":"rpe","sources":["PLANK-E01"]},
  {"code":"ISO-E02","name":"Continuidad isométrica","purpose":"specific_endurance","rest_seconds":120,"effort_mode":"rpe","sources":["PLANK-E02"]},
  {"code":"COD-T01","name":"Aproximación y frenada controladas","purpose":"technique","rest_seconds":75,"effort_mode":"none","sources":["COD-T01"]},
  {"code":"COD-SP01","name":"Sectores del recorrido","purpose":"technique","rest_seconds":90,"effort_mode":"none","sources":["COD-SP01"]},
  {"code":"COD-SP02","name":"Recorrido completo de calidad","purpose":"specific_quality","rest_seconds":180,"effort_mode":"none","sources":["COD-SP02"]},
  {"code":"POWER-P01","name":"Intentos de potencia de calidad","purpose":"power","rest_seconds":120,"effort_mode":"none","sources":["RUN-P02","RUN-P03"]},
  {"code":"ROPE-T01","name":"Trepa técnica conocida","purpose":"technique","rest_seconds":180,"effort_mode":"none","sources":[]},
  {"code":"CARRY-E01","name":"Transporte controlado","purpose":"endurance","rest_seconds":120,"effort_mode":"none","sources":[]},
  {"code":"SKILL-T01","name":"Práctica técnica conocida","purpose":"technique","rest_seconds":90,"effort_mode":"none","sources":[]}
 ]}'::jsonb
$$;

-- Tiempo de una instancia: las pausas son n-1 y la transición se cuenta una vez.
create function public.performance_work_seconds_v2(dose jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare seconds numeric; m text:=dose->'task'->>'measurement';
begin
 select sum(case
  when m='DURATION' then value::numeric
  when m='REPS_IN_TIME' then (dose->'task'->>'fixed_duration_seconds')::numeric
  when m in ('TIME_FOR_DISTANCE','TIME_FOR_COURSE') then greatest(30,value::numeric)
  when m in ('REPS','LOAD_REPS') then value::numeric*5
  when m='DISTANCE' and dose->>'model'='carry' then value::numeric*2
  else 30 end) into seconds from jsonb_array_elements_text(dose->'targets');
 return ceil(seconds+greatest(0,jsonb_array_length(dose->'targets')-1)*(dose->>'rest_seconds')::int+60)::int;
end $$;

create function public.performance_exposure_signal_v2(e jsonb,dose jsonb) returns text
language plpgsql immutable set search_path='' as $$
declare s jsonb; p jsonb; r jsonb; unknown boolean:=false; difficult boolean:=false;
 actual numeric; target numeric; idx int:=0; m text;
begin
 if e->>'abandonment_reason'='discomfort' or exists(select 1 from jsonb_array_elements(coalesce(e->'sets','[]')) entry
   where entry->'result'->>'tolerated'='false' or entry->'result'->>'stop_reason'='discomfort') then return 'pain'; end if;
 if e->'dose' is distinct from dose then return 'different_dose'; end if;
 if e->>'abandonment_reason'='lack_of_time' then return 'time'; end if;
 if e->>'abandonment_reason'='too_difficult' then return 'difficulty'; end if;
 if e->>'status' is distinct from 'completed' or jsonb_array_length(coalesce(e->'sets','[]'))<>jsonb_array_length(dose->'targets') then return 'unknown'; end if;
 for s in select value from jsonb_array_elements(e->'sets') loop
  p:=s->'prescription'; r:=s->'result'; m:=p->>'measurement';
  if s->>'status' is distinct from 'completed' or r is null then return 'unknown'; end if;
  if r->>'conditions_confirmed' is distinct from 'true' then return 'different_conditions'; end if;
  if p->>'load_mode'<>'bodyweight' and p->>'external_load_kg' is not null and r->'load_kg' is distinct from p->'external_load_kg' then return 'different_load'; end if;
  if p->>'load_mode'='bodyweight_plus_external' and r->'body_mass_kg' is distinct from p->'body_mass_kg' then return 'different_body_mass'; end if;
  if m='REPS_IN_TIME' and r->'actual_duration_seconds' is distinct from p->'fixed_duration_seconds' then return 'different_window'; end if;
  if r->>'stop_reason'='time' then return 'time'; end if;
  if r->>'technique_valid'='false' or r->>'stop_reason'='difficulty' then difficult:=true; end if;
  if r->>'technique_valid' is distinct from 'true' or r->>'tolerated' is distinct from 'true'
    or coalesce(r->>'stop_reason','unknown')='unknown' then unknown:=true; end if;
  actual:=(r->>'value')::numeric; target:=(dose->'targets'->>idx)::numeric;
  if m='PASS_FAIL' then
   if r->>'succeeded'='false' then difficult:=true; elsif r->>'succeeded' is null then unknown:=true; end if;
  elsif actual is null then unknown:=true;
  elsif dose->>'model' in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') and actual<target then difficult:=true;
  end if;
  if p->>'effort_mode'='rir' then
   if r->>'rir' is null then unknown:=true;
   elsif (r->>'rir')::numeric<coalesce((p->>'target_rir')::numeric,3) then difficult:=true; end if;
  elsif p->>'effort_mode'='rpe' then
   if r->>'rpe' is null then unknown:=true;
   elsif (r->>'rpe')::numeric>coalesce((p->>'target_rpe')::numeric,7) then difficult:=true; end if;
  end if;
  idx:=idx+1;
 end loop;
 return case when difficult then 'difficulty' when unknown then 'unknown' else 'tolerated' end;
end $$;

create function public.performance_task_v2(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
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

-- Coordinación regional conservadora: solo propuestas que realmente se publicarán pueden consumir progresión.
create function public.performance_coordinate_progression_v2(proposals jsonb,running jsonb,wk date) returns jsonb
language plpgsql immutable set search_path='' as $$
declare result jsonb; p jsonb; output jsonb:='[]';
begin
 result:=public.performance_coordinate_progression_v1(proposals,running,wk);
 for p in select value from jsonb_array_elements(result) loop
  if p->>'status'='ready' then
   p:=p||jsonb_build_object('work_seconds',public.performance_work_seconds_v2(p->'dose'),
     'work_minutes',ceil(public.performance_work_seconds_v2(p->'dose')/60.0));
  end if;
  output:=output||jsonb_build_array(p);
 end loop;
 return output;
end $$;

create function public.performance_place_v2(proposals jsonb,availability jsonb,occupied jsonb,
 prior_loads jsonb,rotation int,wk date,target_date date) returns jsonb
language plpgsql immutable set search_path='' as $$
declare days jsonb:='{}'; placed jsonb:='[]'; missing jsonb:='[]'; p jsonb; day jsonb; old jsonb;
 n int; d int; used int; cost int; wanted int; assigned int; blocked boolean; same_demand boolean;
 lower_days jsonb:='[]'; remaining jsonb:='{}'; score int:=0; actual_days int[]; rounds int;
begin
 for d in 1..7 loop days:=days||jsonb_build_object(d::text,jsonb_build_object('minutes',0,'work','[]'::jsonb)); end loop;
 -- Primero cubrir cada objetivo una vez; después distribuir su segunda exposición.
 for rounds in 1..2 loop
 for p in select value from jsonb_array_elements(proposals) where value->>'status'='ready'
  order by case when value->>'role'='support' then 1 else 0 end,
   case when value->>'model' in ('course','power','rope','reactive_agility') then 0 else 1 end,
   value->>'objective_key',value->>'reference_id' loop
  wanted:=(p->>'frequency')::int;
  select coalesce(array_agg((q->>'day')::int),'{}') into actual_days from jsonb_array_elements(placed) q where q->>'reference_id'=p->>'reference_id';
  assigned:=cardinality(actual_days); if rounds>wanted or assigned<>rounds-1 then continue; end if;
  for n in 0..6 loop
   d:=1+(n+rotation)%7;
   if coalesce(occupied,'[]') @> to_jsonb(array[d]) or wk+d-1>=target_date-1 then continue; end if;
   if exists(select 1 from unnest(actual_days) ad where abs(ad-d)<=1 or abs(ad-d)=6) then continue; end if;
   blocked:=false;
   for old in select value from jsonb_array_elements(placed||coalesce(prior_loads,'[]')) loop
    if abs((old->>'day')::int-d)=1 and exists(select 1 from jsonb_array_elements_text(p->'body_regions') reg
     where coalesce(old->'body_regions','["upper_body","lower_body","trunk"]') ? reg) then blocked:=true; exit; end if;
   end loop;
   if blocked then continue; end if;
   day:=days->d::text; used:=(day->>'minutes')::int;
   -- No apilar apoyos equivalentes o dos bloques fuertes del mismo patrón por ser ejercicios distintos.
   same_demand:=exists(select 1 from jsonb_array_elements(day->'work') q where
    exists(select 1 from jsonb_array_elements_text(p->'movement_patterns') pat where q->'movement_patterns' ? pat)
    or (p->'body_regions' ? 'upper_body' and q->'body_regions' ? 'upper_body'
       and (p->>'model'='isometric' or q->>'model'='isometric')
       and jsonb_array_length(p->'dose'->'targets') + coalesce((select sum(jsonb_array_length(t->'dose'->'targets')) from jsonb_array_elements(day->'work') t where t->'body_regions' ? 'upper_body'),0)>(public.performance_bank_v2()->>'maximum_shared_upper_sets')::int));
   if same_demand then continue; end if;
   cost:=(p->>'work_minutes')::int+case when used=0 then 10 else 0 end;
   if used+cost>coalesce((availability->>d::text)::int,0) then continue; end if;
   day:=day||jsonb_build_object('minutes',used+cost,'work',day->'work'||jsonb_build_array(p));
   days:=jsonb_set(days,array[d::text],day);
   placed:=placed||jsonb_build_array(jsonb_build_object('day',d,'reference_id',p->>'reference_id','body_regions',p->'body_regions'));
   score:=score+case when rounds=1 and p->>'role'<>'support' then 1000 when p->>'role'='support' then 10 else 100 end;
   exit;
  end loop;
 end loop;
 end loop;
 for p in select value from jsonb_array_elements(proposals) where value->>'status'='ready' loop
  select count(*) into assigned from jsonb_array_elements(placed) q where q->>'reference_id'=p->>'reference_id';
  wanted:=(p->>'frequency')::int;
  if assigned<wanted then missing:=missing||jsonb_build_array(jsonb_build_object('reference_id',p->>'reference_id',
   'objective_key',p->>'objective_key','name',p->>'name','role',p->>'role','requested',wanted,'scheduled',assigned,
   'reason',case when assigned=0 then 'No cabe este estímulo con tiempo y recuperación suficientes. Amplía días o revisa prioridades.' else 'Se pauta una exposición: la segunda no cabe respetando tiempo y recuperación.' end)); end if;
 end loop;
 for d in 1..7 loop
  day:=days->d::text; remaining:=remaining||jsonb_build_object(d::text,greatest(0,coalesce((availability->>d::text)::int,0)-(day->>'minutes')::int));
  if exists(select 1 from jsonb_array_elements(day->'work') x where coalesce((x->>'running_leg_load')::boolean,x->'body_regions' ? 'lower_body')) then lower_days:=lower_days||to_jsonb(d); end if;
 end loop;
 return jsonb_build_object('days',days,'remaining',remaining,'lower_days',lower_days,'missing',missing,'score',score);
end $$;

revoke all on function public.performance_bank_v2(), public.performance_work_seconds_v2(jsonb),
 public.performance_exposure_signal_v2(jsonb,jsonb), public.performance_task_v2(jsonb,jsonb,jsonb,date,date,jsonb),
 public.performance_coordinate_progression_v2(jsonb,jsonb,date), public.performance_place_v2(jsonb,jsonb,jsonb,jsonb,int,date,date)
 from public,anon,authenticated;


-- Conserva los segmentos originales de carrera; solo los ordena dentro del día.
create function public.preparation_shared_minutes_v2(force_session jsonb,run_session jsonb) returns integer
language sql immutable set search_path='' as $$
 select coalesce((force_session->>'standalone_minutes')::int,(force_session->>'minutes')::int)+(run_session->>'minutes')::int
 -case when force_session->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(run_session->'segments') s where s->>'role'='warmup') then 4 else 0 end
 -case when exists(select 1 from jsonb_array_elements(run_session->'segments') s where s->>'role'='cooldown') then 3 else 0 end
$$;

create function public.materialize_shared_preparation_day_v2(force_id uuid,run_id uuid,force_session jsonb,run_session jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare force_old uuid; merged uuid; block_id uuid; new_item_id uuid; block_idx int:=0; segment jsonb;
 phase text; phases text[]; b record; item record; srcset record; segment_index int; last_work int;
 run_first boolean:=force_session->>'session_order'='running_first'; has_warm boolean; has_cool boolean;
 total_minutes int:=public.preparation_shared_minutes_v2(force_session,run_session);
begin
 select template_id into force_old from public.scheduled_workouts where id=force_id and user_id=auth.uid() and status='planned' and execution_id is null for update;
 if force_old is null or not exists(select 1 from public.scheduled_workouts where id=run_id and user_id=auth.uid() and status='planned' and execution_id is null) then
  raise exception 'No se pueden unir sesiones iniciadas o ajenas.' using errcode='22023'; end if;
 has_warm:=exists(select 1 from jsonb_array_elements(run_session->'segments') s where s->>'role'='warmup');
 has_cool:=exists(select 1 from jsonb_array_elements(run_session->'segments') s where s->>'role'='cooldown');
 select max(ordinality)::int into last_work from jsonb_array_elements(run_session->'segments') with ordinality where value->>'role'='work';
 insert into public.workout_templates(name,description,origin,owner_user_id,visibility,status,estimated_duration_minutes,version)
 values('Entrenamiento combinado','Preparación compartida, trabajo por objetivos y una vuelta a la calma. Registra cada bloque por separado.','algorithm',auth.uid(),'private','published',total_minutes,1) returning id into merged;
 phases:=case when run_first then array['run_warm','run_work','force_warm','force_work','run_cool','force_cool']
 else array['run_warm','force_warm','force_work','run_work','run_cool','force_cool'] end;
 foreach phase in array phases loop
  if phase like 'run_%' then
   for segment,segment_index in select value,ordinality::int from jsonb_array_elements(run_session->'segments') with ordinality
     where case phase when 'run_warm' then value->>'role'='warmup' when 'run_cool' then value->>'role'='cooldown' else coalesce(value->>'role','work') not in ('warmup','cooldown') end loop
    insert into public.workout_blocks(template_id,order_index,name,format) values(merged,block_idx,
      case phase when 'run_warm' then 'Calentamiento compartido · carrera suave' when 'run_cool' then 'Vuelta a la calma compartida' else run_session->>'name' end,'running') returning id into block_id;
    insert into public.workout_items(block_id,exercise_id,order_index,notes) values(block_id,'20000000-0000-4000-8000-000000000004',0,
      case when phase='run_warm' then 'Empieza suave y aumenta gradualmente. Este tramo prepara también el resto de la sesión.'
      when phase='run_cool' then 'Reduce progresivamente el ritmo hasta terminar cómodo.'
      else (run_session->>'description')||case when segment_index=last_work then ' Al acabar, indica el esfuerzo del bloque de carrera, sin incluir la fuerza.' else '' end end) returning id into new_item_id;
    insert into public.workout_sets(item_id,order_index,target_duration_seconds,target_distance_meters,target_pace_min_seconds_per_km,target_pace_max_seconds_per_km,
      recovery_type,recovery_duration_seconds,target_rpe)
    values(new_item_id,0,(segment->>'seconds')::int,(segment->>'meters')::numeric,(segment->>'pace_min')::int,(segment->>'pace_max')::int,
      case when segment ? 'recovery_seconds' then coalesce(segment->>'recovery_type','jogging') end,(segment->>'recovery_seconds')::int,
      case when segment_index=last_work then coalesce((run_session->>'rpe_ceiling')::int,5) end);
    block_idx:=block_idx+1;
   end loop;
  else
   if phase='force_cool' and has_cool then continue; end if;
   for b in select * from public.workout_blocks where template_id=force_old and
    case phase when 'force_warm' then format='warm_up' when 'force_cool' then format='cool_down' else format not in ('warm_up','cool_down') end order by order_index loop
    insert into public.workout_blocks(template_id,order_index,name,format,rounds,time_cap_seconds,rest_after_seconds)
    values(merged,block_idx,case when phase='force_warm' and (run_first or has_warm) then 'Preparación específica · 3:00 min' else b.name end,b.format,b.rounds,b.time_cap_seconds,b.rest_after_seconds) returning id into block_id;
    for item in select wi.* from public.workout_items wi where wi.block_id=b.id order by wi.order_index loop
     insert into public.workout_items(block_id,exercise_id,order_index,notes) values(block_id,item.exercise_id,item.order_index,
       case when phase='force_warm' and (run_first or has_warm) then
       'Ya has realizado la activación general. Dedica un minuto a movilidad cómoda de las articulaciones que usarás y dos minutos a ensayar los movimientos siguientes con una variante fácil. Sin fatiga ni máximos. Amplía la preparación si aún no te encuentras preparado.' else item.notes end) returning id into new_item_id;
     insert into public.workout_sets(item_id,order_index,target_reps,target_duration_seconds,target_distance_meters,target_load_kg,target_rpe,target_rir,
       rest_after_seconds,performance_prescription)
     select new_item_id,ws.order_index,ws.target_reps,case when phase='force_warm' and (run_first or has_warm) then 180 else ws.target_duration_seconds end,
       ws.target_distance_meters,ws.target_load_kg,ws.target_rpe,ws.target_rir,ws.rest_after_seconds,ws.performance_prescription
     from public.workout_sets ws where ws.item_id=item.id;
    end loop;
    -- El origen queda inmutable; la referencia apunta al orden real de la plantilla compuesta.
    update public.performance_week_work set block_order=block_idx+1000 where scheduled_workout_id=force_id and block_order=b.order_index;
    block_idx:=block_idx+1;
   end loop;
  end if;
 end loop;
 update public.performance_week_work set block_order=block_order-1000 where scheduled_workout_id=force_id and block_order>=1000;
 update public.scheduled_workouts set template_id=merged,template_name='Entrenamiento combinado',estimated_duration_minutes=total_minutes,order_index=0 where id=force_id;
 update public.running_week_sessions set scheduled_workout_id=force_id where scheduled_workout_id=run_id;
 update public.scheduled_workouts set status='cancelled' where id=run_id;
end $$;
revoke all on function public.preparation_shared_minutes_v2(jsonb,jsonb),public.materialize_shared_preparation_day_v2(uuid,uuid,jsonb,jsonb) from public,anon,authenticated;


create or replace function public.validate_running_workout_set()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_format text;
begin
  select block.format into parent_format
  from public.workout_items as item
  join public.workout_blocks as block on block.id = item.block_id
  where item.id = new.item_id;

  if parent_format = 'running' then
    if num_nonnulls(
      new.target_duration_seconds,
      new.target_distance_meters
    ) <> 1
      or new.target_reps is not null
      or new.target_load_kg is not null
      or new.target_rir is not null
      or new.rest_after_seconds <> 0 then
      raise exception 'Running segments require one distance or duration target';
    end if;
  elsif new.target_pace_min_seconds_per_km is not null
    or new.target_pace_max_seconds_per_km is not null
    or new.recovery_type is not null
    or new.recovery_duration_seconds is not null
    or new.recovery_distance_meters is not null then
    raise exception 'Running metadata belongs only to running blocks';
  end if;
  return new;
end;
$$;

create or replace function public.calculate_running_week_constrained(
 p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean,p_constraints jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 ctx public.running_intake_contexts%rowtype; ref record; age integer;
 revise boolean:=coalesce((p_constraints->>'revise_week')::boolean,false);
 last_sunday date:=current_date-extract(isodow from current_date)::integer;
 prev public.running_week_decisions%rowtype; existing public.running_week_decisions%rowtype;
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb;
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
 if not found or ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
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
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped')
   and (not revise or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)))
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',sw.status,'rpe',case when exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id)
   then (select max(r.actual_rpe) from public.workout_execution_sets r where r.execution_id=e.id and r.block_format='running') else e.final_rpe end,'abandonment_reason',e.abandonment_reason,
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by sw.scheduled_date),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id and es.block_format='running') sets on true
 where wd.superseded_at is null and wd.preparation_goal_id=p_goal_id and wd.week_start>=p_week_start-56
   and wd.week_start<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(sw.scheduled_date-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped')
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
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,'capacity_minutes',ctx.comfortable_continuous_minutes,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 -- El coordinador puede solicitar otra propuesta con el tiempo restante.
 -- La política deportiva v5 y su historial permanecen intactos.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 result:=public.running_plan_v5(input);
 return result||jsonb_build_object('goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

create or replace function public.calculate_preparation_week_core(p_goal_id uuid,p_week_start date,p_revision boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype; ctx public.performance_training_contexts%rowtype;
  existing public.preparation_week_decisions%rowtype; previous public.preparation_week_decisions%rowtype;
  ref record; history jsonb; prior jsonb; proposal jsonb; proposals jsonb:='[]'; pending jsonb:='[]';
  occupied jsonb; loads jsonb; candidate jsonb; best jsonb; running jsonb; best_running jsonb;
  rotation int; score int; best_score int:=-2147483647; d int; session jsonb; blocked boolean; has_running boolean;
  running_error text; best_error text; coordinated jsonb; sessions jsonb:='[]'; required_missing boolean; selected_category text;
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
 for ref in select r.*,ep.definition from public.performance_training_references r
   join public.exercise_training_profiles ep on ep.code=r.reference->'task'->>'exercise_code'
     and ep.definition_version=(r.reference->'task'->>'exercise_version')::int
   where r.preparation_goal_id=p_goal_id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
   select coalesce(jsonb_agg(jsonb_build_object('execution_id',e.id,'completed_on',e.completed_at::date,
     'status',e.status,'abandonment_reason',e.abandonment_reason,'dose',pw.dose,'sets',sets.items) order by e.completed_at),'[]') into history
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   join public.workout_executions e on e.id=sw.execution_id
   join lateral(select jsonb_agg(jsonb_build_object('status',es.status,'prescription',es.performance_prescription,
     'result',es.performance_result) order by es.set_order) items from public.workout_execution_sets es
     where es.execution_id=e.id and es.block_order=pw.block_order) sets on true
   where pw.reference_id=ref.id and e.completed_at::date<p_week_start and e.completed_at::date>=p_week_start-56;
   select value into prior from jsonb_array_elements(coalesce(previous.decision->'proposals','[]'))
     where value->>'reference_id'=ref.id::text or value->'covered_reference_ids' ? ref.id::text limit 1;
   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) then
     proposal:=jsonb_build_object('status','needs_equipment','reason','Falta material para esta variante; usa una alternativa calibrada compatible.');
   else proposal:=public.performance_task_v2(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end); end if;
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
     ||jsonb_build_object('covered_reference_ids',jsonb_agg(p->'reference_id'),'frequency',max((p->>'frequency')::int)) proposal
   from jsonb_array_elements(proposals) p where p->>'status'='ready' group by p->'dose'
   union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) x;
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=p_goal_id order by a.assessed_on desc,a.created_at desc limit 1;
 if selected_category is null and exists(select 1 from public.program_assessment_tests where program_id=g.program_id and (category<>'both' or min_age<>0 or max_age<>120)) then
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_assessment','name','Categoría de las pruebas',
     'reason','Completa la evaluación de esta preparación para identificar las pruebas que te corresponden.')); end if;
 for ref in select b.test_id,t.name from public.program_test_training_bindings b
   join public.program_assessment_tests t on t.id=b.test_id
   where b.program_id=g.program_id and public.performance_test_applies(g.id,t.id) and (t.category='both' or t.category=selected_category)
     and not exists(select 1 from public.performance_training_references r where r.preparation_goal_id=p_goal_id and r.active and r.test_id=b.test_id) loop
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
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::int),'[]') into occupied
   from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6 and status not in ('cancelled','skipped')
   and (not p_revision or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)));
 select coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
     and sw.status not in ('cancelled','skipped')
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped')
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry');
 for rotation in 0..6 loop
   candidate:=public.performance_place_v2(proposals,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
   running:=null; running_error:=null;
   if has_running then
     begin
       running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
         jsonb_build_object('revise_week',p_revision,'availability',candidate->'remaining','strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days'));
     if jsonb_array_length(coalesce(running->'sessions','[]'))=0 then
         running_error:='No cabe una sesión de carrera compatible. Revisa disponibilidad y referencias.'; running:=null;
       elsif exists(select 1 from jsonb_array_elements(running->'sessions') rs where
         (rs->>'minutes')::int>coalesce((candidate->'remaining'->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)) then
         running_error:='La carrera ya publicada supera la disponibilidad actual. Revisa la agenda antes de añadir fuerza.'; running:=null;
       end if;
     exception when others then
       running_error:=case
         when sqlerrm like '%current running context%' then 'Actualiza el cuestionario de carrera y sus cuatro semanas recientes.'
         when sqlerrm like '%Health flag%' then 'Has indicado molestias en carrera. Actualiza tu situación antes de planificar.'
         when sqlerrm like '%compatible 2 km mark%' or sqlerrm like '%reuse window%' then 'Elige una marca vigente de 2 km para esta preparación.'
         when sqlerrm like '%Confirm uninterrupted%' then 'Confirma la continuidad de carrera para reutilizar esta marca.'
         when sqlerrm like '%standard or margin%' then 'Falta un mínimo oficial aplicable; elige una meta concreta o mejorar sin cifra.'
         else 'No se ha podido proponer carrera. Revisa la referencia, el cuestionario y los días disponibles.' end;
     end;
   end if;
   score:=(candidate->>'score')::int;
   -- Cobertura antes que minutos: evita premiar accesorios por desplazar carrera.
   score:=score - 10000*(select count(*) from jsonb_array_elements(candidate->'missing') q where q->>'role'<>'support' and (q->>'scheduled')::int=0);
   if running is not null then score:=score+1000+300*jsonb_array_length(running->'sessions')
     +100*(select count(*) from jsonb_array_elements(running->'sessions') q where q->>'kind'<>'easy'); end if;
   if score>best_score then best:=candidate; best_running:=running; best_score:=score; best_error:=running_error; end if;
 end loop;
 -- El trabajo descartado no consume el permiso de progresar de lo publicado.
 select coalesce(jsonb_agg(p),'[]') into coordinated from jsonb_array_elements(proposals) p
 where exists(select 1 from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w where w->>'reference_id'=p->>'reference_id');
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
 select coordinated||coalesce(jsonb_agg(p),'[]') into coordinated from jsonb_array_elements(proposals) p
 where not exists(select 1 from jsonb_array_elements(coordinated) c where c->>'reference_id'=p->>'reference_id');
 -- Mantener una dosis solo reduce el coste ya reservado; nunca rellena ese margen.
 for d in 1..7 loop
   select coalesce(jsonb_agg(c order by w.ordinality),'[]') into session from jsonb_array_elements(best->'days'->d::text->'work') with ordinality w(value,ordinality)
     join lateral(select value c from jsonb_array_elements(coordinated) c where c->>'reference_id'=w.value->>'reference_id') q on true;
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
 required_missing:=(jsonb_array_length(sessions)=0 and best_running is null) or exists(select 1 from jsonb_array_elements(pending) p
   where coalesce(p->>'role','specific')<>'support' and coalesce((p->>'scheduled')::int,0)=0);
 return jsonb_build_object('status',case when required_missing then 'needs_attention' else 'ready' end,
   'policy_version','preparation_coordinator_v2','week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

create or replace function public.publish_preparation_week(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); plan jsonb; saved public.preparation_week_decisions%rowtype;
  d_id uuid; t_id uuid; b_id uuid; i_id uuid; sw_id uuid; ex_id uuid; s jsonb; w jsonb; v jsonb;
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
 if exists(select 1 from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null)
   and current_date<p_week_start-1 then raise exception 'Cierra la semana anterior antes de adaptar y publicar.' using errcode='22023'; end if;
 plan:=public.calculate_preparation_week(p_goal_id,p_week_start);
 if plan->>'status'<>'ready' then raise exception 'Resuelve los datos o conflictos pendientes antes de publicar.' using errcode='22023'; end if;
 if p_expected_proposal is null or plan is distinct from p_expected_proposal then
   raise exception 'Los datos o la agenda han cambiado. Revisa la propuesta actualizada.' using errcode='22023'; end if;
 insert into public.preparation_week_decisions(user_id,preparation_goal_id,week_start,policy_version,decision,input_snapshot)
 values(u,p_goal_id,p_week_start,plan->>'policy_version',plan,jsonb_build_object(
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
   insert into public.workout_items(block_id,exercise_id,order_index,notes)
     values(b_id,'21000000-0000-4000-8000-000000000001',0,
       coalesce(s->>'warm_up_instructions',public.performance_warm_up_instructions_v1(s))) returning id into i_id;
   insert into public.workout_sets(item_id,order_index,target_duration_seconds,rest_after_seconds)
     values(i_id,0,420,0);
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
     perform public.materialize_shared_preparation_day_v2(sw_id,run_schedule,s,run_session);
   end if;
 end loop;
 update public.preparation_week_decisions set decision=plan where id=d_id;
 return plan||jsonb_build_object('decision_id',d_id,'already_published',false);
end $$;

commit;
