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
