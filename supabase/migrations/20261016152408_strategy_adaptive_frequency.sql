begin;

-- Política por estímulo. Las separaciones son guardas conservadoras de producto,
-- no tiempos biológicos universales ni un máximo de sesiones por movimiento.
create function public.performance_frequency_strategy_v2(p jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_object('version','performance_frequency_v2',
  'recovery_days',case when p->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') then 1 else 2 end,
  'recovery_basis',case when p->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') then 'controlled_course_practice' else 'regional_work_or_quality' end,
  'allocation',case when p->>'model' in ('repetitions','load_repetitions','isometric','timed_repetitions')
    or (p->>'model'='carry' and p->'dose'->'task'->>'measurement' in ('DURATION','DISTANCE')) then 'quantity' else 'attempts' end,
  'minimum_quantity',coalesce((p->>'minimum_quantity_from_reference')::int,case when p->>'model'='load_repetitions' then coalesce((p->>'rep_min')::int,4)
    when p->'dose'->'task'->>'measurement'='DURATION' then 3 else 1 end,
    1),
  'parameter_status','operational_requires_outcome_monitoring')
$$;

-- Distribuir un presupuesto acreditado; no convertirlo en más kilos o velocidad.
create function public.performance_redistribute_v2(p jsonb,doses jsonb,new_frequency int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare cfg jsonb:=public.performance_frequency_strategy_v2(p); baseline jsonb:=doses->0;
 n int; total int; per_exposure int; per_set int; remainder int; i int; targets jsonb; result jsonb:='[]'; all_targets jsonb;
begin
 if new_frequency<1 or jsonb_array_length(doses)<1 then return null; end if;
 if cfg->>'allocation'='quantity' then
   select floor(sum(v::numeric))::int into total from jsonb_array_elements(doses) d,
     jsonb_array_elements_text(d->'targets') v;
   n:=greatest(1,ceil((select sum(jsonb_array_length(d->'targets')) from jsonb_array_elements(doses) d)::numeric/new_frequency)::int);
   per_exposure:=total/new_frequency; per_set:=per_exposure/n; remainder:=per_exposure%n;
   if per_set<(cfg->>'minimum_quantity')::int then return null; end if;
   select jsonb_agg(per_set+case when j<=remainder then 1 else 0 end order by j) into targets from generate_series(1,n) j;
   for i in 1..new_frequency loop
     result:=result||jsonb_build_array(baseline||jsonb_build_object('targets',targets,
       'task',(baseline->'task')||jsonb_build_object('target_value',targets->0)));
   end loop;
 else
   select jsonb_agg(v order by ord,idx) into all_targets from jsonb_array_elements(doses) with ordinality x(d,ord),
     jsonb_array_elements(d->'targets') with ordinality y(v,idx);
   total:=jsonb_array_length(all_targets);
   if total<new_frequency then return null; end if;
   -- Los intentos indivisibles se reparten sin perder ninguno (p. ej. 2+1).
   for i in 1..new_frequency loop
     n:=total/new_frequency+case when i<=total%new_frequency then 1 else 0 end;
     select jsonb_agg(v order by ord) into targets from jsonb_array_elements(all_targets) with ordinality x(v,ord)
       where ord> (i-1)*(total/new_frequency)+least(i-1,total%new_frequency)
       and ord<=i*(total/new_frequency)+least(i,total%new_frequency);
     result:=result||jsonb_build_array(baseline||jsonb_build_object('targets',targets,
       'task',(baseline->'task')||jsonb_build_object('target_value',targets->0)));
   end loop;
 end if;
 return result;
end $$;

create function public.performance_task_v5(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
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
 changed:=previous->'dose' is not null and ((previous->'dose'->'task')-array['target_value','instructions','policy_version'])
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

create function public.performance_frequency_candidate_v2(p jsonb,frequency_limit int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare freq int; doses jsonb;
begin
 if p->>'status'<>'ready' then return p; end if;
 freq:=least(greatest(1,frequency_limit),(p->>'frequency')::int);
 if freq<(p->>'frequency')::int and p->>'outcome'='redistribute' then
   p:=p||jsonb_build_object('dose',p->'frequency_fallback_dose','exposure_doses',p->'frequency_fallback_exposures',
     'outcome',p->'frequency_fallback_outcome','reason',p->>'frequency_fallback_reason'||' Conservamos la frecuencia conocida porque otra exposición no cabe.');
 end if;
 select jsonb_agg(d order by ord) into doses from jsonb_array_elements(p->'exposure_doses') with ordinality x(d,ord) where ord<=freq;
 if frequency_limit=0 then
   p:=public.performance_compact_proposal_v2(p); doses:=jsonb_build_array(p->'dose');
 end if;
 return p||jsonb_build_object('requested_frequency',p->'frequency','frequency',freq,'exposure_doses',doses,'dose',doses->0);
end $$;

create function public.performance_exposure_v2(p jsonb,exposure int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare dose jsonb:=coalesce(p->'exposure_doses'->exposure,p->'dose'); comparison jsonb; seconds int; reserved int;
begin
 comparison:=coalesce(p->'comparison_exposure_doses'->exposure,p->'comparison_dose');
 seconds:=public.performance_work_seconds_v2(dose); reserved:=seconds;
 -- Volver de un escalón de carga a su dosis anterior puede requerir más reps.
 if p->>'outcome'='progress' then reserved:=greatest(seconds,public.performance_work_seconds_v2(comparison)); end if;
 return p||jsonb_build_object('dose',dose,'exposure_index',exposure,'work_seconds',seconds,
   'work_minutes',ceil(seconds/60.0),'reservation_minutes',ceil(reserved/60.0));
end $$;

create function public.performance_reconcile_exposures_v2(p jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
begin
 if p->>'outcome'='maintain' and p->'dose'=p->'comparison_dose'
   and p->'exposure_doses'->0 is distinct from p->'dose' then
   p:=p||jsonb_build_object('exposure_doses',p->'comparison_exposure_doses');
 end if;
 return p;
end $$;

revoke all on function public.performance_frequency_strategy_v2(jsonb),public.performance_redistribute_v2(jsonb,jsonb,int),
 public.performance_task_v5(jsonb,jsonb,jsonb,date,date,jsonb,date),public.performance_frequency_candidate_v2(jsonb,int),
 public.performance_exposure_v2(jsonb,int),public.performance_reconcile_exposures_v2(jsonb) from public,anon,authenticated;


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
      where q.policy_version='performance_v1' and q.goal_code=(p_reference->>'goal_code') and q.work_code=work.code;
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
    or (p_reference->>'frequency') is null or (p_reference->>'frequency')::int not between 1 and 7 then
    raise exception 'Confirma los descansos y las sesiones por semana que ya toleras, entre una y siete.' using errcode='22023'; end if;
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
       or (main.p->>'model'='course' and candidate.p->>'role'='support' and candidate.p->>'model'='load_repetitions')
       or (main.p->>'exercise_code'='front_plank_forearms' and candidate.p->>'exercise_code'='dead_bug'))
     and coalesce(main.p->>'outcome','initial')<>'reduce')
   and jsonb_array_length(candidate.p->'dose'->'targets')<=2)
  union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) select coalesce(jsonb_agg(p order by coalesce((p->>'selection_rank')::int,0),p->>'reference_id'),'[]') from selected
$$;
revoke all on function public.performance_select_v4(jsonb) from public,anon,authenticated;

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
   value->>'objective_key',value->>'reference_id' loop
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
revoke all on function public.performance_place_v4(jsonb,jsonb,jsonb,jsonb,int,date,date) from public,anon,authenticated;

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
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
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
     ||jsonb_build_object('covered_reference_ids',jsonb_agg(p->'reference_id'),'covered_objective_keys',jsonb_agg(p->'objective_key'),'frequency',max((p->>'frequency')::int)) proposal
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
   'policy_version','preparation_coordinator_v3','evidence_policy_version','adaptive_evidence_v1','frequency_policy_version','performance_frequency_v2','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

commit;
