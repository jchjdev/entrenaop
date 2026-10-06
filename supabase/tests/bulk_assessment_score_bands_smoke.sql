-- Una tabla pegada se sustituye entera o no se cambia nada.
begin;
select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_test uuid;
  v_count integer;
  v_rejected boolean := false;
begin
  v_program := public.create_admin_preparation_program('Temporal importación', 'access');
  perform public.save_admin_program_scoring_rule_v3(v_program,'tabla_v1',
    'https://www.boe.es/','Fuente temporal','points','none',10,1,0,
    'assessment_date',null,'Ingreso',null,null);
  v_test := public.create_admin_program_assessment_test_v3(v_program,
    'flexiones','Flexiones','repetitions','higher','Flexiones válidas en dos minutos.',
    'men','flexiones',1,1,18,30);
  v_count := public.import_admin_program_score_bands(v_test,
    jsonb_build_array(
      jsonb_build_object('category','men','min_age',18,'max_age',30,
        'min_mark',0,'max_mark',4,'points',0),
      jsonb_build_object('category','men','min_age',18,'max_age',30,
        'min_mark',5,'max_mark',null,'points',10)),true);
  if v_count <> 2 or (select count(*) from public.program_assessment_score_bands
      where test_id = v_test) <> 2 then
    raise exception 'La importación no guardó las dos filas.';
  end if;
  begin
    perform public.import_admin_program_score_bands(v_test,
      jsonb_build_array(
        jsonb_build_object('category','men','min_age',18,'max_age',30,
          'min_mark',0,'max_mark',4,'points',0),
        jsonb_build_object('category','men','min_age',18,'max_age',30,
          'min_mark',4,'max_mark',null,'points',10)),true);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se aceptó una tabla con solapes.'; end if;
  if (select count(*) from public.program_assessment_score_bands
      where test_id = v_test) <> 2 then
    raise exception 'Una importación fallida destruyó la tabla anterior.';
  end if;
end;
$$;
rollback;
