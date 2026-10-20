begin;

alter table public.guided_program_follows add column paused_at timestamptz,
  add constraint guided_program_pause_nonterminal check (
    paused_at is null or (completed_at is null and abandoned_at is null));
create index guided_program_follows_active_quota_idx
  on public.guided_program_follows(user_id)
  where completed_at is null and abandoned_at is null and paused_at is null;

create function public.get_my_guided_program_access() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare pro boolean; active_count integer;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.' using errcode='42501'; end if;
  pro:=public.has_pro_access(auth.uid());
  select count(*) into active_count from public.guided_program_follows
    where user_id=auth.uid() and completed_at is null and abandoned_at is null and paused_at is null;
  return jsonb_build_object('is_pro',pro,'active_programs',active_count,
    'active_limit',case when pro then null else 1 end);
end $$;
revoke all on function public.get_my_guided_program_access() from public,anon;
grant execute on function public.get_my_guided_program_access() to authenticated;

create function public.set_guided_program_paused(p_follow_id uuid,p_paused boolean)
returns void language plpgsql security definer set search_path='' as $$
declare f public.guided_program_follows;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.' using errcode='42501'; end if;
  if p_paused is null then raise exception 'Revisa el cambio de programa.' using errcode='22023'; end if;
  -- Mismo candado y orden que iniciar, abandonar y ejecutar; también serializa dos activaciones.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,17));
  select * into f from public.guided_program_follows where id=p_follow_id and user_id=auth.uid() for update;
  if not found then raise exception 'Seguimiento no disponible.' using errcode='42501'; end if;
  if f.completed_at is not null or f.abandoned_at is not null then
    raise exception 'Este seguimiento ha terminado. Puedes iniciarlo de nuevo desde su ficha.' using errcode='22023';
  end if;
  if p_paused=(f.paused_at is not null) then return; end if;
  if exists(select 1 from public.guided_program_runs r join public.workout_executions e on e.id=r.execution_id
    where r.follow_id=f.id and e.status='in_progress') then
    raise exception 'Termina o abandona la sesión en curso antes de pausar el programa.' using errcode='22023';
  end if;
  if not p_paused and not public.has_pro_access(auth.uid()) and exists(
    select 1 from public.guided_program_follows where user_id=auth.uid()
      and completed_at is null and abandoned_at is null and paused_at is null) then
    raise exception 'Free incluye un programa activo. Pausa el actual para retomar este o accede a Pro para mantener varios.'
      using errcode='P0001',detail='free_guided_program_limit';
  end if;
  update public.guided_program_follows set paused_at=case when p_paused then clock_timestamp() else null end where id=f.id;
end $$;
revoke all on function public.set_guided_program_paused(uuid,boolean) from public,anon;
grant execute on function public.set_guided_program_paused(uuid,boolean) to authenticated;

create or replace function public.follow_guided_program(p_program_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare f public.guided_program_follows; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,17));
  select * into f from public.guided_program_follows where user_id=auth.uid()
    and program_id=p_program_id and completed_at is null and abandoned_at is null;
  if found then
    if f.paused_at is not null then perform public.set_guided_program_paused(f.id,false); end if;
    return f.id;
  end if;
  perform 1 from public.guided_programs where id=p_program_id and status='published' for share;
  if not found then raise exception 'El programa no está disponible.' using errcode='22023'; end if;
  if not public.has_pro_access(auth.uid()) and exists(
    select 1 from public.guided_program_follows where user_id=auth.uid()
      and completed_at is null and abandoned_at is null and paused_at is null) then
    raise exception 'Free incluye un programa activo. Pausa el actual para iniciar otro o accede a Pro para mantener varios.'
      using errcode='P0001',detail='free_guided_program_limit';
  end if;
  insert into public.guided_program_follows(user_id,program_id) values(auth.uid(),p_program_id) returning id into v_id;
  return v_id;
end $$;

create or replace function public.abandon_guided_program(p_follow_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare f public.guided_program_follows;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,17));
  select * into f from public.guided_program_follows where id=p_follow_id and user_id=auth.uid() for update;
  if not found then raise exception 'Seguimiento no disponible.' using errcode='42501'; end if;
  if f.abandoned_at is not null or f.completed_at is not null then return; end if;
  if exists(select 1 from public.guided_program_runs r join public.workout_executions e on e.id=r.execution_id
    where r.follow_id=f.id and e.status='in_progress') then
    raise exception 'Termina o abandona la sesión en curso antes de dejar el programa.' using errcode='22023';
  end if;
  update public.guided_program_follows set abandoned_at=clock_timestamp(),paused_at=null where id=f.id;
end $$;
create or replace function public.advance_guided_program(p_follow_id uuid,p_expected_phase integer)
returns void language plpgsql security definer set search_path='' as $$
declare f public.guided_program_follows; p public.guided_programs;
begin
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,17));
  select * into f from public.guided_program_follows where id=p_follow_id and user_id=auth.uid() for update;
  if not found then raise exception 'Seguimiento no disponible.' using errcode='42501'; end if;
  if f.paused_at is not null then raise exception 'Retoma el programa antes de avanzar.' using errcode='22023'; end if;
  if f.abandoned_at is not null then
    raise exception 'El programa ha sido abandonado.' using errcode='22023';
  end if;
  select * into p from public.guided_programs where id=f.program_id;
  if p.content->>'mode'<>'phased' then raise exception 'Una guía se repite sin cambio de fase.' using errcode='22023'; end if;
  -- Repetir una confirmación ya aceptada no consume otra fase.
  if f.completed_at is not null or p_expected_phase<f.phase_index then return; end if;
  if p_expected_phase is null or p_expected_phase<>f.phase_index then
    raise exception 'El progreso ha cambiado. Vuelve a cargarlo.' using errcode='22023';
  end if;
  if exists(select 1 from public.guided_program_runs r join public.workout_executions e on e.id=r.execution_id
    where r.follow_id=f.id and e.status='in_progress') then
    raise exception 'Resuelve la sesión en curso antes de avanzar.' using errcode='22023';
  end if;
  if f.phase_index+1>=jsonb_array_length(p.content->'phases') then
    update public.guided_program_follows set completed_at=now() where id=f.id;
  else update public.guided_program_follows set phase_index=phase_index+1 where id=f.id;
  end if;
end $$;

create or replace function public.start_guided_program_session(
  p_program_id uuid,p_phase_index integer,p_session_index integer,p_operation_id uuid,
  p_omit_warmup boolean default false,p_rest_seconds integer default null
)
returns uuid language plpgsql security definer set search_path='' as $$
declare f public.guided_program_follows; p public.guided_programs;
  r public.guided_program_runs; link public.guided_program_links; slot jsonb;
  source public.workout_templates; b public.workout_blocks; i public.workout_items; s public.workout_sets;
  template uuid:=gen_random_uuid(); execution uuid; warmup_template uuid; source_id uuid;
  block_id uuid; item_id uuid; block_position integer:=0; rest_delta integer:=0; warmup_minutes integer:=0; result_id uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.' using errcode='42501'; end if;
  if p_operation_id is null or p_phase_index is null or p_session_index is null
    or p_phase_index<0 or p_session_index<0 or p_omit_warmup is null then
    raise exception 'Revisa la sesión solicitada.' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,17));
  select * into r from public.guided_program_runs where user_id=auth.uid() and operation_id=p_operation_id;
  if found then
    if not exists(select 1 from public.guided_program_follows where id=r.follow_id and program_id=p_program_id)
      or r.phase_index<>p_phase_index or r.session_index<>p_session_index
      or r.omitted_warmup<>p_omit_warmup or r.rest_seconds is distinct from p_rest_seconds then
      raise exception 'El reintento debe conservar la sesión y sus ajustes.' using errcode='22023';
    end if;
    if r.execution_id is null then raise exception 'La ejecución fue descartada. Abre de nuevo la sesión.' using errcode='22023'; end if;
    return r.execution_id;
  end if;
  select * into f from public.guided_program_follows where user_id=auth.uid() and program_id=p_program_id
    and completed_at is null and abandoned_at is null for update;
  if not found then raise exception 'Sigue el programa antes de entrenar.' using errcode='42501'; end if;
  if f.paused_at is not null then raise exception 'Retoma el programa desde su ficha antes de entrenar.' using errcode='22023'; end if;
  if f.completed_at is not null or f.phase_index<>p_phase_index then
    raise exception 'Esta sesión no pertenece a tu fase actual.' using errcode='22023';
  end if;
  select * into p from public.guided_programs where id=f.program_id;
  select * into link from public.guided_program_links where program_id=p.id and phase_index=p_phase_index and session_index=p_session_index;
  if not found then raise exception 'La sesión no existe en este programa.' using errcode='22023'; end if;
  -- Otra pestaña debe retomar la ejecución en curso y conservar sus ajustes.
  select r0.* into r from public.guided_program_runs r0 join public.workout_executions e on e.id=r0.execution_id
    where r0.follow_id=f.id and e.status='in_progress' order by r0.created_at desc limit 1;
  if found then
    if r.phase_index<>p_phase_index or r.session_index<>p_session_index then
      raise exception 'Retoma o resuelve primero la otra sesión de este programa.' using errcode='22023';
    end if;
    return r.execution_id;
  end if;
  slot:=p.content->'phases'->p_phase_index->'sessions'->p_session_index;
  if p_rest_seconds is not null and ((slot->'rest'->>'min_seconds') is null
    or (slot->'rest'->>'max_seconds') is null
    or p_rest_seconds<(slot->'rest'->>'min_seconds')::integer
    or p_rest_seconds>(slot->'rest'->>'max_seconds')::integer) then
    raise exception 'Ese descanso no está permitido por la pauta.' using errcode='22023';
  end if;
  select * into source from public.workout_templates where id=link.template_id;
  insert into public.workout_templates select (jsonb_populate_record(null::public.workout_templates,
    to_jsonb(source)||jsonb_build_object('id',template,'family_id',template,'previous_version_id',null,
      'origin','algorithm','owner_user_id',auth.uid(),'visibility','private','status','published','created_at',now(),'updated_at',now()))).*;
  if link.warmup_id is not null then
    select w.template_id,coalesce(t.estimated_duration_minutes,0) into warmup_template,warmup_minutes
      from public.guided_warmups w join public.workout_templates t on t.id=w.template_id where w.id=link.warmup_id;
  end if;
  -- Se copia la prescripción completa, incluidos campos de formatos actuales.
  -- El ejecutor recibe sus contratos habituales, sin un segundo reloj o motor.
  foreach source_id in array case when warmup_template is null then array[link.template_id] else array[warmup_template,link.template_id] end loop
    for b in select * from public.workout_blocks where template_id=source_id order by order_index loop
      block_id:=gen_random_uuid();
      insert into public.workout_blocks select (jsonb_populate_record(null::public.workout_blocks,
        to_jsonb(b)||jsonb_build_object('id',block_id,'template_id',template,'order_index',block_position))).*;
      block_position:=block_position+1;
      for i in select q.* from public.workout_items q where q.block_id=b.id order by q.order_index loop
        item_id:=gen_random_uuid();
        insert into public.workout_items select (jsonb_populate_record(null::public.workout_items,
          to_jsonb(i)||jsonb_build_object('id',item_id,'block_id',block_id))).*;
        for s in select q.* from public.workout_sets q where q.item_id=i.id order by q.order_index loop
          if p_rest_seconds is not null and b.format='straight_sets' then rest_delta:=rest_delta+p_rest_seconds-s.rest_after_seconds; end if;
          insert into public.workout_sets select (jsonb_populate_record(null::public.workout_sets,
            to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'item_id',item_id,
              'rest_after_seconds',case when p_rest_seconds is not null and b.format='straight_sets' then p_rest_seconds else s.rest_after_seconds end))).*;
        end loop;
      end loop;
    end loop;
  end loop;
  if source.estimated_duration_minutes is not null then
    update public.workout_templates set estimated_duration_minutes=greatest(1,source.estimated_duration_minutes+
      case when p_omit_warmup then 0 else warmup_minutes end+ceil(rest_delta/60.0)::integer) where id=template;
  end if;
  execution:=public.start_workout_execution(template);
  if p_omit_warmup then
    for result_id in select id from public.workout_execution_sets where execution_id=execution and block_format='warm_up' loop
      perform public.skip_workout_set(result_id);
    end loop;
  end if;
  insert into public.guided_program_runs(user_id,follow_id,operation_id,phase_index,session_index,omitted_warmup,rest_seconds,template_id,execution_id)
    values(auth.uid(),f.id,p_operation_id,p_phase_index,p_session_index,p_omit_warmup,p_rest_seconds,template,execution);
  return execution;
end $$;

commit;
