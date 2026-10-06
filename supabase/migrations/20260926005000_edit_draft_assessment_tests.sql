begin;

create function public.update_admin_program_assessment_test(
  p_test_id uuid, p_name text, p_unit text, p_better_direction text,
  p_protocol_notes text, p_category text, p_display_order integer,
  p_mark_step numeric, p_reset_bands boolean default false
) returns void
language plpgsql security definer set search_path = ''
as $$
declare v_test public.program_assessment_tests%rowtype;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para editar pruebas.' using errcode = '42501';
  end if;
  select t.* into v_test from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = p_test_id and not p.enabled for update of t;
  if not found then
    raise exception 'Prueba borrador no disponible.' using errcode = '22023';
  end if;
  if (v_test.unit <> p_unit or v_test.better_direction <> p_better_direction
      or v_test.category <> p_category or v_test.mark_step <> p_mark_step)
      and exists (select 1 from public.program_assessment_score_bands b
        where b.test_id = p_test_id) then
    if not p_reset_bands then
      raise exception 'Confirma el borrado de los tramos antes de cambiar la medición.'
        using errcode = '22023';
    end if;
    delete from public.program_assessment_score_bands where test_id = p_test_id;
  end if;
  if exists (select 1 from public.program_assessment_tests t
    where t.program_id = v_test.program_id and t.group_code = v_test.group_code
      and t.id <> p_test_id and (t.category = 'both' or p_category = 'both')) then
    raise exception 'La variante no puede mezclarse con una prueba común.'
      using errcode = '22023';
  end if;
  update public.program_assessment_tests set
    name = btrim(p_name), unit = p_unit,
    better_direction = p_better_direction,
    protocol_notes = btrim(p_protocol_notes), category = p_category,
    display_order = p_display_order, mark_step = p_mark_step
  where id = p_test_id;
end;
$$;

create function public.delete_admin_program_assessment_test(p_test_id uuid)
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
  delete from public.program_assessment_tests where id = p_test_id;
end;
$$;

create function public.update_admin_program_score_band(
  p_band_id uuid, p_category text, p_min_mark numeric,
  p_max_mark numeric, p_points numeric
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_band public.program_assessment_score_bands%rowtype;
declare v_test public.program_assessment_tests%rowtype;
declare v_max_points numeric;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para editar baremos.' using errcode = '42501';
  end if;
  select b.* into v_band from public.program_assessment_score_bands b
  join public.program_assessment_tests t on t.id = b.test_id
  join public.preparation_programs p on p.id = t.program_id
  where b.id = p_band_id and not p.enabled for update of b;
  if not found then
    raise exception 'Tramo borrador no disponible.' using errcode = '22023';
  end if;
  select * into v_test from public.program_assessment_tests where id = v_band.test_id;
  select max_points into v_max_points from public.program_assessment_scoring_rules
    where program_id = v_test.program_id;
  if p_category not in ('men','women') or
     (v_test.category <> 'both' and v_test.category <> p_category) or
     (p_min_mark is null and p_max_mark is null) or
     (p_min_mark is not null and p_max_mark is not null and p_min_mark > p_max_mark) or
     p_points is null or p_points < 0 or p_points > v_max_points or
     (p_min_mark is not null and pg_catalog.mod(p_min_mark, v_test.mark_step) <> 0) or
     (p_max_mark is not null and pg_catalog.mod(p_max_mark, v_test.mark_step) <> 0) then
    raise exception 'Intervalo o puntos inválidos.' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_band.test_id::text || p_category, 0));
  if exists (select 1 from public.program_assessment_score_bands b
    where b.test_id = v_band.test_id and b.category = p_category and b.id <> p_band_id
      and (p_max_mark is null or b.min_mark is null or p_max_mark >= b.min_mark)
      and (p_min_mark is null or b.max_mark is null or p_min_mark <= b.max_mark)) then
    raise exception 'El intervalo se solapa con otro tramo.' using errcode = '22023';
  end if;
  update public.program_assessment_score_bands set
    category = p_category, min_mark = p_min_mark,
    max_mark = p_max_mark, points = p_points where id = p_band_id;
end;
$$;

revoke all on function public.update_admin_program_assessment_test(uuid,text,text,text,text,text,integer,numeric,boolean) from public, anon;
grant execute on function public.update_admin_program_assessment_test(uuid,text,text,text,text,text,integer,numeric,boolean) to authenticated;
revoke all on function public.delete_admin_program_assessment_test(uuid) from public, anon;
grant execute on function public.delete_admin_program_assessment_test(uuid) to authenticated;
revoke all on function public.update_admin_program_score_band(uuid,text,numeric,numeric,numeric) from public, anon;
grant execute on function public.update_admin_program_score_band(uuid,text,numeric,numeric,numeric) to authenticated;

commit;
