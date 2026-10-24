begin;

-- Dos preparadores para el piloto acordado; cada relación consume una plaza
-- del preparador, sin modificar Pro ni las cuotas personales del alumno.
alter table public.trainer_access_settings add column max_active_trainers_per_client integer
 not null default 2 check(max_active_trainers_per_client>0);
create unique index trainer_client_active_pair on public.trainer_client_relations(trainer_id,client_id)
 where ended_at is null;
drop index public.trainer_client_one_active;

create table trainer_private.calendar_sharing (
 client_id uuid primary key references public.profiles(id) on delete cascade,
 enabled boolean not null default false,
 revision bigint not null default 1 check(revision>0),
 updated_at timestamptz not null default clock_timestamp()
);
alter table trainer_private.calendar_sharing enable row level security;
revoke all on trainer_private.calendar_sharing from public,anon,authenticated;

create function trainer_private.guard_relation_membership() returns trigger
language plpgsql security definer set search_path='' as $$
declare limit_count integer;
begin
 if tg_op='UPDATE' then
  if new.client_id is distinct from old.client_id or new.trainer_id is distinct from old.trainer_id then
   raise exception 'La identidad del vínculo no se puede sustituir.' using errcode='23514'; end if;
  if new.ended_at is not distinct from old.ended_at then return new; end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||new.client_id::text,0));
 -- Mismo orden perfil→contador que el resto de escritores del calendario.
 perform 1 from public.profiles where id=new.client_id for key share;
 if not found then raise foreign_key_violation; end if;
 -- Compartido también entre preparadores distintos: en REPEATABLE READ fuerza
 -- 40001 cuando cambió el conjunto de vínculos después de tomar el snapshot.
 insert into trainer_private.calendar_revisions(user_id,revision) values(new.client_id,1)
  on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision+1;
 if new.ended_at is null then
  if exists(select 1 from public.trainer_client_relations r where r.client_id=new.client_id
    and r.trainer_id=new.trainer_id and r.ended_at is null and r.id<>new.id) then
   raise exception 'Ya estás vinculado a este preparador.' using errcode='23505'; end if;
  select max_active_trainers_per_client into strict limit_count
   from public.trainer_access_settings where singleton;
  if (select count(*) from public.trainer_client_relations r where r.client_id=new.client_id
      and r.ended_at is null and r.id<>new.id)>=limit_count then
   raise exception 'Has alcanzado el máximo de preparadores activos.' using errcode='23514'; end if;
 elsif not exists(select 1 from public.trainer_client_relations r where r.client_id=new.client_id
     and r.ended_at is null and r.id<>new.id) then
  -- Una futura etapa no hereda una compartición que quedó sin destinatarios.
  update trainer_private.calendar_sharing set enabled=false,revision=revision+1,
   updated_at=clock_timestamp() where client_id=new.client_id and enabled;
 end if;
 return new;
end $$;
revoke all on function trainer_private.guard_relation_membership() from public,anon,authenticated;
create trigger guard_trainer_relation_membership before insert or update of trainer_id,client_id,ended_at
 on public.trainer_client_relations for each row execute function trainer_private.guard_relation_membership();

do $migration$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('trainer_private.accept_trainer_invitation(text)'::regprocedure);
 anchor:='if exists(select 1 from public.trainer_client_relations where client_id=auth.uid() and ended_at is null) then';
 if strpos(definition,anchor)=0 then raise exception 'Revisar la aceptación profesional antes de ampliar el vínculo.'; end if;
 definition:=replace(definition,anchor,
  'if exists(select 1 from public.trainer_client_relations where client_id=auth.uid() and trainer_id=invite.trainer_id and ended_at is null) then');
 definition:=replace(definition,'Ya tienes un preparador activo.','Ya estás vinculado a este preparador.');
 execute definition;
end $migration$;

create function trainer_private.my_calendar_sharing(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v trainer_private.calendar_sharing;
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_owner
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
 select * into v from trainer_private.calendar_sharing where client_id=auth.uid();
 return jsonb_build_object('enabled',coalesce(v.enabled,false),'revision',coalesce(v.revision,0),
  'active_trainers',(select count(*) from public.trainer_client_relations where client_id=auth.uid() and ended_at is null),
  'max_active_trainers',(select max_active_trainers_per_client from public.trainer_access_settings where singleton));
end $$;

create function trainer_private.set_my_calendar_sharing(p_expected_owner uuid,p_enabled boolean,p_expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v trainer_private.calendar_sharing;
begin
 perform trainer_private.my_calendar_sharing(p_expected_owner);
 if p_enabled is null or p_expected_revision is null or p_expected_revision<0 then raise invalid_parameter_value; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 perform 1 from public.profiles where id=auth.uid() for key share;
 if not found then raise insufficient_privilege; end if;
 select * into v from trainer_private.calendar_sharing where client_id=auth.uid() for update;
 if v.revision=p_expected_revision+1 and v.enabled=p_enabled then
  return trainer_private.my_calendar_sharing(p_expected_owner); end if;
 if coalesce(v.revision,0)<>p_expected_revision then
  raise exception 'La compartición ha cambiado; actualiza antes de continuar.' using errcode='40001'; end if;
 if p_enabled and not exists(select 1 from public.trainer_client_relations where client_id=auth.uid() and ended_at is null) then
  raise exception 'Necesitas un preparador activo para compartir tu calendario.' using errcode='23514'; end if;
 if coalesce(v.enabled,false)=p_enabled then return trainer_private.my_calendar_sharing(p_expected_owner); end if;
 insert into trainer_private.calendar_sharing(client_id,enabled) values(auth.uid(),p_enabled)
  on conflict(client_id) do update set enabled=excluded.enabled,
   revision=trainer_private.calendar_sharing.revision+1,updated_at=clock_timestamp();
 return trainer_private.my_calendar_sharing(p_expected_owner);
end $$;

create function trainer_private.shared_calendar_access(p_expected_owner uuid,p_client_id uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is distinct from p_expected_owner or not trainer_private.has_trainer_mfa()
  or not exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled
    and (valid_until is null or valid_until>statement_timestamp()))
  or not exists(select 1 from public.trainer_client_relations where trainer_id=auth.uid()
    and client_id=p_client_id and ended_at is null) then raise insufficient_privilege; end if;
 return coalesce((select enabled from trainer_private.calendar_sharing where client_id=p_client_id),false);
end $$;
revoke all on function trainer_private.shared_calendar_access(uuid,uuid) from public,anon,authenticated;

create function trainer_private.shared_client_calendar(p_expected_owner uuid,p_client_id uuid,p_from date,p_to date,
 p_after_date date default null,p_after_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.shared_calendar_access(p_expected_owner,p_client_id) then
  return jsonb_build_object('shared',false,'items','[]'::jsonb,'has_more',false,'coaches','[]'::jsonb); end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>61
  or (p_after_date is null)<>(p_after_id is null) then raise invalid_parameter_value; end if;
 return (with page as (
  select s.id,s.scheduled_date,s.scheduled_time,s.template_name,s.estimated_duration_minutes,
   s.source,s.status,a.trainer_id=auth.uid() as is_own,
   case when s.source='coach' then coalesce(nullif(btrim(p.full_name),''),'Preparador') end as trainer_name,
   case when s.source='coach' then r.ended_at is null and r.id is not null else true end as relation_active,
   exists(select 1 from public.workout_blocks b where b.template_id=s.template_id and b.format='running') as is_running
  from public.scheduled_workouts s
  left join public.trainer_assignments a on a.scheduled_id=s.id and a.client_id=p_client_id
  left join public.trainer_client_relations r on r.id=a.relation_id
  left join public.profiles p on p.id=a.trainer_id
  where s.user_id=p_client_id and s.scheduled_date between p_from and p_to
   and (p_after_date is null or (s.scheduled_date,s.id)>(p_after_date,p_after_id))
  order by s.scheduled_date,s.id limit 51
 ), visible as (select * from page order by scheduled_date,id limit 50)
 select jsonb_build_object('shared',true,
  'items',coalesce((select jsonb_agg(to_jsonb(v) order by scheduled_date,id) from visible v),'[]'::jsonb),
  'has_more',(select count(*)>50 from page),
  'coaches',coalesce((select jsonb_agg(jsonb_build_object('name',coalesce(nullif(btrim(p.full_name),''),'Preparador'),
     'is_you',r.trainer_id=auth.uid()) order by r.accepted_at,r.id)
    from public.trainer_client_relations r join public.profiles p on p.id=r.trainer_id
    where r.client_id=p_client_id and r.ended_at is null),'[]'::jsonb)));
end $$;

-- Pauta de esta cita, en lectura. No concede SELECT sobre el catálogo del otro
-- preparador, ni acceso a medios, resultados, conversación o notas privadas.
create function trainer_private.shared_calendar_workout(p_expected_owner uuid,p_client_id uuid,p_scheduled_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not trainer_private.shared_calendar_access(p_expected_owner,p_client_id) then raise insufficient_privilege; end if;
 select jsonb_build_object('id',t.id,'name',s.template_name,'description',t.description,
  'version',s.template_version,'estimated_duration_minutes',s.estimated_duration_minutes,
  'workout_blocks',coalesce((select jsonb_agg(jsonb_build_object(
   'id',b.id,'order_index',b.order_index,'name',b.name,'format',b.format,'rounds',b.rounds,
   'time_cap_seconds',b.time_cap_seconds,'rest_after_seconds',b.rest_after_seconds,
   'workout_items',coalesce((select jsonb_agg(jsonb_build_object(
    'id',i.id,'order_index',i.order_index,'notes',i.notes,
    'exercises',jsonb_build_object('id',e.id,'name',e.name,'description',null),
    'workout_sets',coalesce((select jsonb_agg(jsonb_build_object(
     'id',w.id,'order_index',w.order_index,'target_reps',w.target_reps,
     'target_duration_seconds',w.target_duration_seconds,'target_distance_meters',w.target_distance_meters,
     'target_load_kg',w.target_load_kg,'target_rpe',w.target_rpe,'target_rir',w.target_rir,
     'target_pace_min_seconds_per_km',w.target_pace_min_seconds_per_km,
     'target_pace_max_seconds_per_km',w.target_pace_max_seconds_per_km,
     'recovery_type',w.recovery_type,'recovery_duration_seconds',w.recovery_duration_seconds,
     'recovery_distance_meters',w.recovery_distance_meters,'rest_after_seconds',w.rest_after_seconds,
     'performance_prescription',w.performance_prescription,'running_step',w.running_step
    ) order by w.order_index,w.id) from public.workout_sets w where w.item_id=i.id),'[]'::jsonb)
   ) order by i.order_index,i.id) from public.workout_items i join public.exercises e on e.id=i.exercise_id where i.block_id=b.id),'[]'::jsonb)
  ) order by b.order_index,b.id) from public.workout_blocks b where b.template_id=t.id),'[]'::jsonb)) into result
 from public.scheduled_workouts s join public.workout_templates t on t.id=s.template_id
 where s.id=p_scheduled_id and s.user_id=p_client_id;
 if result is null then raise insufficient_privilege; end if;
 return result;
end $$;

create function trainer_private.my_schedule_coaches(p_expected_owner uuid,p_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.my_calendar_sharing(p_expected_owner);
 if p_ids is null or cardinality(p_ids)>200 or array_position(p_ids,null) is not null then raise invalid_parameter_value; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,
   'trainer_name',coalesce(nullif(btrim(p.full_name),''),'Preparador')) order by s.id)
  from public.scheduled_workouts s join public.trainer_assignments a on a.scheduled_id=s.id
  join public.profiles p on p.id=a.trainer_id
  where s.id=any(p_ids) and s.user_id=auth.uid() and a.client_id=auth.uid() and s.source='coach'),'[]'::jsonb);
end $$;

create function public.get_my_trainer_calendar_sharing(p_expected_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.my_calendar_sharing(p_expected_owner) $$;
create function public.set_my_trainer_calendar_sharing(p_expected_owner uuid,p_enabled boolean,p_expected_revision bigint) returns jsonb
language sql volatile security invoker set search_path='' as $$ select trainer_private.set_my_calendar_sharing(p_expected_owner,p_enabled,p_expected_revision) $$;
create function public.get_trainer_shared_calendar(p_expected_owner uuid,p_client_id uuid,p_from date,p_to date,
 p_after_date date default null,p_after_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.shared_client_calendar(p_expected_owner,p_client_id,p_from,p_to,p_after_date,p_after_id) $$;
create function public.get_trainer_shared_workout(p_expected_owner uuid,p_client_id uuid,p_scheduled_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.shared_calendar_workout(p_expected_owner,p_client_id,p_scheduled_id) $$;
create function public.get_my_schedule_coaches(p_expected_owner uuid,p_ids uuid[]) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.my_schedule_coaches(p_expected_owner,p_ids) $$;

do $grants$
declare f record;
begin
 for f in select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) as args
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where
  (n.nspname='trainer_private' and p.proname in ('my_calendar_sharing','set_my_calendar_sharing','shared_client_calendar','shared_calendar_workout','my_schedule_coaches'))
  or (n.nspname='public' and p.proname in ('get_my_trainer_calendar_sharing','set_my_trainer_calendar_sharing','get_trainer_shared_calendar','get_trainer_shared_workout','get_my_schedule_coaches')) loop
  execute format('revoke all on function %I.%I(%s) from public,anon,authenticated',f.nspname,f.proname,f.args);
  execute format('grant execute on function %I.%I(%s) to authenticated',f.nspname,f.proname,f.args);
 end loop;
end $grants$;

-- Mantiene el contrato anterior y añade destinos explícitos cuando hay mensajes
-- de varios preparadores. Un cliente antiguo no elige a uno arbitrariamente.
do $notices$
declare definition text; anchor text; replacement text;
begin
 definition:=pg_get_functiondef('trainer_private.student_notice_snapshot(uuid,timestamptz,uuid,text)'::regprocedure);
 anchor:='''has_conversations'',conversation is not null,''conversation_relation_id'',conversation,';
 replacement:=$replacement$'has_conversations',conversation is not null,
 'conversation_relation_id',case when (select count(*) from public.trainer_client_relations r
   where r.client_id=auth.uid() and r.ended_at is null and exists(select 1 from trainer_private.messages m where m.relation_id=r.id))>1 then null else conversation end,
 'conversations',coalesce((select jsonb_agg(jsonb_build_object('relation_id',r.id,
    'trainer_name',coalesce(nullif(btrim(p.full_name),''),'Preparador')) order by r.accepted_at,r.id)
   from public.trainer_client_relations r join public.profiles p on p.id=r.trainer_id
   where r.client_id=auth.uid() and r.ended_at is null and exists(select 1 from trainer_private.messages m where m.relation_id=r.id)),'[]'::jsonb),$replacement$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar el contrato de recursos del alumno antes de ampliar conversaciones.'; end if;
 execute replace(definition,anchor,replacement);
end $notices$;

commit;
