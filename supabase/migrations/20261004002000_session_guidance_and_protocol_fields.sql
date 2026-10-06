-- Instrucciones de sesión y capacidades explícitas, sin modificar dosis ni carrera.
begin;

alter table public.workout_execution_sets add column item_instructions text;
comment on column public.workout_execution_sets.item_instructions is
  'Notas del ejercicio en esta sesión, copiadas al iniciar y conservadas en el historial.';

create function public.snapshot_workout_item_instructions() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op='INSERT' then
    select i.notes into new.item_instructions from public.workout_sets s
      join public.workout_items i on i.id=s.item_id where s.id=new.source_set_id;
  elsif new.item_instructions is distinct from old.item_instructions then
    raise exception 'Las instrucciones de una ejecución son inmutables.';
  end if;
  return new;
end $$;
create trigger snapshot_workout_item_instructions before insert or update
on public.workout_execution_sets for each row
execute function public.snapshot_workout_item_instructions();
revoke all on function public.snapshot_workout_item_instructions() from public,anon,authenticated;

create function public.performance_warm_up_instructions_v1(session jsonb) returns text
language plpgsql immutable set search_path = '' as $$
declare w jsonb; patterns jsonb:='[]'; output text;
begin
  for w in select value from jsonb_array_elements(coalesce(session->'work','[]')) loop
    patterns:=patterns||coalesce(w->'movement_patterns','[]');
  end loop;
  output:=E'Calentamiento de esta sesión · unos 7 minutos como orientación.\n'
    ||E'1. Empieza caminando o trotando suavemente, a un ritmo que te permita hablar sin esfuerzo.\n'
    ||E'2. Mueve de forma suave y progresiva las articulaciones que vas a utilizar; evita forzar posiciones.\n';
  if patterns ?| array['horizontal_push','diagonal_push','vertical_push','horizontal_pull','vertical_pull','rope_climb','grip_hold'] then
    output:=output||E'• Hombros, codos y muñecas: movimientos controlados y preparación de los apoyos o agarres.\n';
  end if;
  if patterns ?| array['change_of_direction','reactive_agility','squat','hinge','hip_extension','unilateral_knee_dominant','plyometric_vertical','plyometric_horizontal','plyometric_lateral','plantar_flexion'] then
    output:=output||E'• Tobillos, rodillas y caderas: marcha progresiva, elevación de talones y flexiones de piernas cómodas.\n';
  end if;
  if patterns ?| array['core_anti_extension','core_anti_rotation','core_lateral','carry'] then
    output:=output||E'• Tronco y apoyos: ensaya una posición estable durante unos segundos, respirando y sin agotarte.\n';
  end if;
  output:=output||E'3. Ensaya el trabajo que viene después, de fácil a más específico:\n';
  for w in select value from jsonb_array_elements(coalesce(session->'work','[]')) loop
    output:=output||'• '||coalesce(w->>'name','Movimiento pautado')||': '||case
      when w->'movement_patterns' ?| array['change_of_direction','reactive_agility'] then
        'revisa las líneas y obstáculos; practica despacio la salida, los giros y la frenada. Aumenta gradualmente la velocidad sin buscar una marca.'
      when w->>'model'='isometric' then
        'ensaya una sujeción breve con los mismos apoyos y buena postura. Acaba antes de que cueste mantenerla.'
      when w->>'model'='rope' then
        'revisa el agarre y la técnica permitida; ensáyalos con baja exigencia antes del ascenso pautado.'
      when w->>'model' in ('power','reactive_agility') then
        'ensaya primero el gesto con baja exigencia y aumenta gradualmente la intención. Descansa antes de los intentos de calidad.'
      else 'ensaya unas pocas repeticiones con una variante o carga fácil, lejos del agotamiento.' end||E'\n';
  end loop;
  return output||'No pases al trabajo intenso si aún no ejecutas los gestos con comodidad. '
    ||'Los siete minutos son una estimación, no una obligación ni garantía. Registra la duración real.';
end $$;
revoke all on function public.performance_warm_up_instructions_v1(jsonb) from public,anon,authenticated;

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
    'records_stimulus_responses','records_penalty_seconds'])) then return false; end if;
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
  if p->>'load_mode' <> 'bodyweight' and coalesce((p->>'external_load_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'load_mode' = 'bodyweight_plus_external' and coalesce((p->>'body_mass_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'target_rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (p->>'target_rir')::numeric > 10) then return false; end if;
  foreach k in array array['records_stimulus_responses','records_penalty_seconds'] loop
    if p ? k and jsonb_typeof(p->k)<>'boolean' then return false; end if;
  end loop;
  if p->>'records_stimulus_responses'='true' and m not in ('TIME_FOR_COURSE','PASS_FAIL') then return false; end if;
  if p->>'records_penalty_seconds'='true' and m<>'TIME_FOR_COURSE' then return false; end if;
  return true;
exception when others then return false;
end $$;

create or replace function public.calculate_preparation_week_core(p_goal_id uuid,p_week_start date,p_revision boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype; ctx public.performance_training_contexts%rowtype;
  existing public.preparation_week_decisions%rowtype; previous public.preparation_week_decisions%rowtype;
  ref record; history jsonb; prior jsonb; proposal jsonb; proposals jsonb:='[]'; pending jsonb:='[]';
  occupied jsonb; loads jsonb; candidate jsonb; best jsonb; running jsonb; best_running jsonb;
  rotation int; score int; best_score int:=-1; d int; session jsonb; blocked boolean; has_running boolean;
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
   else proposal:=public.performance_task_v1(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end); end if;
   -- Cualquier molestia posterior al contexto pausa, aunque haya resultados buenos después.
   if exists(select 1 from jsonb_array_elements(history) h
     where (h->>'completed_on')::date>=ctx.observed_at::date and
       (h->>'abandonment_reason'='discomfort' or exists(select 1 from jsonb_array_elements(h->'sets') rs
         where rs->'result'->>'stop_reason'='discomfort' or rs->'result'->>'tolerated'='false'))) then
     proposal:=jsonb_build_object('status','blocked','reason','Actualiza el contexto después de las molestias registradas.'); end if;
   proposal:=proposal||jsonb_build_object('reference_id',ref.id,'objective_key',ref.objective_key,
     'name',ref.definition->>'name','role',ref.reference->>'role','exercise_code',ref.definition->>'code');
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
   candidate:=public.performance_place_v1(proposals,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
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
   if running is not null then score:=score+1000+coalesce((select sum((s->>'minutes')::int) from jsonb_array_elements(running->'sessions') s),0); end if;
   if score>best_score then best:=candidate; best_running:=running; best_score:=score; best_error:=running_error; end if;
 end loop;
 coordinated:=public.performance_coordinate_progression_v1(proposals,best_running,p_week_start);
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
 required_missing:=(jsonb_array_length(sessions)=0 and best_running is null) or exists(select 1 from jsonb_array_elements(pending) p
   where coalesce(p->>'role','specific')<>'support' and coalesce((p->>'scheduled')::int,0)=0);
 return jsonb_build_object('status',case when required_missing then 'needs_attention' else 'ready' end,
   'policy_version','preparation_coordinator_v1','week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

create or replace function public.publish_preparation_week(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); plan jsonb; saved public.preparation_week_decisions%rowtype;
  d_id uuid; t_id uuid; b_id uuid; i_id uuid; sw_id uuid; ex_id uuid; s jsonb; w jsonb; v jsonb;
  p jsonb; idx int; block_idx int; refs jsonb; goal_lock uuid; running_result jsonb;
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
 end loop;
 update public.preparation_week_decisions set decision=plan where id=d_id;
 return plan||jsonb_build_object('decision_id',d_id,'already_published',false);
end $$;

commit;
