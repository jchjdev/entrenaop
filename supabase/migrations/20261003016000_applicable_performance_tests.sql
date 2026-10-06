begin;
-- Una evaluación resuelve categoría/edad con sus reglas oficiales. Entrenamiento
-- reutiliza ese contexto; no vuelve a calcular edades con otra convención.
create function public.performance_test_applies(p_goal uuid,p_test uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.preparation_goals g
   join public.program_assessment_tests t on t.program_id=g.program_id and t.id=p_test
   left join lateral(select a.category,(a.result->>'age')::int age_value
     from public.program_assessment_attempts a where a.preparation_goal_id=g.id
     order by a.assessed_on desc,a.created_at desc limit 1) a on true
   where g.id=p_goal and g.user_id=auth.uid()
     and (a.category is null or t.category in ('both',a.category))
     and (a.age_value is null or a.age_value between t.min_age and t.max_age))
$$;
create function public.performance_reference_applies(p_goal uuid,p_test uuid,p_objective text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
begin
 if p_test is not null then return public.performance_test_applies(p_goal,p_test); end if;
 if p_objective like 'legacy:%' then
   return exists(select 1 from public.preparation_goals g join public.performance_legacy_objectives o
     on o.program_id=g.program_id and o.objective_key=p_objective join public.profiles p on p.id=g.user_id
     where g.id=p_goal and g.user_id=auth.uid() and (o.max_age_exclusive is null or
       coalesce(extract(year from age(coalesce(g.target_date,current_date),p.fecha_nacimiento)),0)<o.max_age_exclusive));
 end if;
 return exists(select 1 from public.preparation_goals where id=p_goal and user_id=auth.uid());
end $$;
revoke all on function public.performance_test_applies(uuid,uuid),public.performance_reference_applies(uuid,uuid,text)
 from public,anon,authenticated;

create or replace function public.get_preparation_training_setup(p_goal_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare g public.preparation_goals%rowtype; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=g.id order by a.assessed_on desc,a.created_at desc limit 1;
 return jsonb_build_object('has_running',g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry')
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or exists(select 1 from public.running_intake_contexts where preparation_goal_id=g.id),'goal_id',g.id,'target_date',g.target_date,'category',selected_category,
   'context',(select to_jsonb(c)-'user_id' from public.performance_training_contexts c where c.user_id=auth.uid()),
   'running_context',(select to_jsonb(c)-'preparation_goal_id' from public.running_intake_contexts c where c.preparation_goal_id=g.id),
   'catalog',coalesce((select jsonb_agg(jsonb_build_object('definition',ep.definition,'version',ep.definition_version) order by ep.definition->>'name')
     from public.exercise_training_profiles ep where exists(select 1 from public.exercises ex
       where ex.training_profile_code=ep.code and ex.training_profile_version=ep.definition_version and ex.is_public)),'[]'::jsonb),
   'references',coalesce((select jsonb_agg(to_jsonb(r)-'user_id' order by r.created_at) from public.performance_training_references r where r.preparation_goal_id=g.id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key)),'[]'::jsonb),
   'objectives',coalesce((select jsonb_agg(jsonb_build_object('objective_key',t.id::text,'test_id',t.id,'name',t.name,'category',t.category,
       'profile_code',b.profile_code,'profile_version',b.profile_version,'measurement',b.measurement_mode,
       'protocol_key','program_test_'||t.id::text,'protocol_version',t.definition_version,'instructions',t.protocol_notes,
       'parameters',b.training_parameters) order by t.display_order)
     from public.program_test_training_bindings b join public.program_assessment_tests t on t.id=b.test_id
     where b.program_id=g.program_id and public.performance_test_applies(g.id,t.id) and (selected_category is null or t.category in ('both',selected_category))),'[]'::jsonb) || coalesce((select jsonb_agg(to_jsonb(o)||jsonb_build_object('program_objective_key',o.objective_key))
       from public.performance_legacy_objectives o where o.program_id=g.program_id and
       (o.max_age_exclusive is null or coalesce((select extract(year from age(coalesce(g.target_date,current_date),fecha_nacimiento)) from public.profiles where id=auth.uid()),0)<o.max_age_exclusive)),'[]'::jsonb),
   'relations',(select jsonb_agg(to_jsonb(r)) from public.performance_exercise_relations r where policy_version='performance_v1'),
   'published_weeks',coalesce((select jsonb_agg(week_start order by week_start desc) from public.preparation_week_decisions where preparation_goal_id=g.id),'[]'::jsonb));
end $$;


create or replace function public.calculate_preparation_week(p_goal_id uuid,p_week_start date)
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
 select * into existing from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start;
 if found then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<current_date-extract(isodow from current_date)::int+1
   or p_week_start>current_date+28 then raise exception 'Elige una semana actual o próxima.' using errcode='22023'; end if;
 select * into previous from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start order by week_start desc limit 1;
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
 if jsonb_array_length(proposals)=0 then return jsonb_build_object('status','needs_calibration',
   'reason','Añade una referencia real para los objetivos de tu preparación.','sessions','[]'::jsonb); end if;
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
   from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6 and status not in ('cancelled','skipped');
 select coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
     and sw.status not in ('cancelled','skipped') and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry');
 for rotation in 0..6 loop
   candidate:=public.performance_place_v1(proposals,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
   running:=null; running_error:=null;
   if has_running then
     begin
       running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
         jsonb_build_object('availability',candidate->'remaining','strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days'));
     if jsonb_array_length(coalesce(running->'sessions','[]'))=0 then
         running_error:='No cabe una sesión de carrera compatible. Revisa disponibilidad y referencias.'; running:=null;
       elsif exists(select 1 from jsonb_array_elements(running->'sessions') rs where
         (rs->>'minutes')::int>coalesce((candidate->'remaining'->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)) then
         running_error:='La carrera ya publicada supera la disponibilidad actual. Revisa la agenda antes de añadir fuerza.'; running:=null;
       end if;
     exception when others then running_error:='Completa o actualiza el cuestionario y la referencia de carrera. Si ya están confirmados, revisa el tiempo disponible.'; end;
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
     'date',p_week_start+d-1,'kind','performance','name','Fuerza y rendimiento','session_order',case when exists(select 1 from jsonb_array_elements(session->'work') w where w->>'model' in ('power','course','reactive_agility','rope')) then 'performance_first' else 'running_first' end,'warm_up_seconds',420,'cool_down_seconds',180)); end if;
 end loop;
 required_missing:=jsonb_array_length(sessions)=0 or exists(select 1 from jsonb_array_elements(pending) p
   where coalesce(p->>'role','specific')<>'support' and coalesce((p->>'scheduled')::int,0)=0);
 return jsonb_build_object('status',case when required_missing then 'needs_attention' else 'ready' end,
   'policy_version','preparation_coordinator_v1','week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;
create or replace function public.guard_performance_reference_protocol() returns trigger
language plpgsql set search_path = '' as $$
declare binding public.program_test_training_bindings%rowtype; t public.program_assessment_tests%rowtype;
begin
 if not public.performance_reference_applies(new.preparation_goal_id,new.test_id,new.objective_key) then
   raise exception 'Esta prueba no corresponde a la categoría o edad de tu preparación actual.' using errcode='22023'; end if;
 if new.test_id is null then return new; end if;
 select * into binding from public.program_test_training_bindings where test_id=new.test_id;
 select * into t from public.program_assessment_tests where id=new.test_id;
 if new.reference->>'role'='specific' then
   if new.reference->'task'->>'protocol_key' is distinct from 'program_test_'||t.id::text
     or new.reference->'task'->>'protocol_version' is distinct from t.definition_version::text then
     raise exception 'La referencia específica debe conservar el protocolo del programa.' using errcode='22023'; end if;
   if binding.measurement_mode='REPS_IN_TIME' and (binding.training_parameters->>'fixed_duration_seconds' is null
      or new.reference->'task'->'fixed_duration_seconds' is distinct from binding.training_parameters->'fixed_duration_seconds') then
     raise exception 'La ventana de trabajo debe coincidir con la prueba.' using errcode='22023'; end if;
   if binding.measurement_mode='TIME_FOR_DISTANCE' and (binding.training_parameters->>'fixed_distance_meters' is null
      or new.reference->'task'->'fixed_distance_meters' is distinct from binding.training_parameters->'fixed_distance_meters') then
     raise exception 'El trayecto debe coincidir con la prueba.' using errcode='22023'; end if;
 end if;
 return new;
end $$;
commit;
