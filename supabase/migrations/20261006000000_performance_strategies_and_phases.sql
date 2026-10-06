-- Estrategias por objetivo y fases visibles. Carrera v5 no se redefine.
begin;

-- Recalibrar sustituye solo la misma medición. Una serie libre y una marca
-- temporal conservan referencias propias y no se convierten entre sí.
drop index public.performance_reference_active;
create unique index performance_reference_active on public.performance_training_references
 (preparation_goal_id,objective_key,(reference->'task'->>'exercise_code'),(reference->'task'->>'measurement')) where active;

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
  if kind<>'legacy_work' then min_reps:=case when goal_mode='MAX_LOAD' then 4 else 6 end; max_reps:=case when goal_mode='MAX_LOAD' then 6 else 10 end; end if;
  if min_reps not between 3 and 10 or max_reps not between min_reps+1 and 12 then
    raise exception 'Horquilla de trabajo no válida.' using errcode='22023'; end if;
  if kind='legacy_work' and task->>'measurement'='LOAD_REPS' and exists(select 1 from jsonb_array_elements_text(p_reference->'targets') val
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
    and objective_key=key and reference->'task'->>'exercise_code'=work.code and reference->'task'->>'measurement'=task->>'measurement' and active;
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

-- Estrategia por objetivo sobre referencias reales. No contiene dosis de carrera.
-- Los plazos de 14/28/7 días son parámetros operativos, no óptimos universales.
create function public.performance_block_v3(reference jsonb, history jsonb, wk date,
 target_date date, started_on date, previous jsonb default '{}'::jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare phase text; remaining int:=target_date-wk; good int:=0; difficult int:=0;
 last_day date; h jsonb; signal text; entered date; reason text; interrupted boolean; counted int:=0;
begin
 for h in select value from jsonb_array_elements(coalesce(history,'[]'))
   where (value->>'completed_on')::date between greatest((reference->>'observed_on')::date,wk-21) and wk-1
   order by value->>'completed_on' desc loop
  if last_day=(h->>'completed_on')::date then continue; end if;
  signal:=public.performance_exposure_signal_v2(h,h->'dose');
  if signal='tolerated' then good:=good+1;
  elsif signal='difficulty' then difficult:=difficult+1; end if;
  last_day:=(h->>'completed_on')::date;
  counted:=counted+1; exit when counted>=2;
 end loop;
 interrupted:=not exists(select 1 from jsonb_array_elements(coalesce(history,'[]')) e
   where (e->>'completed_on')::date between wk-21 and wk-1);
 phase:=case when remaining<=7 then 'taper' when remaining<=28 then 'specific'
   when (previous->>'phase' in ('development','specific') and not interrupted)
     or (good>=2 and not interrupted) then 'development' else 'base' end;
 reason:=case phase when 'base' then 'Encontrar trabajo practicable y consolidar técnica antes de ampliar la exigencia.'
  when 'development' then 'Desarrollar capacidad específica y apoyos pertinentes, conservando lo que permite comparar tu respuesta.'
  when 'specific' then 'Aumentar la prioridad del protocolo del examen con la capacidad actual; no perseguir aún una marca deseada.'
  else 'Conservar práctica conocida y reducir trabajo fatigante antes de la prueba.' end;
 if difficult>0 then reason:=reason||' La dificultad reciente modifica la dosis; cambiar de fecha no acredita preparación.'; end if;
 entered:=case when previous->>'phase'=phase and not interrupted then coalesce((previous->'block'->>'entered_on')::date,wk) else wk end;
 return jsonb_build_object('code',phase,'name',case phase when 'base' then 'Consolidar el punto de partida'
   when 'development' then 'Desarrollar fuerza y resistencia' when 'specific' then 'Preparar el formato del examen' else 'Llegar recuperado' end,
   'purpose',reason,'entered_on',entered,'weeks_in_block',greatest(1,(wk-entered)/7+1),
   'target_date',target_date,'days_remaining',remaining,'comparable_tolerated_exposures',good,
   'next_review','Revisamos la dosis con cada cierre de semana y el énfasis al cambiar la respuesta o acercarse la prueba.',
   'recent_difficulty',difficult>0,'parameter_status','operational_requires_outcome_monitoring');
end $$;

create function public.performance_select_v3(proposals jsonb) returns jsonb
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
  select p||jsonb_build_object('selection_rank',n,'optional',n>1,
    'role',case when n>1 then 'support' else p->>'role' end,
    'frequency',case when n>1 then 1 else (p->>'frequency')::int end,
    'selection_reason',coalesce(p->>'selection_reason','')||case when n>1
      then ' Apoyo opcional con referencia propia; se retira si desplaza trabajo prioritario.' else '' end) p
  from ranked where n=1 or (n=2
   and exists(select 1 from ranked main where main.n=1 and main.p->>'objective_key'=p->>'objective_key'
     and main.p->>'phase'='development' and (
       (main.p->>'exercise_code'='push_up_standard' and p->>'role'='support')
       or (main.p->>'model'='course' and p->>'role'='support' and p->>'model'='load_repetitions')
       or (main.p->>'exercise_code'='front_plank_forearms' and p->>'exercise_code'='dead_bug'))
     and coalesce(main.p->>'outcome','initial')<>'reduce')
   and jsonb_array_length(p->'dose'->'targets')<=2)
  union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) select coalesce(jsonb_agg(p order by coalesce((p->>'selection_rank')::int,0),p->>'reference_id'),'[]') from selected
$$;

create function public.performance_program_path_v3(started_on date,target_date date,wk date,proposals jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare stages jsonb:='[]'; first_specific date:=greatest(started_on,target_date-28);
 first_taper date:=greatest(started_on,target_date-7); first_development date;
begin
 first_development:=least(first_specific,started_on+14);
 if started_on<first_development then stages:=stages||jsonb_build_array(jsonb_build_object(
  'code','base','name','Consolidar el punto de partida','starts_on',started_on,'ends_on',first_development-1,
  'purpose','Confirmar técnica, datos y una dosis tolerable. La transición se revisa con los resultados.')); end if;
 if first_development<first_specific then stages:=stages||jsonb_build_array(jsonb_build_object(
  'code','development','name','Desarrollar fuerza y resistencia','starts_on',first_development,'ends_on',first_specific-1,
  'purpose','Desarrollo revisable por bloques; trabajo específico y apoyos con datos propios.')); end if;
 if first_specific<first_taper then stages:=stages||jsonb_build_array(jsonb_build_object(
  'code','specific','name','Preparar el formato del examen','starts_on',first_specific,'ends_on',first_taper-1,
  'purpose','Dar más peso a las condiciones de la prueba sin convertir cada entrenamiento en un máximo.')); end if;
 stages:=stages||jsonb_build_array(jsonb_build_object('code','taper','name','Llegar recuperado',
  'starts_on',first_taper,'ends_on',target_date,'purpose','Menos trabajo fatigante y práctica conocida.'));
 return jsonb_build_object('version','program_path_v3','planned',true,'target_date',target_date,
  'stages',stages,'objectives',coalesce((select jsonb_agg(coalesce(p->'block',jsonb_build_object(
     'code',p->>'phase','name',case p->>'phase' when 'base' then 'Consolidar el punto de partida' when 'development' then 'Desarrollar fuerza y resistencia' when 'specific' then 'Preparar el formato del examen' else 'Llegar recuperado' end,
     'purpose',coalesce(p->>'selection_reason',p->>'reason')))||jsonb_build_object(
     'objective_key',p->>'objective_key','exercise_name',p->>'name')) from jsonb_array_elements(proposals) p
     where p->>'status'='ready' and p->>'optional' is distinct from 'true'),'[]'),
  'note','Fechas orientativas. Cada objetivo conserva su fase real según resultados y tiempo hasta la prueba.');
end $$;

create function public.performance_calibration_options_v3(p_goal_id uuid) returns jsonb
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
    and (rel.role='support' or (rel.goal_code='front_plank_forearms' and rel.work_code='dead_bug')) and rel.policy_version='performance_v1'
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
revoke all on function public.performance_block_v3(jsonb,jsonb,date,date,date,jsonb),
 public.performance_select_v3(jsonb),public.performance_program_path_v3(date,date,date,jsonb),
 public.performance_calibration_options_v3(uuid) from public,anon,authenticated;

-- Una comprobación submáxima sustituye la primera exposición ordinaria al
-- cambiar a especificidad, si hay respuesta comparable suficiente. No se
-- añade volumen, no estima una marca máxima y no se activa por contador.
create function public.performance_controls_v3(sessions jsonb,previous jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare result jsonb:='[]'; session jsonb; work jsonb; items jsonb; old jsonb; used text[]:='{}'; key text;
begin
 for session in select value from jsonb_array_elements(coalesce(sessions,'[]')) order by value->>'date' loop
  items:='[]';
  for work in select value from jsonb_array_elements(session->'work') loop
   key:=work->>'reference_id';
   select value into old from jsonb_array_elements(coalesce(previous->'proposals','[]')) p
    where p->>'reference_id'=key or p->'covered_reference_ids' ? key limit 1;
   if work->>'phase'='specific' and old->>'phase'='development'
     and (work->'block'->>'comparable_tolerated_exposures')::int>=2
     and work->>'outcome'<>'reduce' and work->>'optional' is distinct from 'true'
     and not key=any(used) then
    work:=work||jsonb_build_object('control',jsonb_build_object('kind','submaximal_work',
      'purpose','Comprobar calidad y esfuerzo al entrar en trabajo específico. No mide tu máximo.',
      'replaces','ordinary_exposure','updates','work_capacity_only'),
      'name','Control submáximo · '||(work->>'name'),
      'reason',(work->>'reason')||' Hoy comprobamos la respuesta en condiciones repetibles. Registra trabajo válido, esfuerzo y técnica; no añadas un máximo.');
    used:=array_append(used,key);
   end if;
   items:=items||jsonb_build_array(work);
  end loop;
  result:=result||jsonb_build_array(session||jsonb_build_object('work',items));
 end loop;
 return result;
end $$;
revoke all on function public.performance_controls_v3(jsonb,jsonb) from public,anon,authenticated;

create function public.performance_warm_up_steps_v3(session jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare output jsonb:='[]'; mobility text; rehearsal text:=''; w jsonb; shared boolean:=coalesce((session->>'warm_up_seconds')::int,420)=180;
begin
 if not shared then output:=output||jsonb_build_array(jsonb_build_object('name','Activación suave','seconds',180,
   'instructions','Camina o trota suavemente. Aumenta el movimiento de forma gradual, a un ritmo que te permita hablar con comodidad.')); end if;
 mobility:='Movimientos cómodos de hombros, codos y muñecas para los apoyos. Si hay desplazamientos, incluye tobillos, rodillas y caderas. Sin forzar posiciones.';
 for w in select value from jsonb_array_elements(coalesce(session->'work','[]')) loop
   rehearsal:=rehearsal||coalesce(w->>'name','Movimiento pautado')||': '||case
    when w->>'model'='course' then 'ensaya despacio la salida, los giros y la frenada; comprueba el espacio libre.'
    when w->>'model'='isometric' then 'ensaya la postura unos segundos, respirando, y termina antes de que cueste.'
    else 'ensaya pocas repeticiones con apoyo o carga fácil, lejos del agotamiento.' end||E'\n';
 end loop;
 return output||jsonb_build_array(
   jsonb_build_object('name','Movilidad cómoda','seconds',case when shared then 60 else 120 end,'instructions',mobility),
   jsonb_build_object('name','Ensayo de los movimientos','seconds',120,'instructions',rehearsal||'La duración es orientativa. Amplía la preparación si aún no te encuentras preparado; hoy no buscamos fatiga ni máximos.'));
end $$;
revoke all on function public.performance_warm_up_steps_v3(jsonb) from public,anon,authenticated;


create function public.performance_task_v3_core(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
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

create function public.performance_task_v3(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,previous jsonb default '{}'::jsonb,started_on date default null)
returns jsonb language plpgsql immutable set search_path='' as $$
declare b jsonb:=public.performance_block_v3(reference,history,wk,target_date,coalesce(started_on,wk),previous);
 p jsonb:=public.performance_task_v3_core(reference||jsonb_build_object('strategy_phase',b->>'code'),profile,history,wk,target_date,previous); baseline jsonb; targets jsonb; e jsonb;
 good int:=0; easy int:=0; budget int; idx int; initial numeric; current_value numeric; count_sets int; n int; seconds int;
begin
 p:=p||jsonb_build_object('block',b);
 if p->>'outcome'<>'progress' or p->>'model' not in ('repetitions','isometric') then return p; end if;
 for e in select value from jsonb_array_elements(p->'evidence') where value->>'signal'='tolerated' loop
  good:=good+1;
  if not exists(select 1 from jsonb_array_elements(e->'exposure'->'sets') s where
    case when p->>'model'='repetitions' then coalesce((s->'result'->>'rir')::numeric,0)<6
    else coalesce((s->'result'->>'rpe')::numeric,10)>4 end) then easy:=easy+1; end if;
 end loop;
 if good<2 or easy<2 then return p; end if;
 baseline:=p->'comparison_dose'->'targets'; targets:=baseline; count_sets:=jsonb_array_length(targets);
 select greatest(1,floor(sum(value::numeric)*0.10))::int into budget from jsonb_array_elements_text(targets);
 -- Cota operativa: hasta 10% de volumen, como máximo tres unidades por serie.
 budget:=least(budget,count_sets*3);
 for n in 1..budget loop
  select ordinality::int-1 into idx from jsonb_array_elements_text(targets) with ordinality
   where value::numeric<(baseline->>(ordinality::int-1))::numeric+3 order by value::numeric,ordinality limit 1;
  if idx is null then exit; end if;
  targets:=jsonb_set(targets,array[idx::text],to_jsonb((targets->>idx)::numeric+1));
 end loop;
 p:=jsonb_set(p,'{dose,targets}',targets); p:=jsonb_set(p,'{dose,task,target_value}',targets->0);
 seconds:=public.performance_work_seconds_v2(p->'dose');
 return p||jsonb_build_object('work_seconds',seconds,'work_minutes',ceil(seconds/60.0),'adaptation_rule','repeated_very_easy_bounded_volume_v1',
  'reason',p->>'reason'||' Ambas exposiciones dejaron mucho margen: ajuste limitado del volumen, sin estimar un máximo ni cambiar la variante.');
end $$;

create function public.performance_place_v3(proposals jsonb,availability jsonb,occupied jsonb,
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
  order by case when value->>'required_for_objective'='true' then 0 else 1 end,
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
    exists(select 1 from jsonb_array_elements_text(p->'movement_patterns') pat where q->'movement_patterns' ? pat) and not (p->>'objective_key'=q->>'objective_key' and (p->>'optional'='true') is distinct from (q->>'optional'='true') and jsonb_array_length(p->'dose'->'targets')+jsonb_array_length(q->'dose'->'targets')<=4)
    or (p->'body_regions' ? 'upper_body' and q->'body_regions' ? 'upper_body'
       and (p->>'model'='isometric' or q->>'model'='isometric')
       and jsonb_array_length(p->'dose'->'targets') + coalesce((select sum(jsonb_array_length(t->'dose'->'targets')) from jsonb_array_elements(day->'work') t where t->'body_regions' ? 'upper_body'),0)>(public.performance_bank_v2()->>'maximum_shared_upper_sets')::int));
   if same_demand then continue; end if;
   cost:=(p->>'work_minutes')::int+case when used=0 then 10 else 0 end;
   if used+cost>coalesce((availability->>d::text)::int,0) then continue; end if;
   day:=day||jsonb_build_object('minutes',used+cost,'work',day->'work'||jsonb_build_array(p));
   days:=jsonb_set(days,array[d::text],day);
   placed:=placed||jsonb_build_array(jsonb_build_object('day',d,'reference_id',p->>'reference_id','body_regions',p->'body_regions'));
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
   'reason',case when assigned=0 then 'No cabe este estímulo con tiempo y recuperación suficientes. Amplía días o revisa prioridades.' else 'Se pauta una exposición: la segunda no cabe respetando tiempo y recuperación.' end)); end if;
 end loop;
 for d in 1..7 loop
  day:=days->d::text; remaining:=remaining||jsonb_build_object(d::text,greatest(0,coalesce((availability->>d::text)::int,0)-(day->>'minutes')::int));
  if exists(select 1 from jsonb_array_elements(day->'work') x where coalesce((x->>'running_leg_load')::boolean,x->'body_regions' ? 'lower_body')) then lower_days:=lower_days||to_jsonb(d); end if;
 end loop;
 return jsonb_build_object('days',days,'remaining',remaining,'lower_days',lower_days,'missing',missing,'score',score);
end $$;

create or replace function public.calculate_preparation_week_for_scope(p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype; ctx public.performance_training_contexts%rowtype;
  existing public.preparation_week_decisions%rowtype; previous public.preparation_week_decisions%rowtype;
  ref record; history jsonb; prior jsonb; proposal jsonb; proposals jsonb:='[]'; pending jsonb:='[]';
  occupied jsonb; loads jsonb; candidate jsonb; best jsonb; running jsonb; best_running jsonb;
  started_on date; include_support boolean; frequency_limit int; candidates jsonb; expected_running jsonb; minimum_runs int:=1; expected_runs int:=0; actual_runs int:=0;
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
 select coalesce(min(week_start),p_week_start) into started_on from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;
 for ref in select r.*,ep.definition from public.performance_training_references r
   join public.exercise_training_profiles ep on ep.code=r.reference->'task'->>'exercise_code'
     and ep.definition_version=(r.reference->'task'->>'exercise_version')::int
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
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
   else proposal:=public.performance_task_v3(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end,started_on); end if;
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

 proposals:=public.performance_select_v3(proposals);
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
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::int),'[]') into occupied
   from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6 and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(p_excluded)
   and (not p_revision or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)));
 select coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
     and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=p_scope<>'performance' and (exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry'));
 -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and q->>'objective_key'=p->>'objective_key'
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
 for frequency_limit in reverse 2..0 loop
 select coalesce(jsonb_agg((case when frequency_limit=0 then public.performance_compact_proposal_v2(p) else p end)||jsonb_build_object('requested_frequency',p->'frequency','frequency',least(greatest(1,frequency_limit),(p->>'frequency')::int))),'[]') into candidates from jsonb_array_elements(proposals) p where include_support or p->>'optional' is distinct from 'true';
 for rotation in 0..6 loop
   candidate:=public.performance_place_v3(candidates,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
   running:=null; running_error:=null;
   if has_running then
     begin
       running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
         jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),'availability',candidate->'remaining','strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days'));
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
   score:=score - 10000*(select count(*) from jsonb_array_elements(candidate->'missing') q where q->>'required_for_objective'='true' and (q->>'scheduled')::int=0);
   if running is not null then score:=score+1000+300*jsonb_array_length(running->'sessions')
     +100*(select count(*) from jsonb_array_elements(running->'sessions') q where q->>'kind'<>'easy'); end if;
   if frequency_limit=0 then score:=score-50; end if;
   if has_running and jsonb_array_length(coalesce(running->'sessions','[]'))<minimum_runs then score:=score-10000; end if;
   if score>best_score then best:=candidate; best_running:=running; best_score:=score; best_error:=running_error; end if;
 end loop;
 end loop;
 end loop;
 -- El trabajo descartado no consume el permiso de progresar de lo publicado.
 select coalesce(jsonb_agg(w),'[]') into coordinated from (select distinct w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w) chosen;
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
 select coordinated||coalesce(jsonb_agg(p||jsonb_build_object('allocation_status','not_scheduled','allocation_reason','Se conserva la referencia, pero esta semana tiene prioridad la cobertura específica, carrera y recuperación.')),'[]') into coordinated from jsonb_array_elements(proposals) p
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
   'policy_version','preparation_coordinator_v3','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

create or replace function public.get_preparation_training_setup(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare setup jsonb; a public.adaptive_program_states%rowtype; scope text; active_program jsonb; latest jsonb; started_on date; path jsonb;
begin
 setup:=public.get_preparation_training_setup_base(p_goal_id);
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

create function public.materialize_shared_preparation_day_v3(force_id uuid,run_id uuid,force_session jsonb,run_session jsonb)
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
       item.notes) returning id into new_item_id;
     insert into public.workout_sets(item_id,order_index,target_reps,target_duration_seconds,target_distance_meters,target_load_kg,target_rpe,target_rir,
       rest_after_seconds,performance_prescription)
     select new_item_id,ws.order_index,ws.target_reps,ws.target_duration_seconds,
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

revoke all on function public.performance_task_v3_core(jsonb,jsonb,jsonb,date,date,jsonb),public.performance_task_v3(jsonb,jsonb,jsonb,date,date,jsonb,date),public.performance_place_v3(jsonb,jsonb,jsonb,jsonb,integer,date,date) from public,anon,authenticated;

revoke all on function public.materialize_shared_preparation_day_v3(uuid,uuid,jsonb,jsonb) from public,anon,authenticated;

commit;
