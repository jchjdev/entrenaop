begin;
-- Conserva el contrato previo: el consentimiento personal es por teléfono,
-- aunque el preparador utilice varias instalaciones de la misma cuenta.
alter table push_private.installations add column personal_enabled boolean not null default true;
create function push_private.channel_configuration(p_expected_owner uuid,p_id uuid,p_secret text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d jsonb;personal boolean:=false;
begin
 d:=push_private.device_state(p_expected_owner,p_id,p_secret);
 if (d->>'owned')::boolean then select personal_enabled into personal from push_private.installations where id=p_id and owner_id=auth.uid();end if;
 return push_private.configuration(p_expected_owner)||jsonb_build_object('personal_enabled',coalesce(personal,false),'installation_owned',coalesce((d->>'owned')::boolean,false));
end $$;
create function push_private.set_device_personal_delivery(p_expected_owner uuid,p_id uuid,p_secret text,p_enabled boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d jsonb;
begin
 d:=push_private.device_state(p_expected_owner,p_id,p_secret);
 if p_enabled is null then raise invalid_parameter_value;end if;
 if d is null or not coalesce((d->>'owned')::boolean,false) then raise insufficient_privilege;end if;
 update push_private.installations set personal_enabled=p_enabled where id=p_id and owner_id=auth.uid() and binding_id=(d->>'binding_id')::uuid;
 if not found then raise serialization_failure;end if;
 return push_private.channel_configuration(p_expected_owner,p_id,p_secret);
end $$;
create function push_private.register_channel_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid,p_previous_binding uuid,p_token text,p_platform text,p_professional boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous jsonb;result jsonb;
begin
 previous:=push_private.device_state(p_expected_owner,p_id,p_secret);
 if (p_professional is true and not coalesce((previous->>'owned')::boolean and (previous->>'active')::boolean,false))
  or (p_professional is null and not coalesce((previous->>'owned')::boolean,false)) then
  perform trainer_private.program_work_identity(p_expected_owner);
  if not exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled and (valid_until is null or valid_until>statement_timestamp())) then raise insufficient_privilege;end if;
 end if;
 result:=push_private.register_device(p_expected_owner,p_id,p_secret,p_binding_id,p_previous_binding,p_token,p_platform);
 if p_professional is false or not coalesce((previous->>'owned')::boolean,false) or (p_professional is true and not coalesce((previous->>'active')::boolean,false)) then
  update push_private.installations set personal_enabled=coalesce(not p_professional,false) where id=p_id and owner_id=auth.uid() and binding_id=(result->>'binding_id')::uuid;
 end if;
 return result;
end $$;
create function public.get_my_push_channel_configuration(p_expected_owner uuid,p_id uuid,p_secret text) returns jsonb
language sql stable security invoker set search_path='' as $$select push_private.channel_configuration(p_expected_owner,p_id,p_secret)$$;
create function public.set_my_device_personal_push_delivery(p_expected_owner uuid,p_id uuid,p_secret text,p_enabled boolean) returns jsonb
language sql security invoker set search_path='' as $$select push_private.set_device_personal_delivery(p_expected_owner,p_id,p_secret,p_enabled)$$;
create or replace function public.register_my_push_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid,p_previous_binding uuid,p_token text,p_platform text) returns jsonb
language sql security invoker set search_path='' as $$select push_private.register_channel_device(p_expected_owner,p_id,p_secret,p_binding_id,p_previous_binding,p_token,p_platform,false)$$;
create function public.register_my_coach_push_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid,p_previous_binding uuid,p_token text,p_platform text) returns jsonb
language sql security invoker set search_path='' as $$select push_private.register_channel_device(p_expected_owner,p_id,p_secret,p_binding_id,p_previous_binding,p_token,p_platform,true)$$;
create function public.refresh_my_push_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid,p_previous_binding uuid,p_token text,p_platform text) returns jsonb
language sql security invoker set search_path='' as $$select push_private.register_channel_device(p_expected_owner,p_id,p_secret,p_binding_id,p_previous_binding,p_token,p_platform,null)$$;
revoke all on function public.refresh_my_push_device(uuid,uuid,text,uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.refresh_my_push_device(uuid,uuid,text,uuid,uuid,text,text) to authenticated;
revoke all on function push_private.channel_configuration(uuid,uuid,text),push_private.set_device_personal_delivery(uuid,uuid,text,boolean),push_private.register_channel_device(uuid,uuid,text,uuid,uuid,text,text,boolean),
 public.get_my_push_channel_configuration(uuid,uuid,text),public.set_my_device_personal_push_delivery(uuid,uuid,text,boolean),public.register_my_coach_push_device(uuid,uuid,text,uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function push_private.channel_configuration(uuid,uuid,text),push_private.set_device_personal_delivery(uuid,uuid,text,boolean),push_private.register_channel_device(uuid,uuid,text,uuid,uuid,text,text,boolean),
 public.get_my_push_channel_configuration(uuid,uuid,text),public.set_my_device_personal_push_delivery(uuid,uuid,text,boolean),public.register_my_coach_push_device(uuid,uuid,text,uuid,uuid,text,text) to authenticated;
-- El setter inicial por cuenta no gobierna ningún envío y se retira del cliente.
revoke execute on function public.set_my_personal_push_delivery(uuid,boolean),push_private.set_personal_delivery(uuid,boolean) from authenticated;
create or replace function push_private.prepare_notice_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare q push_private.notice_jobs;p push_private.preferences;
begin
 select j.* into q from push_private.notice_jobs j join push_private.installations d on d.id=j.installation_id
 where j.id=p_id and j.claim_id=p_claim and j.lease_generation=p_generation and j.lease_until>statement_timestamp()
  and d.binding_id=p_binding and d.owner_id=j.owner_id and d.active;
 if not found or not exists(select 1 from push_private.settings where singleton and enabled) then return null;end if;
 if push_private.next_allowed(q.owner_id,statement_timestamp())>statement_timestamp() then return jsonb_build_object('kind','defer');end if;
 if q.kind in ('coachMessage','coachVideo') then
  if not exists(select 1 from push_private.coach_job_events j where j.job_id=q.id and j.generation>q.delivered_generation and j.generation<=p_generation
    and push_private.coach_event_pending(j.event_id,q.owner_id)) then return null;end if;
 elsif not exists(select 1 from push_private.installations where id=q.installation_id and owner_id=q.owner_id and personal_enabled) then return null;
 elsif q.kind='reminder' then
  select * into p from push_private.preferences where owner_id=q.owner_id;
  if not found or p.reminder_mode='off' or p.revision<>q.reminder_revision or q.expires_at<=statement_timestamp()
   or not push_private.has_training(q.owner_id,q.reminder_date) then return null;end if;
 else
  if not exists(select 1 from push_private.job_notices j join trainer_private.student_notices n on n.id=j.notice_id
   join public.trainer_client_relations r on r.id=n.relation_id join public.trainer_access a on a.trainer_id=r.trainer_id
   where j.job_id=q.id and j.generation>q.delivered_generation and j.generation<=p_generation and n.owner_id=q.owner_id
    and (n.kind<>'assignment' or exists(select 1 from public.scheduled_workouts s where s.id=n.source_id and s.user_id=n.owner_id and s.status<>'cancelled'))
    and n.read_at is null and n.created_at>statement_timestamp()-interval '24 hours' and r.client_id=q.owner_id and r.ended_at is null
    and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())) then return null;end if;
 end if;
 return jsonb_build_object('kind',q.kind,'previous_day',q.kind='reminder' and p.reminder_mode='previousDay');
end $$;
commit;
