-- Los borradores pueden describir ejercicios distintos por columna H/M y
-- tablas de puntos por intervalos. Publicación y captura quedan separadas.
begin;

alter table public.program_assessment_tests
  add column category text not null default 'both',
  add column group_code text,
  add column display_order integer not null default 1,
  add column mark_step numeric(12,3) not null default 1;

update public.program_assessment_tests set group_code = code;

alter table public.program_assessment_tests
  alter column group_code set not null,
  add constraint program_assessment_tests_category_check
    check (category in ('both', 'men', 'women')),
  add constraint program_assessment_tests_group_check
    check (group_code ~ '^[a-z][a-z0-9_]{2,63}$'),
  add constraint program_assessment_tests_order_check
    check (display_order > 0),
  add constraint program_assessment_tests_step_check
    check (mark_step > 0);

create unique index program_assessment_tests_group_category_idx
on public.program_assessment_tests(program_id, group_code, category,
  definition_version);

create table public.program_assessment_scoring_rules (
  program_id text primary key references public.preparation_programs(id)
    on delete restrict,
  scoring_version text not null,
  source_url text not null,
  source_label text not null,
  aggregation text not null,
  max_points numeric(6,2) not null,
  min_each_points numeric(6,2) not null,
  min_aggregate_points numeric(6,2) not null,
  created_at timestamptz not null default now(),
  constraint program_scoring_version_check
    check (char_length(btrim(scoring_version)) between 3 and 120),
  constraint program_scoring_source_check
    check (source_url ~ '^https://'),
  constraint program_scoring_label_check
    check (char_length(btrim(source_label)) between 3 and 250),
  constraint program_scoring_aggregation_check
    check (aggregation in ('average', 'sum')),
  constraint program_scoring_points_check
    check (max_points > 0 and min_each_points >= 0
      and min_each_points <= max_points and min_aggregate_points >= 0)
);

create table public.program_assessment_score_bands (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.program_assessment_tests(id)
    on delete restrict,
  category text not null check (category in ('men', 'women')),
  min_mark numeric(12,3),
  max_mark numeric(12,3),
  points numeric(6,2) not null check (points >= 0),
  created_at timestamptz not null default now(),
  constraint program_score_band_bounds_check
    check (min_mark is null or max_mark is null or min_mark <= max_mark),
  constraint program_score_band_not_unbounded_check
    check (min_mark is not null or max_mark is not null)
);

create index program_score_bands_test_category_idx
on public.program_assessment_score_bands(test_id, category);

alter table public.program_assessment_scoring_rules enable row level security;
alter table public.program_assessment_score_bands enable row level security;
revoke all on public.program_assessment_scoring_rules from public, anon,
  authenticated;
revoke all on public.program_assessment_score_bands from public, anon,
  authenticated;
grant select on public.program_assessment_scoring_rules to authenticated;
grant select on public.program_assessment_score_bands to authenticated;

create policy program_scoring_rules_read
on public.program_assessment_scoring_rules for select to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.preparation_programs p
  where p.id = program_id and p.enabled
));

create policy program_score_bands_read
on public.program_assessment_score_bands for select to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = test_id and p.enabled
));

create function public.create_admin_program_assessment_test_v2(
  p_program_id text, p_code text, p_name text, p_unit text,
  p_better_direction text, p_protocol_notes text, p_category text,
  p_group_code text, p_display_order integer, p_mark_step numeric
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para definir pruebas.'
      using errcode = '42501';
  end if;
  if not exists (select 1 from public.preparation_programs p
    where p.id = p_program_id and not p.enabled) then
    raise exception 'Solo se pueden definir pruebas en borradores.'
      using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_program_id || ':' || p_group_code, 0));
  if exists (select 1 from public.program_assessment_tests t
    where t.program_id = p_program_id and t.group_code = p_group_code
      and t.definition_version = 1
      and (t.category = 'both' or p_category = 'both')) then
    raise exception 'Un ejercicio común no puede mezclarse con variantes H/M.'
      using errcode = '22023';
  end if;
  insert into public.program_assessment_tests
    (program_id, code, name, unit, better_direction, protocol_notes,
     category, group_code, display_order, mark_step)
  values
    (p_program_id, btrim(p_code), btrim(p_name), p_unit,
     p_better_direction, btrim(p_protocol_notes), p_category,
     btrim(p_group_code), p_display_order, p_mark_step)
  returning id into v_id;
  return v_id;
end;
$$;

create function public.save_admin_program_scoring_rule(
  p_program_id text, p_scoring_version text, p_source_url text,
  p_source_label text, p_aggregation text, p_max_points numeric,
  p_min_each_points numeric, p_min_aggregate_points numeric
) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para definir baremos.'
      using errcode = '42501';
  end if;
  if not exists (select 1 from public.preparation_programs p
    where p.id = p_program_id and not p.enabled) then
    raise exception 'Solo se pueden baremar borradores.'
      using errcode = '22023';
  end if;
  insert into public.program_assessment_scoring_rules
    (program_id, scoring_version, source_url, source_label, aggregation,
     max_points, min_each_points, min_aggregate_points)
  values (p_program_id, btrim(p_scoring_version), btrim(p_source_url),
    btrim(p_source_label), p_aggregation, p_max_points,
    p_min_each_points, p_min_aggregate_points)
  on conflict (program_id) do update set
    scoring_version = excluded.scoring_version,
    source_url = excluded.source_url,
    source_label = excluded.source_label,
    aggregation = excluded.aggregation,
    max_points = excluded.max_points,
    min_each_points = excluded.min_each_points,
    min_aggregate_points = excluded.min_aggregate_points;
end;
$$;

create function public.add_admin_program_score_band(
  p_test_id uuid, p_category text, p_min_mark numeric,
  p_max_mark numeric, p_points numeric
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_test public.program_assessment_tests%rowtype;
  v_max_points numeric;
  v_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para definir baremos.'
      using errcode = '42501';
  end if;
  select t.* into v_test from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = p_test_id and not p.enabled;
  if not found then
    raise exception 'Prueba borrador no disponible.' using errcode = '22023';
  end if;
  if p_category not in ('men','women') or
     (v_test.category <> 'both' and v_test.category <> p_category) then
    raise exception 'Columna de baremo incompatible con la prueba.'
      using errcode = '22023';
  end if;
  select r.max_points into v_max_points
  from public.program_assessment_scoring_rules r
  where r.program_id = v_test.program_id;
  if v_max_points is null then
    raise exception 'Define antes la regla de puntuación del programa.'
      using errcode = '22023';
  end if;
  if p_min_mark is null and p_max_mark is null or
     p_min_mark is not null and p_max_mark is not null
       and p_min_mark > p_max_mark or
     p_points is null or p_points < 0 or p_points > v_max_points then
    raise exception 'Intervalo o puntos inválidos.' using errcode = '22023';
  end if;
  if (p_min_mark is not null and
        pg_catalog.mod(p_min_mark, v_test.mark_step) <> 0) or
     (p_max_mark is not null and
        pg_catalog.mod(p_max_mark, v_test.mark_step) <> 0) then
    raise exception 'Los límites deben respetar la resolución de la marca.'
      using errcode = '22023';
  end if;
  -- Serializa altas concurrentes para impedir intervalos solapados.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_test_id::text || p_category, 0));
  if exists (select 1 from public.program_assessment_score_bands b
    where b.test_id = p_test_id and b.category = p_category
      and (p_max_mark is null or b.min_mark is null
        or p_max_mark >= b.min_mark)
      and (p_min_mark is null or b.max_mark is null
        or p_min_mark <= b.max_mark)) then
    raise exception 'El intervalo se solapa con otro tramo.'
      using errcode = '22023';
  end if;
  insert into public.program_assessment_score_bands
    (test_id, category, min_mark, max_mark, points)
  values (p_test_id, p_category, p_min_mark, p_max_mark, p_points)
  returning id into v_id;
  return v_id;
end;
$$;

create function public.score_program_assessment_mark(
  p_test_id uuid, p_category text, p_mark numeric
) returns numeric
language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_test public.program_assessment_tests%rowtype;
  v_points numeric;
begin
  select * into v_test from public.program_assessment_tests
  where id = p_test_id;
  if not found then
    raise exception 'Prueba no disponible.' using errcode = '22023';
  end if;
  if p_category not in ('men','women') or
      (v_test.category <> 'both' and v_test.category <> p_category) or
      p_mark is null or p_mark < 0 or
      pg_catalog.mod(p_mark, v_test.mark_step) <> 0 then
    raise exception 'Marca o columna de baremo incompatible.'
      using errcode = '22023';
  end if;
  select b.points into v_points from public.program_assessment_score_bands b
  where b.test_id = p_test_id and b.category = p_category
    and (b.min_mark is null or p_mark >= b.min_mark)
    and (b.max_mark is null or p_mark <= b.max_mark);
  if not found then
    raise exception 'La marca no tiene tramo de puntuación definido.'
      using errcode = '22023';
  end if;
  return v_points;
end;
$$;

revoke all on function public.create_admin_program_assessment_test_v2(
  text,text,text,text,text,text,text,text,integer,numeric)
from public, anon;
grant execute on function public.create_admin_program_assessment_test_v2(
  text,text,text,text,text,text,text,text,integer,numeric)
to authenticated;
revoke all on function public.save_admin_program_scoring_rule(
  text,text,text,text,text,numeric,numeric,numeric)
from public, anon;
grant execute on function public.save_admin_program_scoring_rule(
  text,text,text,text,text,numeric,numeric,numeric)
to authenticated;
revoke all on function public.add_admin_program_score_band(
  uuid,text,numeric,numeric,numeric)
from public, anon;
grant execute on function public.add_admin_program_score_band(
  uuid,text,numeric,numeric,numeric)
to authenticated;
revoke all on function public.score_program_assessment_mark(
  uuid,text,numeric) from public, anon;
grant execute on function public.score_program_assessment_mark(
  uuid,text,numeric) to authenticated;

commit;
