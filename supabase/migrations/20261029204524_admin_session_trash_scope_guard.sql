-- La papelera ahora admite recetas coach. ADMIN conserva exclusivamente
-- sesiones oficiales; no debe depender de las variantes permitidas por CHECK.
begin;
create or replace function public.list_admin_session_trash() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('kind','session','id',t.id,'name',t.name,
  'trashed_at',t.trashed_at,'revision',null,'versions',t.version,'work_count',0) order by t.trashed_at desc)
  from public.workout_templates t where t.trashed_at is not null and t.origin='system' and t.owner_user_id is null),'[]'::jsonb);
end $$;
commit;
