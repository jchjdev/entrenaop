-- Amplía los borradores existentes sin alterar marcas ni baremos ya cargados.
-- Los dos modos son umbral apto/no apto y puntos por tramos de edad y H/M.
begin;

alter table public.program_assessment_tests
  add column min_age integer not null default 0,
  add column max_age integer not null default 120,
  add constraint program_assessment_test_age_check
    check (min_age >= 0 and max_age <= 120 and min_age <= max_age);

alter table public.program_assessment_score_bands
  add column min_age integer not null default 0,
  add column max_age integer not null default 120,
  add constraint program_assessment_band_age_check
    check (min_age >= 0 and max_age <= 120 and min_age <= max_age);

alter table public.program_assessment_scoring_rules
  add column scoring_mode text not null default 'points',
  add column age_reference text not null default 'assessment_date',
  add column stage_label text not null default 'Ingreso',
  add column effective_on date,
  add column expires_on date,
  add constraint program_scoring_mode_check
    check (scoring_mode in ('points', 'pass_fail')),
  add constraint program_scoring_age_reference_check
    check (age_reference in ('assessment_date', 'reference_date', 'calendar_year')),
  add constraint program_scoring_stage_check
    check (char_length(btrim(stage_label)) between 3 and 120),
  add constraint program_scoring_dates_check
    check (effective_on is null or expires_on is null or effective_on <= expires_on);

alter table public.program_assessment_scoring_rules
  drop constraint program_scoring_aggregation_check,
  add constraint program_scoring_aggregation_check
    check (aggregation in ('none', 'average', 'sum'));

create table public.program_assessment_pass_standards (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.program_assessment_tests(id)
    on delete restrict,
  category text not null check (category in ('men', 'women')),
  min_age integer not null default 0,
  max_age integer not null default 120,
  threshold numeric(12,3) not null check (threshold >= 0),
  created_at timestamptz not null default now(),
  constraint program_pass_standard_age_check
    check (min_age >= 0 and max_age <= 120 and min_age <= max_age)
);

create index program_pass_standards_test_category_idx
on public.program_assessment_pass_standards(test_id, category, min_age);

alter table public.program_assessment_pass_standards enable row level security;
revoke all on public.program_assessment_pass_standards
  from public, anon, authenticated;
grant select on public.program_assessment_pass_standards to authenticated;
create policy program_pass_standards_read
on public.program_assessment_pass_standards for select to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = test_id and p.enabled
));

create function public.create_admin_program_assessment_test_v3(
  p_program_id text, p_code text, p_name text, p_unit text,
  p_better_direction text, p_protocol_notes text, p_category text,
  p_group_code text, p_display_order integer, p_mark_step numeric,
  p_min_age integer, p_max_age integer
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if p_min_age is null or p_max_age is null or p_min_age < 0 or
      p_max_age > 120 or p_min_age > p_max_age then
    raise exception 'Rango de edad inválido.' using errcode = '22023';
  end if;
  v_id := public.create_admin_program_assessment_test_v2(
    p_program_id, p_code, p_name, p_unit, p_better_direction,
    p_protocol_notes, p_category, p_group_code, p_display_order, p_mark_step);
  update public.program_assessment_tests set
    min_age = p_min_age, max_age = p_max_age where id = v_id;
  return v_id;
end;
$$;

create function public.update_admin_program_assessment_test_v3(
  p_test_id uuid, p_name text, p_unit text, p_better_direction text,
  p_protocol_notes text, p_category text, p_display_order integer,
  p_mark_step numeric, p_min_age integer, p_max_age integer,
  p_reset_bands boolean default false
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_test public.program_assessment_tests%rowtype;
begin
  if p_min_age is null or p_max_age is null or p_min_age < 0 or
      p_max_age > 120 or p_min_age > p_max_age then
    raise exception 'Rango de edad inválido.' using errcode = '22023';
  end if;
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para editar pruebas.' using errcode = '42501';
  end if;
  select t.* into v_test from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = p_test_id and not p.enabled for update of t;
  if not found then
    raise exception 'Prueba borrador no disponible.' using errcode = '22023';
  end if;
  if ((v_test.unit, v_test.better_direction, v_test.category, v_test.mark_step)
      is distinct from (p_unit, p_better_direction, p_category, p_mark_step)
      or exists (select 1 from public.program_assessment_pass_standards s
        where s.test_id = p_test_id and
          (s.min_age < p_min_age or s.max_age > p_max_age)))
      and exists (select 1 from public.program_assessment_pass_standards
        where test_id = p_test_id) then
    if p_reset_bands is not true then
      raise exception 'Confirma el borrado de los mínimos antes de cambiar la medición.'
        using errcode = '22023';
    end if;
    delete from public.program_assessment_pass_standards where test_id = p_test_id;
  end if;
  if exists (select 1 from public.program_assessment_score_bands b
      where b.test_id = p_test_id and
        (b.min_age < p_min_age or b.max_age > p_max_age)) then
    if p_reset_bands is not true then
      raise exception 'Confirma el borrado de los tramos fuera de la nueva edad.'
        using errcode = '22023';
    end if;
    delete from public.program_assessment_score_bands where test_id = p_test_id;
  end if;
  perform public.update_admin_program_assessment_test(
    p_test_id, p_name, p_unit, p_better_direction, p_protocol_notes,
    p_category, p_display_order, p_mark_step, p_reset_bands);
  update public.program_assessment_tests set
    min_age = p_min_age, max_age = p_max_age where id = p_test_id;
end;
$$;

create function public.guard_assessment_test_pass_standards_update()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if (old.unit, old.better_direction, old.category, old.mark_step)
      is distinct from
     (new.unit, new.better_direction, new.category, new.mark_step)
     and exists (select 1 from public.program_assessment_pass_standards s
       where s.test_id = old.id) then
    raise exception 'Primero borra los mínimos incompatibles.'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger guard_assessment_test_pass_standards_before_update
before update of unit, better_direction, category, mark_step
on public.program_assessment_tests
for each row execute function public.guard_assessment_test_pass_standards_update();

create function public.save_admin_program_scoring_rule_v2(
  p_program_id text, p_scoring_version text, p_source_url text,
  p_source_label text, p_scoring_mode text, p_aggregation text,
  p_max_points numeric, p_min_each_points numeric,
  p_min_aggregate_points numeric, p_age_reference text,
  p_stage_label text, p_effective_on date, p_expires_on date
) returns void language plpgsql security definer set search_path = ''
as $$
begin
  if p_scoring_mode not in ('points', 'pass_fail') or
     p_aggregation not in ('none', 'average', 'sum') or
     (p_scoring_mode = 'pass_fail' and p_aggregation <> 'none') or
     p_age_reference not in ('assessment_date','reference_date','calendar_year') then
    raise exception 'Modo o contexto de puntuación inválido.' using errcode = '22023';
  end if;
  if p_scoring_mode = 'pass_fail' and exists (
    select 1 from public.program_assessment_score_bands b
    join public.program_assessment_tests t on t.id = b.test_id
    where t.program_id = p_program_id) or
     p_scoring_mode = 'points' and exists (
    select 1 from public.program_assessment_pass_standards s
    join public.program_assessment_tests t on t.id = s.test_id
    where t.program_id = p_program_id) then
    raise exception 'Borra antes los baremos del modo anterior.'
      using errcode = '22023';
  end if;
  perform public.save_admin_program_scoring_rule(
    p_program_id, p_scoring_version, p_source_url, p_source_label,
    p_aggregation, p_max_points, p_min_each_points, p_min_aggregate_points);
  update public.program_assessment_scoring_rules set
    scoring_mode = p_scoring_mode, age_reference = p_age_reference,
    stage_label = btrim(p_stage_label), effective_on = p_effective_on,
    expires_on = p_expires_on
  where program_id = p_program_id;
end;
$$;

create function public.save_admin_program_score_band_v2(
  p_test_id uuid, p_band_id uuid, p_category text,
  p_min_age integer, p_max_age integer, p_min_mark numeric,
  p_max_mark numeric, p_points numeric
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_test public.program_assessment_tests%rowtype;
  v_max_points numeric;
  v_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para editar baremos.' using errcode = '42501';
  end if;
  select t.* into v_test from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = p_test_id and not p.enabled;
  if not found then
    raise exception 'Prueba borrador no disponible.' using errcode = '22023';
  end if;
  if p_band_id is not null and not exists (
    select 1 from public.program_assessment_score_bands
    where id = p_band_id and test_id = p_test_id) then
    raise exception 'Tramo ajeno a la prueba.' using errcode = '22023';
  end if;
  if p_category not in ('men','women') or
     (v_test.category <> 'both' and v_test.category <> p_category) or
     p_min_age is null or p_max_age is null or p_min_age < 0 or
     p_max_age > 120 or p_min_age > p_max_age or
     p_min_age < v_test.min_age or p_max_age > v_test.max_age or
     p_min_mark is null and p_max_mark is null or
     p_min_mark is not null and p_max_mark is not null and p_min_mark > p_max_mark or
     p_points is null or p_points < 0 or
     (p_min_mark is not null and pg_catalog.mod(p_min_mark, v_test.mark_step) <> 0) or
     (p_max_mark is not null and pg_catalog.mod(p_max_mark, v_test.mark_step) <> 0) then
    raise exception 'Columna, edad, marca o puntos inválidos.' using errcode = '22023';
  end if;
  select r.max_points into v_max_points
  from public.program_assessment_scoring_rules r
  where r.program_id = v_test.program_id and r.scoring_mode = 'points';
  if v_max_points is null or p_points > v_max_points then
    raise exception 'Define un baremo de puntos antes de añadir tramos.'
      using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_test_id::text || p_category, 0));
  if exists (select 1 from public.program_assessment_score_bands b
    where b.test_id = p_test_id and b.category = p_category
      and (p_band_id is null or b.id <> p_band_id)
      and b.min_age <= p_max_age and b.max_age >= p_min_age
      and (p_max_mark is null or b.min_mark is null or p_max_mark >= b.min_mark)
      and (p_min_mark is null or b.max_mark is null or p_min_mark <= b.max_mark)) then
    raise exception 'Tramos solapados para esta edad y columna.'
      using errcode = '22023';
  end if;
  if p_band_id is null then
    insert into public.program_assessment_score_bands
      (test_id,category,min_age,max_age,min_mark,max_mark,points)
    values (p_test_id,p_category,p_min_age,p_max_age,p_min_mark,p_max_mark,p_points)
    returning id into v_id;
  else
    update public.program_assessment_score_bands set
      category = p_category, min_age = p_min_age, max_age = p_max_age,
      min_mark = p_min_mark, max_mark = p_max_mark, points = p_points
    where id = p_band_id returning id into v_id;
  end if;
  return v_id;
end;
$$;

create function public.save_admin_program_pass_standard(
  p_test_id uuid, p_standard_id uuid, p_category text,
  p_min_age integer, p_max_age integer, p_threshold numeric
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_test public.program_assessment_tests%rowtype;
  v_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para editar mínimos.' using errcode = '42501';
  end if;
  select t.* into v_test from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = p_test_id and not p.enabled;
  if not found then
    raise exception 'Prueba borrador no disponible.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.program_assessment_scoring_rules
    where program_id = v_test.program_id and scoring_mode = 'pass_fail') then
    raise exception 'Define antes la evaluación apto/no apto.'
      using errcode = '22023';
  end if;
  if p_category not in ('men','women') or
     (v_test.category <> 'both' and v_test.category <> p_category) or
     p_min_age is null or p_max_age is null or p_min_age < v_test.min_age or
     p_max_age > v_test.max_age or p_min_age > p_max_age or
     p_threshold is null or p_threshold < 0 or
     pg_catalog.mod(p_threshold, v_test.mark_step) <> 0 then
    raise exception 'Columna, edad o mínimo inválidos.' using errcode = '22023';
  end if;
  if p_standard_id is not null and not exists (
    select 1 from public.program_assessment_pass_standards
    where id = p_standard_id and test_id = p_test_id) then
    raise exception 'Mínimo ajeno a la prueba.' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_test_id::text || p_category, 0));
  if exists (select 1 from public.program_assessment_pass_standards s
    where s.test_id = p_test_id and s.category = p_category
      and (p_standard_id is null or s.id <> p_standard_id)
      and s.min_age <= p_max_age and s.max_age >= p_min_age) then
    raise exception 'Edades solapadas para esta columna.' using errcode = '22023';
  end if;
  if p_standard_id is null then
    insert into public.program_assessment_pass_standards
      (test_id,category,min_age,max_age,threshold)
    values (p_test_id,p_category,p_min_age,p_max_age,p_threshold)
    returning id into v_id;
  else
    update public.program_assessment_pass_standards set
      category = p_category, min_age = p_min_age, max_age = p_max_age,
      threshold = p_threshold where id = p_standard_id returning id into v_id;
  end if;
  return v_id;
end;
$$;

create function public.delete_admin_program_pass_standard(p_standard_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para borrar mínimos.' using errcode = '42501';
  end if;
  delete from public.program_assessment_pass_standards s
  using public.program_assessment_tests t, public.preparation_programs p
  where s.id = p_standard_id and t.id = s.test_id
    and p.id = t.program_id and not p.enabled;
  if not found then
    raise exception 'Mínimo no disponible en un borrador.' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.delete_admin_program_assessment_test(p_test_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para borrar pruebas.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.program_assessment_tests t
    join public.preparation_programs p on p.id = t.program_id
    where t.id = p_test_id and not p.enabled) then
    raise exception 'Prueba borrador no disponible.' using errcode = '22023';
  end if;
  delete from public.program_assessment_score_bands where test_id = p_test_id;
  delete from public.program_assessment_pass_standards where test_id = p_test_id;
  delete from public.program_assessment_tests where id = p_test_id;
end;
$$;

revoke all on function public.create_admin_program_assessment_test_v3(
  text,text,text,text,text,text,text,text,integer,numeric,integer,integer)
from public, anon;
grant execute on function public.create_admin_program_assessment_test_v3(
  text,text,text,text,text,text,text,text,integer,numeric,integer,integer)
to authenticated;
revoke all on function public.update_admin_program_assessment_test_v3(
  uuid,text,text,text,text,text,integer,numeric,integer,integer,boolean)
from public, anon;
grant execute on function public.update_admin_program_assessment_test_v3(
  uuid,text,text,text,text,text,integer,numeric,integer,integer,boolean)
to authenticated;
revoke all on function public.save_admin_program_scoring_rule_v2(
  text,text,text,text,text,text,numeric,numeric,numeric,text,text,date,date)
from public, anon;
grant execute on function public.save_admin_program_scoring_rule_v2(
  text,text,text,text,text,text,numeric,numeric,numeric,text,text,date,date)
to authenticated;
revoke all on function public.save_admin_program_score_band_v2(
  uuid,uuid,text,integer,integer,numeric,numeric,numeric)
from public, anon;
grant execute on function public.save_admin_program_score_band_v2(
  uuid,uuid,text,integer,integer,numeric,numeric,numeric)
to authenticated;
revoke all on function public.save_admin_program_pass_standard(
  uuid,uuid,text,integer,integer,numeric) from public, anon;
grant execute on function public.save_admin_program_pass_standard(
  uuid,uuid,text,integer,integer,numeric) to authenticated;
revoke all on function public.delete_admin_program_pass_standard(uuid)
from public, anon;
grant execute on function public.delete_admin_program_pass_standard(uuid)
to authenticated;

commit;
