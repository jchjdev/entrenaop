begin;
alter table public.running_week_decisions add column superseded_at timestamptz;
alter table public.preparation_week_decisions add column superseded_at timestamptz;
alter table public.running_week_decisions drop constraint running_week_decisions_preparation_goal_id_week_start_key;
alter table public.preparation_week_decisions drop constraint preparation_week_decisions_preparation_goal_id_week_start_key;
create unique index running_week_active on public.running_week_decisions(preparation_goal_id,week_start) where superseded_at is null;
create unique index preparation_week_active on public.preparation_week_decisions(preparation_goal_id,week_start) where superseded_at is null;

create function public.preparation_revision_session_ids(p_goal uuid,p_week date)
returns setof uuid language sql stable security definer set search_path='' as $$
 select rs.scheduled_workout_id from public.running_week_sessions rs
 join public.running_week_decisions d on d.id=rs.decision_id
 where d.preparation_goal_id=p_goal and d.week_start=p_week and d.superseded_at is null
 union
 select pw.scheduled_workout_id from public.performance_week_work pw
 join public.preparation_week_decisions d on d.id=pw.decision_id
 where d.preparation_goal_id=p_goal and d.week_start=p_week and d.superseded_at is null
$$;
revoke all on function public.preparation_revision_session_ids(uuid,date) from public,anon,authenticated;

create function public.check_preparation_week_revision(p_goal uuid,p_week date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare running_id uuid; preparation_id uuid;
begin
 if not exists(select 1 from public.preparation_goals where id=p_goal and user_id=auth.uid() and status='active') then
   raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select id into running_id from public.running_week_decisions where preparation_goal_id=p_goal and week_start=p_week and superseded_at is null;
 select id into preparation_id from public.preparation_week_decisions where preparation_goal_id=p_goal and week_start=p_week and superseded_at is null;
 if running_id is null and preparation_id is null then raise exception 'Esta semana aún no está publicada. Calcula una propuesta nueva.' using errcode='22023'; end if;
 if p_week<current_date-extract(isodow from current_date)::int+1 or p_week>current_date+28 then
   raise exception 'Solo puedes revisar una semana actual o próxima.' using errcode='22023'; end if;
 if exists(select 1 from public.scheduled_workouts sw where sw.id in (select public.preparation_revision_session_ids(p_goal,p_week))
   and (sw.user_id is distinct from auth.uid() or sw.preparation_goal_id is distinct from p_goal or sw.source<>'algorithm'
     or sw.status<>'planned' or sw.execution_id is not null or sw.scheduled_date<current_date
     or exists(select 1 from public.workout_executions e where e.template_id=sw.template_id))) then
   raise exception 'Esta semana ya tiene sesiones iniciadas, realizadas, omitidas o pasadas. Conservamos sus registros; ajusta la siguiente semana.' using errcode='22023'; end if;
 if exists(select 1 from public.running_week_decisions where preparation_goal_id=p_goal and week_start>p_week and superseded_at is null)
   or exists(select 1 from public.preparation_week_decisions where preparation_goal_id=p_goal and week_start>p_week and superseded_at is null) then
   raise exception 'Hay semanas posteriores publicadas que dependen de esta decisión. No se sustituye retroactivamente.' using errcode='22023'; end if;
 return jsonb_build_object('running_decision_id',running_id,'preparation_decision_id',preparation_id);
end $$;
revoke all on function public.check_preparation_week_revision(uuid,date) from public,anon,authenticated;


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
     'status',sw.status,'rpe',e.final_rpe,'abandonment_reason',e.abandonment_reason,
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by sw.scheduled_date),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id) sets on true
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
     'date',p_week_start+d-1,'kind','performance','name','Fuerza y rendimiento','session_order',case when exists(select 1 from jsonb_array_elements(session->'work') w where w->>'model' in ('power','course','reactive_agility','rope')) then 'performance_first' else 'running_first' end,'warm_up_seconds',420,'cool_down_seconds',180)); end if;
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

revoke all on function public.calculate_preparation_week_core(uuid,date,boolean) from public,anon,authenticated;
create or replace function public.calculate_preparation_week(p_goal_id uuid,p_week_start date)
returns jsonb language sql security definer set search_path='' as $$
 select public.calculate_preparation_week_core(p_goal_id,p_week_start,false)
$$;
create function public.preview_preparation_week_revision(p_goal_id uuid,p_week_start date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare revision jsonb;
begin
 revision:=public.check_preparation_week_revision(p_goal_id,p_week_start);
 return public.calculate_preparation_week_core(p_goal_id,p_week_start,true)||jsonb_build_object('revision',revision);
end $$;
revoke all on function public.preview_preparation_week_revision(uuid,date) from public,anon;
grant execute on function public.preview_preparation_week_revision(uuid,date) to authenticated;


create or replace function public.materialize_running_week_plan(p_goal_id uuid,p_week_start date,p_plan jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); gid uuid; existing public.running_week_decisions%rowtype;
 plan jsonb; s jsonb; segment jsonb; decision_id uuid; template_id uuid;
 block_id uuid; item_id uuid; schedule_id uuid; idx integer;
begin
 if u is null then raise exception 'Authentication required'; end if;
 select id into gid from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active' for update;
 if not found then raise exception 'Active running preparation not found'; end if;
 select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 if found then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
 plan:=p_plan;
 insert into public.running_week_decisions(user_id,preparation_goal_id,week_start,policy_version,basis,
   outcome,reference_source,reference_record_id,input_snapshot,decision)
 values(u,p_goal_id,p_week_start,plan->>'policy_version',plan->>'basis',plan->>'outcome',
   plan->>'reference_source',plan->>'reference_record_id',plan-'sessions',plan) returning id into decision_id;
 for s in select value from jsonb_array_elements(plan->'sessions') loop
   insert into public.workout_templates(name,description,origin,owner_user_id,visibility,status,estimated_duration_minutes,version)
   values(s->>'name',s->>'description','algorithm',u,'private','published',(s->>'minutes')::integer,1) returning id into template_id;
   insert into public.workout_blocks(template_id,order_index,name,format)
   values(template_id,0,s->>'name','running') returning id into block_id;
   insert into public.workout_items(block_id,exercise_id,order_index,notes)
   values(block_id,'20000000-0000-4000-8000-000000000004',0,
     (s->>'description')||' Esfuerzo orientativo máximo: '||(s->>'rpe_ceiling')||'/10.') returning id into item_id;
   idx:=0;
   for segment in select value from jsonb_array_elements(s->'segments') loop
     insert into public.workout_sets(item_id,order_index,target_duration_seconds,target_distance_meters,
       target_pace_min_seconds_per_km,target_pace_max_seconds_per_km,recovery_type,recovery_duration_seconds)
     values(item_id,idx,(segment->>'seconds')::integer,(segment->>'meters')::numeric,
       (segment->>'pace_min')::integer,(segment->>'pace_max')::integer,
       case when segment ? 'recovery_seconds' then coalesce(segment->>'recovery_type','jogging') end,(segment->>'recovery_seconds')::integer);
     idx:=idx+1;
   end loop;
   insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,
     estimated_duration_minutes,preparation_goal_id,scheduled_date,source,status)
   values(u,template_id,s->>'name',1,(s->>'minutes')::integer,p_goal_id,(s->>'date')::date,'algorithm','planned') returning id into schedule_id;
   insert into public.running_week_sessions(decision_id,scheduled_workout_id,kind,planned_minutes,variant_code,prescription)
   values(decision_id,schedule_id,s->>'kind',(s->>'minutes')::integer,s->>'variant_code',s);
 end loop;
 return plan||jsonb_build_object('decision_id',decision_id,'already_published',false);
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
   insert into public.workout_items(block_id,exercise_id,order_index)
     values(b_id,'21000000-0000-4000-8000-000000000001',0) returning id into i_id;
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
   'published_weeks',coalesce((select jsonb_agg(week_start order by week_start desc) from (select week_start from public.preparation_week_decisions where preparation_goal_id=g.id and superseded_at is null
       union select week_start from public.running_week_decisions where preparation_goal_id=g.id and superseded_at is null) active_weeks),'[]'::jsonb));
end $$;

create or replace function public.preview_running_next_week(p_goal_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_last_week date;
  v_next_week date;
  v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.preparation_goals g
    where g.id = p_goal_id and g.user_id = v_user
      and g.status = 'active'

  ) then raise exception 'Active running preparation not found'; end if;
  select max(d.week_start) into v_last_week
  from public.running_week_decisions d
  where d.superseded_at is null and d.preparation_goal_id = p_goal_id and d.user_id = v_user;
  if v_last_week is null then
    raise exception 'Publish a week before previewing its successor';
  end if;
  if exists (
    select 1 from public.running_week_decisions d
    join public.running_week_sessions rs on rs.decision_id = d.id
    join public.scheduled_workouts sw on sw.id = rs.scheduled_workout_id
    where d.superseded_at is null and d.preparation_goal_id = p_goal_id and d.week_start = v_last_week
      and sw.status in ('planned', 'in_progress')
  ) then
    raise exception 'Finish or skip the published sessions before forecasting';
  end if;
  v_next_week := v_last_week + 7;
  if exists (
    select 1 from public.running_week_decisions d
    where d.superseded_at is null and d.preparation_goal_id = p_goal_id and d.week_start = v_next_week
  ) then
    raise exception 'The next week is already published';
  end if;
  v_result := public.calculate_running_week_core(
    p_goal_id, v_next_week, false, true);
  return v_result || jsonb_build_object(
    'simulation', true, 'forecast', true, 'source_week', v_last_week);
end;
$$;


create function public.publish_preparation_week_revision(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare plan jsonb; current_plan public.preparation_week_decisions%rowtype; revision jsonb; sessions uuid[]; new_id uuid;
begin
 if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 perform 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active' for update;
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 if p_expected_proposal->'revision' is null or p_expected_proposal->'revision'='null'::jsonb then
   raise exception 'Revisa primero la propuesta de sustitución.' using errcode='22023'; end if;
 select * into current_plan from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 -- El reintento de la misma publicación no crea una tercera revisión.
 if found and current_plan.decision->'revision'=p_expected_proposal->'revision' then
   return current_plan.decision||jsonb_build_object('decision_id',current_plan.id,'already_published',true); end if;
 select coalesce(array_agg(id),'{}'::uuid[]) into sessions from public.preparation_revision_session_ids(p_goal_id,p_week_start) id;
 perform 1 from public.scheduled_workouts where id=any(sessions) order by id for update;
 revision:=public.check_preparation_week_revision(p_goal_id,p_week_start);
 plan:=public.preview_preparation_week_revision(p_goal_id,p_week_start);
 if plan->>'status'<>'ready' or plan is distinct from p_expected_proposal then
   raise exception 'Los datos o la agenda han cambiado. Recalcula y revisa la propuesta antes de sustituirla.' using errcode='22023'; end if;
 -- Se conservan decisiones, sesiones y plantillas. La agenda cancela únicamente
 -- los pendientes originales; iniciar uno de ellos comparte su candado de fila.
 update public.scheduled_workouts set status='cancelled' where id=any(sessions);
 update public.running_week_decisions set superseded_at=now() where id=(revision->>'running_decision_id')::uuid;
 update public.preparation_week_decisions set superseded_at=now() where id=(revision->>'preparation_decision_id')::uuid;
 plan:=public.publish_preparation_week(p_goal_id,p_week_start,p_expected_proposal-'revision');
 new_id:=(plan->>'decision_id')::uuid;
 plan:=plan||jsonb_build_object('revision',revision);
 update public.preparation_week_decisions set decision=plan-'decision_id'-'already_published' where id=new_id;
 return plan;
end $$;
revoke all on function public.publish_preparation_week_revision(uuid,date,jsonb) from public,anon;
grant execute on function public.publish_preparation_week_revision(uuid,date,jsonb) to authenticated;
commit;
