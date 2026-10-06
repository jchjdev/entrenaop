-- Carga transaccional de tablas extensas en borradores.
begin;

create function public.import_admin_program_score_bands(
  p_test_id uuid, p_rows jsonb, p_replace boolean default true
) returns integer language plpgsql security definer set search_path = ''
as $$
declare
  v_row jsonb;
  v_count integer;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede importar baremos.'
      using errcode = '42501';
  end if;
  if not exists (select 1 from public.program_assessment_tests t
      join public.preparation_programs p on p.id = t.program_id
      join public.program_assessment_scoring_rules r on r.program_id = p.id
      where t.id = p_test_id and not p.enabled and r.scoring_mode = 'points') then
    raise exception 'La prueba no está en un borrador de puntos.'
      using errcode = '22023';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or
      jsonb_array_length(p_rows) < 1 or jsonb_array_length(p_rows) > 2000 then
    raise exception 'La importación debe contener entre 1 y 2000 filas.'
      using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_test_id::text, 0));
  if p_replace then
    delete from public.program_assessment_score_bands where test_id = p_test_id;
  end if;
  v_count := 0;
  for v_row in select value from jsonb_array_elements(p_rows) loop
    perform public.save_admin_program_score_band_v2(
      p_test_id,null,v_row->>'category',
      (v_row->>'min_age')::integer,(v_row->>'max_age')::integer,
      (v_row->>'min_mark')::numeric,(v_row->>'max_mark')::numeric,
      (v_row->>'points')::numeric);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.import_admin_program_score_bands(uuid,jsonb,boolean)
from public, anon;
grant execute on function public.import_admin_program_score_bands(uuid,jsonb,boolean)
to authenticated;

commit;
