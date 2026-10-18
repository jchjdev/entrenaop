begin;
-- Iniciados es una colección activa; el historial conserva todos los seguimientos.
create or replace function public.get_guided_program_catalog(p_query text default '',p_mode text default null,
  p_offset integer default 0,p_limit integer default 3,p_followed boolean default false)
returns setof public.guided_programs language sql stable security invoker set search_path='' as $$
  select p.* from public.guided_programs p
  where p.status<>'draft' and (
    (p_followed and exists(select 1 from public.guided_program_follows f where f.program_id=p.id and f.user_id=auth.uid() and f.completed_at is null and f.abandoned_at is null))
    or (not p_followed and p.status='published' and not exists(
      select 1 from public.guided_programs newer where newer.family_id=p.family_id and newer.status='published' and newer.version>p.version
    ))
  ) and (p_mode is null or p.content->>'mode'=p_mode)
    and (coalesce(p_query,'')='' or (p.content->>'name') ilike '%'||left(p_query,100)||'%'
      or (p.content->>'description') ilike '%'||left(p_query,100)||'%')
  order by p.created_at desc,p.id
  offset greatest(0,p_offset) limit greatest(1,least(25,p_limit));
$$;
revoke all on function public.get_guided_program_catalog(text,text,integer,integer,boolean) from public,anon,authenticated;
grant execute on function public.get_guided_program_catalog(text,text,integer,integer,boolean) to authenticated;
commit;
