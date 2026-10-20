-- Evidencias operativas privadas. Solo el trabajo de servidor escribe copias
-- y eventos del proveedor; el navegador únicamente consulta con permiso ADMIN.
create table admin_ops_private.backup_runs (
  run_id text primary key check (run_id ~ '^[0-9]+-[0-9]+$'),
  started_at timestamptz not null,
  finished_at timestamptz,
  status text not null check (status in ('running','failed','verified')),
  artifact_id bigint,
  artifact_name text,
  archive_sha256 text check (archive_sha256 ~ '^[a-f0-9]{64}$'),
  archive_bytes bigint check (archive_bytes between 1 and 16777216),
  storage_objects integer check (storage_objects>=0),
  restore_verified_at timestamptz,
  expires_at timestamptz,
  failure_code text check (failure_code ~ '^[a-z_]{1,60}$'),
  check (status<>'verified' or (artifact_id is not null and archive_sha256 is not null
    and archive_bytes is not null and restore_verified_at is not null and expires_at>finished_at))
);
alter table admin_ops_private.backup_runs enable row level security;
revoke all on admin_ops_private.backup_runs from public,anon,authenticated;

create table admin_ops_private.service_events (
  event_id text primary key check (length(event_id) between 1 and 150),
  occurred_at timestamptz not null,
  source text not null check (source in ('edge_logs','postgres_logs','auth_logs','storage_logs','function_edge_logs','admin')),
  code text not null check (code ~ '^[A-Za-z0-9_]{1,50}$'),
  component text not null check (component ~ '^[a-z_/]{1,60}$'),
  release text check (release='local' or release ~ '^[a-f0-9]{40}$')
);
create index service_events_recent on admin_ops_private.service_events(occurred_at desc,event_id);
alter table admin_ops_private.service_events enable row level security;
revoke all on admin_ops_private.service_events from public,anon,authenticated;

create table admin_ops_private.log_collections (
  run_id text primary key,
  checked_at timestamptz not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  status text not null check (status in ('success','failed')),
  truncated boolean not null default false,
  event_count integer not null check (event_count between 0 and 5000),
  check (window_end>window_start and window_end-window_start<=interval '24 hours')
);
alter table admin_ops_private.log_collections enable row level security;
revoke all on admin_ops_private.log_collections from public,anon,authenticated;

create function public.admin_recovery_diagnostics() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return jsonb_build_object(
    'checked_at',now(),
    'backups',coalesce((select jsonb_agg(to_jsonb(b) order by b.started_at desc)
      from (select * from admin_ops_private.backup_runs order by started_at desc limit 10) b),'[]'::jsonb),
    'collection',(select to_jsonb(c) from admin_ops_private.log_collections c order by checked_at desc limit 1),
    'errors',coalesce((select jsonb_agg(to_jsonb(e) order by e.occurred_at desc)
      from (select * from admin_ops_private.service_events where occurred_at>now()-interval '14 days'
        order by occurred_at desc,event_id limit 100) e),'[]'::jsonb));
end $$;
revoke all on function public.admin_recovery_diagnostics() from public,anon;
grant execute on function public.admin_recovery_diagnostics() to authenticated;

-- No se aceptan mensajes, consultas, URLs ni trazas arbitrarias del cliente.
create function public.report_admin_client_error(p_code text,p_component text,p_release text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  if p_code is null or p_component is null or
    p_code not in ('framework_error','unhandled_async','network_error','server_error') or
    p_component not in ('admin','programs','guided_programs','sessions','exercises','warmups','accounts','operations') or
    p_release is null or not(p_release='local' or p_release ~ '^[a-f0-9]{40}$') then
    raise invalid_parameter_value;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,31));
  -- Un fallo en bucle no puede llenar la base de datos ni generar otra tormenta.
  if (select count(*) from admin_ops_private.service_events where source='admin'
    and occurred_at>now()-interval '1 minute')>=10 then return; end if;
  insert into admin_ops_private.service_events(event_id,occurred_at,source,code,component,release)
    values(gen_random_uuid()::text,now(),'admin',p_code,p_component,p_release);
end $$;
revoke all on function public.report_admin_client_error(text,text,text) from public,anon;
grant execute on function public.report_admin_client_error(text,text,text) to authenticated;

create or replace function public.admin_operations_status() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return jsonb_build_object('checked_at',now(),'database','reachable',
    'history_events',(select count(*) from admin_ops_private.editorial_events where before_data is distinct from after_data),
    'failed_videos',(select count(*) from public.exercise_video_assets where status='failed'),
    'backups',case when exists(select 1 from admin_ops_private.backup_runs where status='verified' and expires_at>now()
      and finished_at>now()-interval '36 hours') then 'verified' else 'unverified' end,
    'service_logs',case when exists(select 1 from admin_ops_private.log_collections where status='success'
      and checked_at>now()-interval '2 hours') then 'collected' else 'not_connected' end);
end $$;
