-- Derechos comerciales reales y cuotas. Ningún cliente puede concederse Pro.
begin;

create table public.pro_access_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  source text not null check (source = 'development_manual'),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  revocation_reason text,
  granted_by uuid references auth.users(id) on delete set null,
  reason text not null check (char_length(btrim(reason)) between 3 and 200),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index pro_access_grants_user_idx on public.pro_access_grants(user_id, ends_at);
alter table public.pro_access_grants enable row level security;
revoke all on public.pro_access_grants from public, anon, authenticated;
grant select on public.pro_access_grants to authenticated;
create policy pro_access_read_own on public.pro_access_grants for select
  to authenticated using (user_id = (select auth.uid()));

-- Se habilita expresamente en Dev mediante una operación de confianza.
-- Una migración aplicada a otro entorno no habilita concesiones manuales.
create table public.commercial_access_settings (
  singleton boolean primary key default true check (singleton),
  development_manual_access_enabled boolean not null default false
);
insert into public.commercial_access_settings(singleton) values(true);
alter table public.commercial_access_settings enable row level security;
revoke all on public.commercial_access_settings from public, anon, authenticated;

create function public.has_pro_access(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.pro_access_grants
    where user_id = p_user_id and revoked_at is null
      and starts_at <= statement_timestamp() and ends_at > statement_timestamp());
$$;
revoke all on function public.has_pro_access(uuid) from public, anon, authenticated;

create function public.require_pro_access() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión para continuar.' using errcode = '42501';
  end if;
  if not public.has_pro_access(auth.uid()) then
    raise exception 'Los programas adaptativos requieren Pro.'
      using errcode = 'P0001', detail = 'pro_required';
  end if;
end $$;
revoke all on function public.require_pro_access() from public, anon, authenticated;

create function public.pro_access_snapshot(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id', p_user_id, 'tier', case when public.has_pro_access(p_user_id) then 'pro' else 'free' end,
    'checked_at', statement_timestamp(),
    'valid_until', (select max(ends_at) from public.pro_access_grants where user_id = p_user_id
      and revoked_at is null and starts_at <= statement_timestamp() and ends_at > statement_timestamp()),
    'source', case when public.has_pro_access(p_user_id) then 'development_manual' else null end,
    'personal_exercises', (select count(*) from public.exercises where created_by = p_user_id and origin = 'user'),
    'personal_sessions', (select count(distinct family_id) from public.workout_templates
      where owner_user_id = p_user_id and origin = 'user' and status <> 'archived'),
    'exercise_limit', case when public.has_pro_access(p_user_id) then null else 8 end,
    'session_limit', case when public.has_pro_access(p_user_id) then null else 4 end
  );
$$;
revoke all on function public.pro_access_snapshot(uuid) from public, anon, authenticated;

create function public.get_my_pro_access() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Inicia sesión para consultar tu acceso.' using errcode = '42501'; end if;
  return public.pro_access_snapshot(auth.uid());
end $$;
revoke all on function public.get_my_pro_access() from public, anon;
grant execute on function public.get_my_pro_access() to authenticated;

create function public.check_development_access_admin() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(), false) then
    raise exception 'Solo administración puede gestionar cuentas de prueba.' using errcode = '42501';
  end if;
  if not coalesce((select development_manual_access_enabled from public.commercial_access_settings where singleton), false) then
    raise exception 'La gestión de cuentas de prueba está deshabilitada en este entorno.' using errcode = '42501';
  end if;
end $$;
revoke all on function public.check_development_access_admin() from public, anon, authenticated;

create function public.admin_find_development_account(p_email text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid;
begin
  perform public.check_development_access_admin();
  select id into u from auth.users where lower(email) = lower(btrim(p_email));
  if u is null then raise exception 'No existe una cuenta registrada con ese correo.' using errcode = '22023'; end if;
  return public.pro_access_snapshot(u);
end $$;

create function public.admin_set_development_pro_access(
  p_user_id uuid, p_enabled boolean, p_days integer default 30,
  p_reason text default 'Prueba de acceso Free/Pro'
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.check_development_access_admin();
  if p_enabled is null or p_days is null or p_days not between 1 and 365
     or p_reason is null or char_length(btrim(p_reason)) not between 3 and 200 then
    raise exception 'Revisa la duración y el motivo del acceso de prueba.' using errcode = '22023';
  end if;
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then raise exception 'La cuenta ya no está disponible.' using errcode = '22023'; end if;
  update public.pro_access_grants set revoked_at = statement_timestamp(),
    revoked_by = auth.uid(), revocation_reason = btrim(p_reason)
    where user_id = p_user_id and source = 'development_manual' and revoked_at is null;
  if p_enabled then
    insert into public.pro_access_grants(user_id, source, ends_at, granted_by, reason)
      values(p_user_id, 'development_manual', statement_timestamp() + make_interval(days => p_days), auth.uid(), btrim(p_reason));
  end if;
  return public.pro_access_snapshot(p_user_id);
end $$;
revoke all on function public.admin_find_development_account(text),
  public.admin_set_development_pro_access(uuid, boolean, integer, text) from public, anon;
grant execute on function public.admin_find_development_account(text),
  public.admin_set_development_pro_access(uuid, boolean, integer, text) to authenticated;

create function public.enforce_personal_exercise_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.origin <> 'user' then return new; end if;
  if tg_op = 'UPDATE' and old.origin = 'user' and old.created_by = new.created_by then return new; end if;
  -- El mismo candado serializa creaciones simultáneas y cambios de acceso.
  perform 1 from public.profiles where id = new.created_by for update;
  if not public.has_pro_access(new.created_by) and
     (select count(*) from public.exercises where origin = 'user' and created_by = new.created_by) >= 8 then
    raise exception 'Has alcanzado los 8 ejercicios propios incluidos en Free. Con Pro puedes crear más.'
      using errcode = 'P0001', detail = 'free_exercise_limit';
  end if;
  return new;
end $$;
revoke all on function public.enforce_personal_exercise_quota() from public, anon, authenticated;
create trigger enforce_personal_exercise_quota before insert or update of origin, created_by
  on public.exercises for each row execute function public.enforce_personal_exercise_quota();

create function public.enforce_personal_session_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
declare revision public.workout_templates%rowtype; revision_id text;
begin
  if new.origin <> 'user' or new.status = 'archived' then return new; end if;
  if tg_op = 'UPDATE' and old.origin = 'user' and old.status <> 'archived'
    and old.owner_user_id = new.owner_user_id and old.family_id = new.family_id then return new; end if;
  perform 1 from public.profiles where id = new.owner_user_id for update;
  if tg_op = 'INSERT' then
    revision_id := nullif(current_setting('entrenaop.revising_template', true), '');
    if revision_id is not null then
      select * into revision from public.workout_templates where id::text = revision_id
        and origin = 'user' and status <> 'archived' and owner_user_id = auth.uid()
        and owner_user_id = new.owner_user_id for update;
      if not found then raise exception 'Revisión no disponible.' using errcode = '42501'; end if;
      -- El contexto interno no omite la cuota: vincula la versión a una familia
      -- propia existente. No permite obtener otra plaza ni cambiar de dueño.
      new.family_id := revision.family_id;
      new.previous_version_id := revision.id;
      new.version := revision.version + 1;
    end if;
  end if;
  if not public.has_pro_access(new.owner_user_id)
    and not exists(select 1 from public.workout_templates where owner_user_id = new.owner_user_id
      and origin = 'user' and status <> 'archived' and family_id = new.family_id and id <> new.id)
    and (select count(distinct family_id) from public.workout_templates where owner_user_id = new.owner_user_id
      and origin = 'user' and status <> 'archived' and id <> new.id) >= 4 then
    raise exception 'Has alcanzado las 4 sesiones propias incluidas en Free. Con Pro puedes guardar más.'
      using errcode = 'P0001', detail = 'free_session_limit';
  end if;
  return new;
end $$;
revoke all on function public.enforce_personal_session_quota() from public, anon, authenticated;
create trigger enforce_personal_session_quota before insert or update of origin, owner_user_id, status, family_id
  on public.workout_templates for each row execute function public.enforce_personal_session_quota();

-- Una revisión conserva su plaza incluso después de caducar Pro. La operación
-- sigue siendo atómica: si falla la creación, el archivado también se revierte.
create or replace function public.revise_personal_workout_template(p_template_id uuid, p_payload jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare source_template public.workout_templates%rowtype; v_template_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  perform 1 from public.profiles where id = auth.uid() for update;
  select * into source_template from public.workout_templates where id = p_template_id
    and owner_user_id = auth.uid() and origin = 'user' and status <> 'archived' for update;
  if not found then raise exception 'Personal workout is not accessible' using errcode = '42501'; end if;
  -- Se sustituye una plaza; un permiso interno de revisión nunca viene del cliente.
  perform set_config('entrenaop.revising_template', source_template.id::text, true);
  v_template_id := public.create_personal_workout_template(p_payload);
  perform set_config('entrenaop.revising_template', '', true);
  update public.workout_templates set status = 'archived' where id = source_template.id;
  update public.workout_templates set family_id = source_template.family_id,
    previous_version_id = source_template.id, version = source_template.version + 1 where id = v_template_id;
  return v_template_id;
end $$;

-- Se conservan los motores y sus contratos; las entradas públicas comprueban
-- el derecho antes de calcular/publicar. Las bases quedan fuera del cliente.
do $migration$
declare signature text; function_oid regprocedure; base_name text; original_name text;
  arguments text; result_type text; call_arguments text;
begin
  foreach signature in array array[
    'calculate_preparation_week(uuid,date)', 'preview_preparation_week_revision(uuid,date)',
    'preview_adaptive_program_activation(uuid,date)', 'activate_adaptive_program(uuid,date,jsonb)',
    'publish_preparation_week(uuid,date,jsonb)', 'publish_preparation_week_revision(uuid,date,jsonb)',
    'calculate_running_week(uuid,date)', 'preview_running_initial_week(uuid,date)',
    'preview_running_next_week(uuid)', 'publish_running_week(uuid,date)',
    'calculate_fas_running_week(uuid,date)', 'preview_fas_running_initial_week(uuid,date)',
    'preview_fas_running_next_week(uuid)', 'publish_fas_running_week(uuid,date)'
  ] loop
    function_oid := ('public.' || signature)::regprocedure;
    select proname, pg_get_function_arguments(function_oid), pg_get_function_result(function_oid),
      (select string_agg(quote_ident(name), ', ' order by ord)
        from unnest(proargnames) with ordinality names(name, ord))
      into original_name, arguments, result_type, call_arguments from pg_proc where pg_proc.oid = function_oid;
    base_name := original_name || '_pro_base';
    execute format('alter function %s rename to %I', function_oid, base_name);
    execute format('revoke all on function %s from public, anon, authenticated', function_oid);
    execute format('create function public.%I(%s) returns %s language plpgsql security definer set search_path = '''' as $body$ begin perform public.require_pro_access(); return public.%I(%s); end $body$',
      original_name, arguments, result_type, base_name, call_arguments);
    execute format('revoke all on function public.%I(%s) from public, anon', original_name, pg_get_function_identity_arguments(function_oid));
    execute format('grant execute on function public.%I(%s) to authenticated', original_name, pg_get_function_identity_arguments(function_oid));
  end loop;
end $migration$;

create or replace function public.advance_adaptive_program(p_goal_id uuid) returns jsonb
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
 -- Caducar Pro conserva el estado y las sesiones, pero detiene la generación.
 if not public.has_pro_access(auth.uid()) then return to_jsonb(a); end if;
 select max(week_start) into previous_week from (
      select week_start from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
      union select week_start from public.running_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
    ) weeks;
 if previous_week is null then return to_jsonb(a); end if;
 if not public.preparation_week_closed(p_goal_id,previous_week) then
  update public.adaptive_program_states set status='training',continuation_code='waiting_results',next_generation_on=null,message='La siguiente semana se preparará al resolver las sesiones de esta semana.',last_error_code=null where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 next_week:=greatest(previous_week+7,current_date-extract(isodow from current_date)::int+1);
 if next_week>=g.target_date then
  update public.adaptive_program_states set auto_advance=false,status='complete',continuation_code='complete',next_generation_on=null,message='Has llegado al final de la preparación. Revisa tus resultados.',updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 select count(*),count(*) filter(where status='completed') into total,completed from public.scheduled_workouts
 where preparation_goal_id=p_goal_id and scheduled_date between previous_week and previous_week+6;
 if completed=0 then reason:='No hay entrenamientos completados esta semana. Revisa tu situación y disponibilidad antes de continuar.';
 else
  -- Solo una semana por delante. Un registro adelantado no encadena meses ficticios.
  if next_week>current_date-extract(isodow from current_date)::int+8 then
    update public.adaptive_program_states set status='training',continuation_code='waiting_date',
      next_generation_on=next_week-7,last_error_code=null,
      message='Esta semana está cerrada por adelantado. La siguiente se preparará automáticamente a partir del '||to_char(next_week-7,'DD/MM')||', con los resultados disponibles.',updated_at=now()
      where preparation_goal_id=p_goal_id returning * into a;
    return to_jsonb(a);
   end if;
  begin
   plan:=public.calculate_preparation_week(p_goal_id,next_week);
   if plan->>'status'='ready' then
    plan:=public.publish_preparation_week(p_goal_id,next_week,plan);
    update public.adaptive_program_states set status='training',continuation_code='week_ready',next_generation_on=null,message='Tu próxima semana está preparada con los resultados registrados.',last_generated_week=next_week,last_error_code=null,updated_at=now()
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
 update public.adaptive_program_states set status='needs_review',continuation_code='needs_review',review_items=coalesce(plan->'pending',jsonb_build_array(jsonb_build_object('status',coalesce(plan->>'status','needs_context'),'reason',reason))),next_generation_on=null,message=reason,updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
 return to_jsonb(a);
end $$;

alter function public.refresh_adaptive_programs() rename to refresh_adaptive_programs_pro_base;
revoke all on function public.refresh_adaptive_programs_pro_base() from public, anon, authenticated;
create function public.refresh_adaptive_programs() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  result := public.refresh_adaptive_programs_pro_base();
  if public.has_pro_access(auth.uid()) then return result; end if;
  select coalesce(jsonb_agg(case when item->>'status' = 'draft' then item else
    item || jsonb_build_object('status', 'paused', 'continuation_code', 'pro_required',
      'message', 'Tu programa se conserva. Necesitas Pro para generar y adaptar nuevas semanas.',
      'next_generation_on', null) end), '[]'::jsonb) into result from jsonb_array_elements(result) item;
  return result;
end $$;
revoke all on function public.refresh_adaptive_programs() from public, anon;
grant execute on function public.refresh_adaptive_programs() to authenticated;

commit;
