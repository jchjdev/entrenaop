begin;
insert into public.exercises(id,name,description,muscle_groups,equipment,difficulty,exercise_type,is_public,created_by,origin)
values
 ('21000000-0000-4000-8000-000000000001','Calentamiento para fuerza y rendimiento',
  'Empieza con movimiento suave y movilidad dinámica de las regiones de la sesión. Ensaya después los gestos con una variante o carga fácil, sin acercarte al fallo. Antes de saltos, giros o trepa, prepara progresivamente sus apoyos y agarres. Registra el tiempo real; siete minutos son una reserva inicial, no una garantía de preparación suficiente.',
  array['cuerpo completo'],array['peso corporal'],'inicial','duración',true,null,'system'),
 ('21000000-0000-4000-8000-000000000002','Vuelta a la calma tras fuerza y rendimiento',
  'Reduce progresivamente la actividad con movimiento suave y respiración cómoda. Registra cómo te has encontrado; no conviertas molestias en una serie completada con normalidad.',
  array['cuerpo completo'],array['peso corporal'],'inicial','duración',true,null,'system');

create function public.publish_preparation_week(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb)
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
 select * into saved from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start;
 if found then return saved.decision||jsonb_build_object('decision_id',saved.id,'already_published',true); end if;
 if exists(select 1 from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start)
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

-- La ruta antigua no puede publicar solo carrera ignorando fuerza activa.
-- Si no hay referencias de fuerza, mantiene exactamente su recorrido anterior.
create or replace function public.publish_running_week(p_goal_id uuid,p_week_start date)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if exists(select 1 from public.performance_training_references where preparation_goal_id=p_goal_id
   and user_id=auth.uid() and active) then
   raise exception 'Revisa y publica desde Fuerza y carrera para coordinar toda la semana.' using errcode='22023'; end if;
 return public.materialize_running_week_plan(p_goal_id,p_week_start,
   public.calculate_running_week_core(p_goal_id,p_week_start,false,false));
end $$;
revoke all on function public.publish_preparation_week(uuid,date,jsonb) from public,anon;
grant execute on function public.publish_preparation_week(uuid,date,jsonb) to authenticated;
commit;
