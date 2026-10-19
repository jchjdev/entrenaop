-- Se activa únicamente después de verificar un factor; el cliente no puede desactivarlo.
create table public.admin_security_requirements (
  user_id uuid primary key references public.admin_permissions(user_id) on delete cascade,
  mfa_required boolean not null default true check (mfa_required),
  enabled_at timestamptz not null default now()
);
alter table public.admin_security_requirements enable row level security;
revoke all on public.admin_security_requirements from public, anon, authenticated;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.admin_permissions p where p.user_id=(select auth.uid()))
    and (
      not exists(select 1 from public.admin_security_requirements r where r.user_id=(select auth.uid()))
      or (
        coalesce((select auth.jwt()->>'aal')='aal2',false)
        and exists(select 1 from auth.mfa_factors f where f.user_id=(select auth.uid()) and f.status='verified')
      )
    );
$$;

create function public.get_admin_security_status()
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'eligible', exists(select 1 from public.admin_permissions p where p.user_id=(select auth.uid())),
    'mfa_required', exists(select 1 from public.admin_security_requirements r where r.user_id=(select auth.uid())),
    'assured', coalesce((select auth.jwt()->>'aal')='aal2',false)
      and exists(select 1 from auth.mfa_factors where user_id=(select auth.uid()) and status='verified')
  );
$$;

create function public.enable_admin_mfa_requirement()
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null
    or not exists(select 1 from public.admin_permissions where user_id=auth.uid())
    or (auth.jwt()->>'aal') is distinct from 'aal2'
    or not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified') then
    raise exception 'Verifica primero tu segundo factor.' using errcode='42501';
  end if;
  insert into public.admin_security_requirements(user_id) values(auth.uid()) on conflict(user_id) do nothing;
end $$;

revoke all on function public.get_admin_security_status() from public, anon;
revoke all on function public.enable_admin_mfa_requirement() from public, anon;
grant execute on function public.get_admin_security_status() to authenticated;
grant execute on function public.enable_admin_mfa_requirement() to authenticated;

-- Esta operación antigua consultaba el permiso directamente y debe compartir la comprobación MFA.
do $$
declare definition text; original text := 'not exists(select 1 from public.admin_permissions where user_id=u)';
begin
  definition:=pg_get_functiondef('public.reset_adaptive_program_trial(uuid,text)'::regprocedure);
  if position(original in definition)=0 then raise exception 'Contrato de reinicio inesperado: revisar antes de aplicar MFA.'; end if;
  execute replace(definition,original,'not public.is_admin()');
  definition:=pg_get_functiondef('public.get_preparation_training_setup_base(uuid)'::regprocedure);
  original:='exists(select 1 from public.admin_permissions where user_id=auth.uid())';
  if position(original in definition)=0 then raise exception 'Contrato de preparación inesperado: revisar capacidad administrativa.'; end if;
  execute replace(definition,original,'public.is_admin()');
end $$;
