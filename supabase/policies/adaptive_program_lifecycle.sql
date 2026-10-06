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
