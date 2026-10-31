begin;

-- Coincide con la búsqueda del editor: términos literales, sin distinguir
-- mayúsculas ni tildes. No se interpretan comodines, expresiones ni IDs.
create function trainer_private.catalog_search_normalize(p_text text) returns text
language sql immutable parallel safe security invoker set search_path='' as $$
 select translate(lower(btrim(regexp_replace(coalesce(p_text,''),'\s+',' ','g'))),'áéíóúü','aeiouu');
$$;
revoke all on function trainer_private.catalog_search_normalize(text) from public,anon,authenticated;

create index trainer_workout_library_page on public.workout_templates(owner_user_id,created_at desc,id desc)
 where origin='coach' and status='published' and trashed_at is null;

create function trainer_private.search_trainer_workouts(
 p_query text default '',p_running boolean default null,p_format text default null,
 p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare terms text[];
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) or length(coalesce(p_query,''))>512 then raise invalid_parameter_value; end if;
 if p_format is not null and p_format not in ('straight_sets','superset','circuit','intervals','emom','amrap','tabata','running','warm_up','cool_down') then raise invalid_parameter_value; end if;
 terms:=string_to_array(trainer_private.catalog_search_normalize(p_query),' ');
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]'::jsonb) from (
  select t.id,t.name,t.version,t.created_at,
   ('running'=any(d.formats)) as is_running,to_jsonb(d.formats) as formats,to_jsonb(d.words) as search_content
  from public.workout_templates t
  cross join lateral (
   select coalesce(array_agg(distinct b.format),'{}'::text[]) as formats,
    array_prepend(coalesce(t.description,''),coalesce(array_agg(distinct concat_ws(' ',b.name,case b.format
     when 'straight_sets' then 'Series convencionales' when 'superset' then 'Superserie'
     when 'circuit' then 'Circuito' when 'intervals' then 'Intervalos' when 'amrap' then 'AMRAP'
     when 'tabata' then 'Tabata' when 'emom' then 'EMOM' when 'running' then 'Carrera'
     when 'warm_up' then 'Calentamiento' when 'cool_down' then 'Vuelta a la calma' end,e.name)),'{}'::text[])) as words
   from public.workout_blocks b left join public.workout_items i on i.block_id=b.id
   left join public.exercises e on e.id=i.exercise_id and (e.origin='system' or e.created_by=auth.uid())
   where b.template_id=t.id
  ) d
  where t.owner_user_id=auth.uid() and t.origin='coach' and t.status='published' and t.trashed_at is null
   and not exists(select 1 from trainer_private.assignment_variants v where v.template_id=t.id)
   and (p_before_at is null or (t.created_at,t.id)<(p_before_at,p_before_id))
   and (p_running is null or p_running=('running'=any(d.formats)))
   and (p_format is null or p_format=any(d.formats))
   and not exists(select 1 from unnest(terms) q(term) where strpos(
    trainer_private.catalog_search_normalize(concat_ws(' ',t.name,case when 'running'=any(d.formats) then 'Carrera' else 'Fuerza' end,array_to_string(d.words,' '))),q.term)=0)
  order by t.created_at desc,t.id desc limit 50
 ) x);
end $$;

create function trainer_private.search_trainer_programs(
 p_query text default '',p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare terms text[];
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) or length(coalesce(p_query,''))>512 then raise invalid_parameter_value; end if;
 terms:=string_to_array(trainer_private.catalog_search_normalize(p_query),' ');
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]'::jsonb) from (
  select p.id,p.family_id,p.version,p.status,p.content,p.created_at
  from trainer_private.programs p
  where p.trainer_id=auth.uid() and p.trashed_at is null and p.status='published'
   and (p_before_at is null or (p.created_at,p.id)<(p_before_at,p_before_id))
   and not exists(select 1 from unnest(terms) q(term) where strpos(
    trainer_private.catalog_search_normalize(concat_ws(' ',p.content->>'name',p.content->>'description',
     (select string_agg(concat_ws(' ',ph->>'name',s->>'name'),' ') from jsonb_array_elements(p.content->'phases') ph
      left join lateral jsonb_array_elements(ph->'sessions') s on true))),q.term)=0)
  order by p.created_at desc,p.id desc limit 50
 ) x);
end $$;

create function public.search_trainer_workouts(p_query text default '',p_running boolean default null,p_format text default null,p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$
 select trainer_private.search_trainer_workouts(p_query,p_running,p_format,p_before_at,p_before_id);
$$;
create function public.search_trainer_programs(p_query text default '',p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$
 select trainer_private.search_trainer_programs(p_query,p_before_at,p_before_id);
$$;
revoke all on function trainer_private.search_trainer_workouts(text,boolean,text,timestamptz,uuid),trainer_private.search_trainer_programs(text,timestamptz,uuid),public.search_trainer_workouts(text,boolean,text,timestamptz,uuid),public.search_trainer_programs(text,timestamptz,uuid) from public,anon,authenticated;
grant execute on function trainer_private.search_trainer_workouts(text,boolean,text,timestamptz,uuid),trainer_private.search_trainer_programs(text,timestamptz,uuid),public.search_trainer_workouts(text,boolean,text,timestamptz,uuid),public.search_trainer_programs(text,timestamptz,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
