begin;
-- Registro por cita, sin identidad Apple, credenciales ni mediciones del reloj.
create table device_private.apple_training_deliveries (
 owner_id uuid not null references auth.users(id) on delete cascade,
 scheduled_id uuid not null references public.scheduled_workouts(id) on delete restrict,
 plan_id uuid not null default gen_random_uuid() unique,
 revision text not null check(revision ~ '^[0-9a-f]{64}$'),
 snapshot jsonb not null, attempt_id uuid not null,
 session_id uuid not null, lease_until timestamptz,
 status text not null check(status in ('prepared','submitted','removed')),
 updated_at timestamptz not null default now(), primary key(owner_id,scheduled_id)
);
alter table device_private.apple_training_deliveries enable row level security;
revoke all on device_private.apple_training_deliveries from public,anon,authenticated,service_role;
-- El marcador de referencia externa serializa enlace y borrado profesional.
create trigger retain_assignment_external_reference before insert or update of scheduled_id
 on device_private.apple_training_deliveries for each row
 execute function trainer_private.retain_assignment_external_reference();
-- La explicaciÃÆ’³n genÃÆ’©rica evita atribuir una referencia Apple a Garmin.
do $$declare d text; anchor text:='if exists(select 1 from device_private.training_deliveries';begin
 d:=pg_get_functiondef('trainer_private.assignment_delete_block(uuid)'::regprocedure);
 if strpos(d,anchor)=0 then raise exception 'Revisar protecciÃÆ’³n de borrado profesional';end if;
 execute replace(d,anchor,'if exists(select 1 from device_private.apple_training_deliveries where scheduled_id=p_id) then return ''references'';end if; '||anchor);
end $$;

create function device_private.apple_training_command(p_owner uuid,p_action text,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.scheduled_workouts; d device_private.apple_training_deliveries; src jsonb;
 sid uuid; attempt uuid; today date:=(statement_timestamp() at time zone 'Europe/Madrid')::date;
begin
 if p_owner is null or auth.uid() is distinct from p_owner or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
 or not exists(select 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=p_owner
  and (not_after is null or not_after>statement_timestamp())) then
  raise exception 'account_changed' using errcode='42501';end if;
 if p_action is null or p_action not in ('list','preview','prepare','record','removal','removed') then raise invalid_parameter_value;end if;
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>3000 then raise invalid_parameter_value;end if;
 if p_action='list' then
  return jsonb_build_object('allowed',device_private.garmin_access(p_owner),
   'candidates',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',template_name,'date',scheduled_date,'source',source) order by scheduled_date,id),'[]'::jsonb)
    from (select * from public.scheduled_workouts where user_id=p_owner and source in ('coach','algorithm') and status='planned'
      and execution_id is null and scheduled_date between today and today+14
      and exists(select 1 from public.workout_blocks where template_id=scheduled_workouts.template_id and format='running')
      order by scheduled_date,id limit 60) q),
   'deliveries',(select coalesce(jsonb_agg(jsonb_build_object('id',a.scheduled_id,'plan_id',a.plan_id,'name',a.snapshot->>'name',
    'date',a.snapshot->>'date','revision',a.revision,'status',a.status,
    'needs_removal',s.id is null or s.status in ('cancelled','skipped'),'started',s.execution_id is not null)
    order by a.updated_at desc),'[]'::jsonb) from device_private.apple_training_deliveries a
    left join public.scheduled_workouts s on s.id=a.scheduled_id where a.owner_id=p_owner));
 end if;
 sid:=(p_input->>'scheduled_id')::uuid;
 if sid is null then raise invalid_parameter_value;end if;
 -- Mismo orden de exclusiÃÆ’³n que el motor profesional y Garmin.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 select * into s from public.scheduled_workouts where id=sid and user_id=p_owner for share;
 if not found then raise exception 'source_not_allowed' using errcode='42501';end if;
 select * into d from device_private.apple_training_deliveries where owner_id=p_owner and scheduled_id=sid for update;
 if p_action in ('prepare','removal') and d.lease_until>statement_timestamp() then
  raise exception 'connection_busy' using errcode='55P03';end if;
 if p_action in ('record','removed') and (d.plan_id is null or d.session_id is distinct from (auth.jwt()->>'session_id')::uuid
  or d.attempt_id is distinct from (p_input->>'attempt_id')::uuid or d.revision is distinct from p_input->>'revision') then
  raise exception 'stale_prescription' using errcode='40001';end if;
 if p_action in ('removal','removed') then
  if d.plan_id is null then raise exception 'source_not_allowed' using errcode='42501';end if;
  if p_action='removal' then
   update device_private.apple_training_deliveries set attempt_id=gen_random_uuid(),session_id=(auth.jwt()->>'session_id')::uuid,
    lease_until=statement_timestamp()+interval '90 seconds' where owner_id=p_owner and scheduled_id=sid returning * into d;
  end if;
  if p_action='removed' then
   update device_private.apple_training_deliveries set status='removed',lease_until=null,updated_at=now() where owner_id=p_owner and scheduled_id=sid;
  end if;
  return jsonb_build_object('plan_id',d.plan_id,'date',d.snapshot->>'date','attempt_id',d.attempt_id,'revision',d.revision);
 end if;
 if p_action='record' then
  if d.attempt_id is distinct from (p_input->>'attempt_id')::uuid or d.revision is distinct from p_input->>'revision' then
   raise exception 'stale_prescription' using errcode='40001';end if;
  update device_private.apple_training_deliveries set status='submitted',lease_until=null,updated_at=now() where owner_id=p_owner and scheduled_id=sid;
  -- Esto registra un ACK local de WorkoutKit, nunca recepciÃÆ’³n fÃÆ’­sica ni ejecuciÃÆ’³n.
  return jsonb_build_object('recorded',true,'needs_removal',s.status in ('cancelled','skipped'));
 end if;
 if not device_private.garmin_access(p_owner) then raise exception 'access_required' using errcode='42501';end if;
 if s.scheduled_date not between today and today+14 then raise exception 'date_outside_window' using errcode='22023';end if;
 src:=device_private.training_source(p_owner,p_owner,sid);
 if not exists(select 1 from public.workout_blocks where template_id=s.template_id and format='running') then
  raise exception 'unsupported_prescription' using errcode='22023';end if;
 if p_action='preview' then return src;end if;
 if p_action<>'prepare' then raise invalid_parameter_value;end if;
 if src->>'revision' is distinct from p_input->>'revision' then raise exception 'stale_prescription' using errcode='40001';end if;
 attempt:=(p_input->>'attempt_id')::uuid;if attempt is null then raise invalid_parameter_value;end if;
 insert into device_private.apple_training_deliveries(owner_id,scheduled_id,revision,snapshot,attempt_id,status,session_id,lease_until)
  values(p_owner,sid,src->>'revision',src->'snapshot',attempt,'prepared',(auth.jwt()->>'session_id')::uuid,statement_timestamp()+interval '90 seconds')
  on conflict(owner_id,scheduled_id) do update set revision=excluded.revision,snapshot=excluded.snapshot,
   attempt_id=excluded.attempt_id,status='prepared',session_id=excluded.session_id,lease_until=excluded.lease_until,updated_at=now()
  returning * into d;
 return src||jsonb_build_object('plan_id',d.plan_id,'attempt_id',d.attempt_id);
end $$;
revoke all on function device_private.apple_training_command(uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function device_private.apple_training_command(uuid,text,jsonb) to authenticated;
create function public.apple_training_command(p_owner uuid,p_action text,p_input jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$
 select device_private.apple_training_command(p_owner,p_action,p_input);
$$;
revoke all on function public.apple_training_command(uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.apple_training_command(uuid,text,jsonb) to authenticated;
commit;
