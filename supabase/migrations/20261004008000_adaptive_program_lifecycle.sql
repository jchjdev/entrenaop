begin;
-- Estado del programa y continuidad autorizada al activar la primera propuesta.
create table public.adaptive_program_states (
 preparation_goal_id uuid primary key references public.preparation_goals(id) on delete cascade,
 objective_targets jsonb not null default '{}' check(jsonb_typeof(objective_targets)='object'),
 auto_advance boolean not null default false,
 status text not null default 'draft' check(status in ('draft','training','needs_review','complete')),
 message text,
 started_week date,
 last_generated_week date,
 last_error_code text,
 policy_version text not null default 'adaptive_program_v1',
 updated_at timestamptz not null default now()
);
alter table public.adaptive_program_states enable row level security;
revoke all on public.adaptive_program_states from public,anon,authenticated;
grant select on public.adaptive_program_states to authenticated;
create policy adaptive_program_read_own on public.adaptive_program_states for select to authenticated
 using(exists(select 1 from public.preparation_goals g where g.id=preparation_goal_id and g.user_id=auth.uid()));

create function public.preparation_week_closed(p_goal_id uuid,p_week date) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid())
 and exists(select 1 from public.scheduled_workouts where preparation_goal_id=p_goal_id and scheduled_date between p_week and p_week+6)
 and not exists(select 1 from public.scheduled_workouts where preparation_goal_id=p_goal_id and scheduled_date between p_week and p_week+6 and status in ('planned','in_progress'))
$$;

create function public.preparation_can_advance(p_goal_id uuid,p_week date) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.adaptive_program_states a join public.preparation_goals g on g.id=a.preparation_goal_id
 where g.id=p_goal_id and g.user_id=auth.uid() and g.status='active' and a.auto_advance)
 and p_week<=current_date-extract(isodow from current_date)::int+8
 and public.preparation_week_closed(p_goal_id,p_week-7)
$$;

create function public.save_adaptive_program_preferences(p_goal_id uuid,p_target_date date,p_targets jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare setup jsonb; obj jsonb; item record; n numeric;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if auth.uid() is null or not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then
  raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 if p_target_date is null or p_target_date<current_date or p_target_date>(current_date+interval '1 year')::date then
  raise exception 'Elige la fecha de la prueba dentro de los próximos doce meses.' using errcode='22023'; end if;
 if p_targets is null or jsonb_typeof(p_targets)<>'object' then raise exception 'Objetivos no válidos.'; end if;
 setup:=public.get_preparation_training_setup(p_goal_id);
 for item in select * from jsonb_each(p_targets) loop
  select value into obj from jsonb_array_elements(setup->'objectives') where value->>'objective_key'=item.key;
  n:=(item.value->>'value')::numeric;
  if obj is null or item.value->>'measurement' is distinct from obj->>'measurement' or n is null or n not between 0.01 and 100000
    or (obj->>'measurement' in ('REPS','REPS_IN_TIME') and n<>trunc(n)) then raise exception 'Revisa la marca objetivo y su unidad.' using errcode='22023'; end if;
 end loop;
 update public.preparation_goals set target_date=p_target_date where id=p_goal_id;
 insert into public.adaptive_program_states(preparation_goal_id,objective_targets) values(p_goal_id,p_targets)
 on conflict(preparation_goal_id) do update set objective_targets=excluded.objective_targets,updated_at=now();
end $$;

create function public.advance_adaptive_program(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.adaptive_program_states%rowtype; g public.preparation_goals%rowtype; previous_week date; next_week date;
 plan jsonb; reason text; total int; completed int;
begin
 -- Mismo orden de candados que la publicación y la revisión de semanas.
 perform 1 from public.profiles where id=auth.uid() for update;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into a from public.adaptive_program_states where preparation_goal_id=p_goal_id for update;
 if not found or not a.auto_advance then return coalesce(to_jsonb(a),'{}'); end if;
 select max(week_start) into previous_week from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;
 if previous_week is null then return to_jsonb(a); end if;
 if not public.preparation_week_closed(p_goal_id,previous_week) then
  update public.adaptive_program_states set status='training',message='La siguiente semana se preparará al resolver las sesiones de esta semana.',last_error_code=null where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 next_week:=greatest(previous_week+7,current_date-extract(isodow from current_date)::int+1);
 if next_week>=g.target_date then
  update public.adaptive_program_states set status='complete',message='Has llegado al final de la preparación. Revisa tus resultados.',updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 select count(*),count(*) filter(where status='completed') into total,completed from public.scheduled_workouts
 where preparation_goal_id=p_goal_id and scheduled_date between previous_week and previous_week+6;
 if completed=0 then reason:='No hay entrenamientos completados esta semana. Revisa tu situación y disponibilidad antes de continuar.';
 else
  -- Solo una semana por delante. Un registro adelantado no encadena meses ficticios.
  if next_week>current_date-extract(isodow from current_date)::int+8 then return to_jsonb(a); end if;
  begin
   plan:=public.calculate_preparation_week(p_goal_id,next_week);
   if plan->>'status'='ready' then
    plan:=public.publish_preparation_week(p_goal_id,next_week,plan);
    update public.adaptive_program_states set status='training',message='Tu próxima semana está preparada con los resultados registrados.',last_generated_week=next_week,last_error_code=null,updated_at=now()
     where preparation_goal_id=p_goal_id returning * into a;
    return to_jsonb(a);
   end if;
   reason:=coalesce(plan->>'reason','Revisa los datos pendientes antes de continuar.');
   if jsonb_array_length(coalesce(plan->'pending','[]'))>0 then reason:=coalesce(plan->'pending'->0->>'reason',reason); end if;
  exception when others then
   update public.adaptive_program_states set last_error_code=sqlstate where preparation_goal_id=p_goal_id;
   reason:='Tus resultados están guardados. Revisa los datos del programa para preparar la siguiente semana.';
  end;
 end if;
 update public.adaptive_program_states set status='needs_review',message=reason,updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
 return to_jsonb(a);
end $$;

create function public.activate_adaptive_program(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p jsonb;
begin
 if not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 if not exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id) then raise exception 'Guarda antes la fecha y los objetivos del programa.'; end if;
 p:=public.publish_preparation_week(p_goal_id,p_week_start,p_expected_proposal);
 update public.adaptive_program_states set auto_advance=true,status='training',started_week=coalesce(started_week,p_week_start),last_generated_week=p_week_start,
 message='La siguiente semana se preparará al resolver las sesiones de esta semana.',updated_at=now() where preparation_goal_id=p_goal_id;
 return p;
end $$;

create function public.advance_program_after_session() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.preparation_goal_id is not null and new.status is distinct from old.status and new.status in ('completed','abandoned','skipped')
  and exists(select 1 from public.adaptive_program_states where preparation_goal_id=new.preparation_goal_id and auto_advance)
  and exists(select 1 from public.preparation_goals where id=new.preparation_goal_id and user_id=auth.uid() and status='active') then
  begin
   perform public.advance_adaptive_program(new.preparation_goal_id);
  exception when others then
   -- Una incidencia de planificación nunca revierte el resultado del entrenamiento.
   update public.adaptive_program_states set status='needs_review',message='Resultado guardado. Revisa el programa para continuar.',last_error_code=sqlstate where preparation_goal_id=new.preparation_goal_id;
  end;
 end if;
 return new;
end $$;
create trigger advance_program_after_session after update of status on public.scheduled_workouts
 for each row execute function public.advance_program_after_session();

revoke all on function public.preparation_week_closed(uuid,date),public.preparation_can_advance(uuid,date),public.advance_program_after_session() from public,anon,authenticated;
revoke all on function public.advance_adaptive_program(uuid),public.activate_adaptive_program(uuid,date,jsonb),public.save_adaptive_program_preferences(uuid,date,jsonb) from public,anon;
grant execute on function public.advance_adaptive_program(uuid),public.activate_adaptive_program(uuid,date,jsonb),public.save_adaptive_program_preferences(uuid,date,jsonb) to authenticated;

create function public.skip_preparation_session(p_session_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 -- La omisión es explícita; nunca se infiere por pasar la fecha.
 update public.scheduled_workouts sw set status='skipped'
 where sw.id=p_session_id and sw.user_id=auth.uid() and sw.status='planned' and sw.scheduled_date<=current_date
   and exists(select 1 from public.preparation_goals g where g.id=sw.preparation_goal_id and g.user_id=auth.uid() and g.status='active')
   and sw.execution_id is null;
 if not found then raise exception 'Solo puedes marcar como no realizada una sesión pendiente hasta hoy y que no hayas empezado.' using errcode='22023'; end if;
end $$;
revoke all on function public.skip_preparation_session(uuid) from public,anon;
grant execute on function public.skip_preparation_session(uuid) to authenticated;

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
   and current_date<p_week_start-1 and not public.preparation_can_advance(p_goal_id,p_week_start) then raise exception 'Cierra la semana anterior antes de adaptar y publicar.' using errcode='22023'; end if;
 if exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id and auto_advance)
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
create or replace function public.get_preparation_training_setup(p_goal_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare g public.preparation_goals%rowtype; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=g.id order by a.assessed_on desc,a.created_at desc limit 1;
 return jsonb_build_object('has_running',g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry')
   or exists(select 1 from public.program_training_modules where program_id=g.program_id and module_key='running_2000m_v1')
   or exists(select 1 from public.running_intake_contexts where preparation_goal_id=g.id),'program_state',coalesce((select to_jsonb(a)-'last_error_code' from public.adaptive_program_states a where a.preparation_goal_id=g.id),'{}'::jsonb),'pending_sessions',coalesce((select jsonb_agg(jsonb_build_object('id',sw.id,'date',sw.scheduled_date,'name',sw.template_name,'status',sw.status) order by sw.scheduled_date) from public.scheduled_workouts sw where sw.preparation_goal_id=g.id and sw.status in ('planned','in_progress') and sw.scheduled_date<=current_date),'[]'::jsonb),'goal_id',g.id,'target_date',g.target_date,'category',selected_category,
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
commit;
