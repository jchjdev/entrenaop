begin;

create schema editor_private;
revoke all on schema editor_private from public,anon;
grant usage on schema editor_private to authenticated;

create table editor_private.exercise_preference_owners (
 user_id uuid not null references public.profiles(id) on delete cascade,
 context text not null check(context in ('admin_official','trainer_private')),
 write_revision bigint not null default 0 check(write_revision>=0),
 primary key(user_id,context)
);
-- No hay FK al ejercicio: retirar/borrar una referencia no borra la preferencia
-- ni reinicia su CAS. La lectura devuelve solo la intersección autorizada actual.
create table editor_private.exercise_preferences (
 user_id uuid not null,context text not null,exercise_id uuid not null,
 favorite boolean not null default false,favorite_revision bigint not null default 0 check(favorite_revision>=0),
 last_selected_at timestamptz,
 primary key(user_id,context,exercise_id),
 foreign key(user_id,context) references editor_private.exercise_preference_owners(user_id,context) on delete cascade
);
create index editor_exercise_favorites on editor_private.exercise_preferences(user_id,context,exercise_id) where favorite;
create index editor_exercise_recents on editor_private.exercise_preferences(user_id,context,last_selected_at desc,exercise_id desc) where last_selected_at is not null;
create table editor_private.exercise_preference_writes (
 user_id uuid not null,context text not null,operation_id uuid not null,
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=2048),
 result jsonb not null,
 primary key(user_id,context,operation_id),
 foreign key(user_id,context) references editor_private.exercise_preference_owners(user_id,context) on delete cascade
);
alter table editor_private.exercise_preference_owners enable row level security;
alter table editor_private.exercise_preferences enable row level security;
alter table editor_private.exercise_preference_writes enable row level security;
revoke all on editor_private.exercise_preference_owners,editor_private.exercise_preferences,editor_private.exercise_preference_writes from public,anon,authenticated;

create function editor_private.require_context(p_context text) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if p_context is null or p_context not in ('admin_official','trainer_private') then raise invalid_parameter_value; end if;
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if p_context='admin_official' then
  if not public.is_admin() then raise insufficient_privilege; end if;
 elsif not exists(select 1 from public.trainer_access where trainer_id=auth.uid()) then raise insufficient_privilege;
 end if;
end $$;

create function editor_private.can_select_exercise(p_context text,p_exercise_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.exercises e where e.id=p_exercise_id
  and e.id<>'20000000-0000-4000-8000-000000000004'::uuid
  and (e.is_public or (p_context='trainer_private' and e.origin='coach' and e.created_by=auth.uid()
   and exists(select 1 from trainer_private.exercise_versions v where v.exercise_id=e.id and v.trainer_id=auth.uid() and v.current))));
$$;

create function editor_private.lock_owner(p_context text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform editor_private.require_context(p_context);
 -- La FK del propietario se fija antes del acceso y de sus preferencias.
 perform 1 from public.profiles where id=auth.uid() for key share;
 if not found then raise insufficient_privilege; end if;
 if p_context='trainer_private' then perform trainer_private.require_authoring_access();
 else
  perform 1 from public.admin_permissions where user_id=auth.uid() for key share;
  if not found then raise insufficient_privilege; end if;
 end if;
 -- Incluso sin fila previa, ON CONFLICT UPDATE detecta un escritor invisible
 -- en REPEATABLE READ. Un advisory o DO NOTHING no renovaría ese snapshot.
 insert into editor_private.exercise_preference_owners(user_id,context,write_revision) values(auth.uid(),p_context,1)
  on conflict(user_id,context) do update set write_revision=editor_private.exercise_preference_owners.write_revision+1;
end $$;

create function editor_private.preference_entry(p_context text,p_exercise_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('exercise_id',exercise_id,'favorite',favorite,'favorite_revision',favorite_revision,'last_selected_at',last_selected_at)
  from editor_private.exercise_preferences where user_id=auth.uid() and context=p_context and exercise_id=p_exercise_id;
$$;

create function editor_private.get_editor_exercise_preferences(p_context text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform editor_private.require_context(p_context);
 select coalesce(jsonb_agg(jsonb_build_object('exercise_id',p.exercise_id,'favorite',p.favorite,
  'favorite_revision',p.favorite_revision,'last_selected_at',p.last_selected_at) order by p.exercise_id),'[]') into result
 from editor_private.exercise_preferences p where p.user_id=auth.uid() and p.context=p_context
  and (p.favorite or p.last_selected_at is not null)
  and editor_private.can_select_exercise(p_context,p.exercise_id);
 return jsonb_build_object('entries',result,'recent_limit',20,'favorite_limit',500);
end $$;

-- El snapshot disperso no devuelve cada tombstone. Este lookup propio permite
-- recuperar su CAS sin ampliar el listado ni volver a empezar desde revisión 0.
create function editor_private.get_editor_exercise_preference(p_context text,p_exercise_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform editor_private.require_context(p_context);
 if p_exercise_id is null then raise invalid_parameter_value; end if;
 result:=editor_private.preference_entry(p_context,p_exercise_id);
 if result is not null then return result; end if;
 if not editor_private.can_select_exercise(p_context,p_exercise_id) then raise insufficient_privilege; end if;
 return jsonb_build_object('exercise_id',p_exercise_id,'favorite',false,'favorite_revision',0,'last_selected_at',null);
end $$;

create function editor_private.set_editor_exercise_favorite(p_operation_id uuid,p_context text,p_exercise_id uuid,p_favorite boolean,p_expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior editor_private.exercise_preference_writes; pref editor_private.exercise_preferences; payload jsonb; result jsonb;
begin
 if p_operation_id is null or p_exercise_id is null or p_favorite is null or p_expected_revision is null or p_expected_revision<0 then raise invalid_parameter_value; end if;
 perform editor_private.lock_owner(p_context);
 payload:=jsonb_build_object('action','favorite','exercise_id',p_exercise_id,'favorite',p_favorite,'expected_revision',p_expected_revision);
 select * into prior from editor_private.exercise_preference_writes where user_id=auth.uid() and context=p_context and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 select * into pref from editor_private.exercise_preferences where user_id=auth.uid() and context=p_context and exercise_id=p_exercise_id;
 -- Desmarcar una referencia propia conservada no consulta metadata del recurso
 -- retirado. Ningún UUID ajeno crea una preferencia por este camino.
 if not (found and not p_favorite) and not editor_private.can_select_exercise(p_context,p_exercise_id) then raise insufficient_privilege; end if;
 if coalesce(pref.favorite_revision,0)<>p_expected_revision then raise serialization_failure; end if;
 if p_favorite and not coalesce(pref.favorite,false)
  and (select count(*) from editor_private.exercise_preferences where user_id=auth.uid() and context=p_context and favorite)>=500 then
  raise exception 'Has alcanzado el límite técnico de 500 favoritos de este editor.' using errcode='54000';
 end if;
 insert into editor_private.exercise_preferences(user_id,context,exercise_id,favorite,favorite_revision)
  values(auth.uid(),p_context,p_exercise_id,p_favorite,p_expected_revision+1)
  on conflict(user_id,context,exercise_id) do update set favorite=excluded.favorite,favorite_revision=excluded.favorite_revision;
 result:=editor_private.preference_entry(p_context,p_exercise_id);
 insert into editor_private.exercise_preference_writes(user_id,context,operation_id,payload,result) values(auth.uid(),p_context,p_operation_id,payload,result);
 return result;
end $$;

create function editor_private.record_editor_exercise_selection(p_operation_id uuid,p_context text,p_exercise_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior editor_private.exercise_preference_writes; payload jsonb; result jsonb;
begin
 if p_operation_id is null or p_exercise_id is null then raise invalid_parameter_value; end if;
 perform editor_private.lock_owner(p_context);
 payload:=jsonb_build_object('action','selection','exercise_id',p_exercise_id);
 select * into prior from editor_private.exercise_preference_writes where user_id=auth.uid() and context=p_context and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 if not editor_private.can_select_exercise(p_context,p_exercise_id) then raise insufficient_privilege; end if;
 insert into editor_private.exercise_preferences(user_id,context,exercise_id,last_selected_at) values(auth.uid(),p_context,p_exercise_id,clock_timestamp())
  on conflict(user_id,context,exercise_id) do update set last_selected_at=excluded.last_selected_at;
 -- Se conserva el CAS favorito al sacar una entrada de recientes; los recibos
 -- previos siguen siendo exactos y no vuelven a insertar una selección antigua.
 update editor_private.exercise_preferences p set last_selected_at=null where p.user_id=auth.uid() and p.context=p_context and p.last_selected_at is not null
  and p.exercise_id not in(select exercise_id from editor_private.exercise_preferences where user_id=auth.uid() and context=p_context and last_selected_at is not null
   order by last_selected_at desc,exercise_id desc limit 20);
 result:=editor_private.preference_entry(p_context,p_exercise_id);
 insert into editor_private.exercise_preference_writes(user_id,context,operation_id,payload,result) values(auth.uid(),p_context,p_operation_id,payload,result);
 return result;
end $$;

revoke all on function editor_private.require_context(text),editor_private.can_select_exercise(text,uuid),editor_private.lock_owner(text),editor_private.preference_entry(text,uuid),
 editor_private.get_editor_exercise_preferences(text),editor_private.get_editor_exercise_preference(text,uuid),editor_private.set_editor_exercise_favorite(uuid,text,uuid,boolean,bigint),editor_private.record_editor_exercise_selection(uuid,text,uuid) from public,anon,authenticated;

create function public.get_editor_exercise_preferences(p_context text) returns jsonb
language sql stable security invoker set search_path='' as $$select editor_private.get_editor_exercise_preferences(p_context)$$;
create function public.get_editor_exercise_preference(p_context text,p_exercise_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select editor_private.get_editor_exercise_preference(p_context,p_exercise_id)$$;
create function public.set_editor_exercise_favorite(p_operation_id uuid,p_context text,p_exercise_id uuid,p_favorite boolean,p_expected_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select editor_private.set_editor_exercise_favorite(p_operation_id,p_context,p_exercise_id,p_favorite,p_expected_revision)$$;
create function public.record_editor_exercise_selection(p_operation_id uuid,p_context text,p_exercise_id uuid) returns jsonb
language sql security invoker set search_path='' as $$select editor_private.record_editor_exercise_selection(p_operation_id,p_context,p_exercise_id)$$;
revoke all on function public.get_editor_exercise_preferences(text),public.get_editor_exercise_preference(text,uuid),public.set_editor_exercise_favorite(uuid,text,uuid,boolean,bigint),public.record_editor_exercise_selection(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.get_editor_exercise_preferences(text),public.get_editor_exercise_preference(text,uuid),public.set_editor_exercise_favorite(uuid,text,uuid,boolean,bigint),public.record_editor_exercise_selection(uuid,text,uuid),
 editor_private.get_editor_exercise_preferences(text),editor_private.get_editor_exercise_preference(text,uuid),editor_private.set_editor_exercise_favorite(uuid,text,uuid,boolean,bigint),editor_private.record_editor_exercise_selection(uuid,text,uuid) to authenticated;

commit;
