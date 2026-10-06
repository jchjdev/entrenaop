-- Anexo II de BOE-A-2026-15055. Borrador administrativo no publicado.
-- Fuente: https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055
begin;

do $$
declare
  v_program text;
  v_agility uuid;
  v_pullups uuid;
  v_hang uuid;
  v_run uuid;
begin
  select p.id into v_program from public.preparation_programs p
  where p.id = 'police_national_basic_2026'
     or (p.name = 'CNP' and p.kind = 'access' and not p.enabled)
  order by (p.id = 'police_national_basic_2026') desc, p.created_at
  limit 1;
  if v_program is null then
    v_program := 'police_national_basic_2026';
    insert into public.preparation_programs (id, name, kind, enabled)
    values (v_program, 'Policía Nacional · Escala Básica 2026',
      'access', false);
  end if;
  if exists (select 1 from public.program_assessment_tests
    where program_id = v_program) or exists (
      select 1 from public.program_assessment_scoring_rules
      where program_id = v_program) then
    raise exception 'El borrador CNP ya tiene pruebas o baremo; revisa antes de sembrar.';
  end if;

  insert into public.program_assessment_scoring_rules
    (program_id, scoring_version, source_url, source_label,
     aggregation, max_points, min_each_points, min_aggregate_points)
  values (v_program, 'boe_a_2026_15055_anexo_ii_v1',
    'https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055',
    'BOE-A-2026-15055, anexo II · Policía Nacional 2026',
    'average', 10, 1, 5);

  insert into public.program_assessment_tests
    (program_id, code, name, unit, better_direction, protocol_notes,
     category, group_code, display_order, mark_step)
  values (v_program, 'agility_circuit', 'Circuito de agilidad',
    'seconds', 'lower',
    'Circuito del anexo II. Tiempo en décimas. Un intento; segundo solo si el primero es nulo. Recorrido incorrecto, derribo o apoyo en obstáculos anulan el intento.',
    'both', 'agility', 1, 0.1)
  returning id into v_agility;

  insert into public.program_assessment_tests
    (program_id, code, name, unit, better_direction, protocol_notes,
     category, group_code, display_order, mark_step)
  values (v_program, 'pull_ups_men', 'Dominadas',
    'repetitions', 'higher',
    'Agarre prono, brazos extendidos al inicio y barbilla por encima de la barra. Sin balanceo ni impulso. Un intento; solo cuentan repeticiones válidas según anexo II.',
    'men', 'upper_body', 2, 1)
  returning id into v_pullups;

  insert into public.program_assessment_tests
    (program_id, code, name, unit, better_direction, protocol_notes,
     category, group_code, display_order, mark_step)
  values (v_program, 'bar_hang_women', 'Suspensión en barra',
    'seconds', 'higher',
    'Agarre supino y suspensión estática con barbilla por encima de la barra. La prueba termina cuando baja, toca la barra o incumple las reglas. Un intento según anexo II.',
    'women', 'upper_body', 2, 1)
  returning id into v_hang;

  insert into public.program_assessment_tests
    (program_id, code, name, unit, better_direction, protocol_notes,
     category, group_code, display_order, mark_step)
  values (v_program, 'run_1000_m', 'Carrera 1.000 m',
    'seconds', 'lower',
    'Carrera de 1.000 m en grupo sobre superficie lisa, plana y dura. Tiempo en minutos y segundos. Un intento; sin zapatillas de clavos, según anexo II.',
    'both', 'run_1000', 3, 1)
  returning id into v_run;

  -- Extremos incluidos; NULL representa el extremo abierto de «o más/menos».
  insert into public.program_assessment_score_bands
    (test_id, category, min_mark, max_mark, points)
  select v_agility, x.category, x.lo, x.hi, x.points
  from (values
    ('men',11.7::numeric,null::numeric,0),
    ('men',11.5,11.6,1),('men',11.3,11.4,2),
    ('men',11.0,11.2,3),('men',10.6,10.9,4),
    ('men',10.2,10.5,5),('men',9.8,10.1,6),
    ('men',9.4,9.7,7),('men',8.9,9.3,8),
    ('men',8.3,8.8,9),('men',null,8.2,10),
    ('women',12.8,null,0),('women',12.6,12.7,1),
    ('women',12.4,12.5,2),('women',12.1,12.3,3),
    ('women',11.7,12.0,4),('women',11.3,11.6,5),
    ('women',10.9,11.2,6),('women',10.4,10.8,7),
    ('women',9.9,10.3,8),('women',9.4,9.8,9),
    ('women',null,9.3,10)
  ) as x(category, lo, hi, points);

  insert into public.program_assessment_score_bands
    (test_id, category, min_mark, max_mark, points)
  select v_pullups, 'men', x.lo, x.hi, x.points
  from (values
    (null::numeric,4::numeric,0),
    (5,5,1),(6,6,2),(7,7,3),(8,9,4),
    (10,11,5),(12,13,6),(14,14,7),
    (15,15,8),(16,16,9),(17,null,10)
  ) as x(lo, hi, points);

  insert into public.program_assessment_score_bands
    (test_id, category, min_mark, max_mark, points)
  select v_hang, 'women', x.lo, x.hi, x.points
  from (values
    (null::numeric,35::numeric,0),
    (36,40,1),(41,45,2),(46,51,3),(52,56,4),
    (57,62,5),(63,69,6),(70,77,7),
    (78,85,8),(86,94,9),(95,null,10)
  ) as x(lo, hi, points);

  insert into public.program_assessment_score_bands
    (test_id, category, min_mark, max_mark, points)
  select v_run, x.category, x.lo, x.hi, x.points
  from (values
    ('men',229::numeric,null::numeric,0),
    ('men',223,228,1),('men',217,222,2),
    ('men',211,216,3),('men',205,210,4),
    ('men',199,204,5),('men',193,198,6),
    ('men',187,192,7),('men',181,186,8),
    ('men',175,180,9),('men',null,174,10),
    ('women',286,null,0),('women',277,285,1),
    ('women',268,276,2),('women',259,267,3),
    ('women',250,258,4),('women',241,249,5),
    ('women',232,240,6),('women',223,231,7),
    ('women',214,222,8),('women',205,213,9),
    ('women',null,204,10)
  ) as x(category, lo, hi, points);
end;
$$;

commit;
