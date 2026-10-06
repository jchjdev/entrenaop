-- Cero repeticiones es una marca válida; cero segundos o metros no lo es.
begin;

create or replace function public.score_program_assessment_mark(
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
      (v_test.unit <> 'repetitions' and p_mark = 0) or
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

commit;
