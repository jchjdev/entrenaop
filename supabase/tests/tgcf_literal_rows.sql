-- Ejecutar solo contra Dev. Cualquier escritura de prueba termina en ROLLBACK.
begin;

create temporary table tgcf_checks (cells integer, intervals integer, targets integer) on commit drop;

do $$
declare
  seed public.builtin_assessment_revisions;
  t jsonb; column_index integer; column_count integer; higher boolean;
  cell record; mark_step integer; candidate bigint; expected integer;
  band jsonb; test_category text; preview jsonb; item jsonb; marks jsonb;
  exact_checks integer:=0; interval_checks integer:=0; target_checks integer:=0;
begin
  select * into strict seed from public.builtin_assessment_revisions
  where program_id='fas_periodic_assessment' and revision=1;
  for t in select value from jsonb_array_elements(seed.definition->'tests') loop
    column_count:=jsonb_array_length(t->'rows'->0->1);
    higher:=t->>'betterDirection'='higher';
    mark_step:=case t->>'id' when 'upper_body_push_ups_2_min' then 1
      when 'agility_speed_circuit' then 100 else 1000 end;
    for column_index in 0..column_count-1 loop
      for cell in
        with cells as (
          select (x->>0)::bigint as mark,(x->1->>column_index)::integer as points
          from jsonb_array_elements(t->'rows') x
        )
        select *,lead(mark) over(order by mark) as next_mark,
          lead(points) over(order by mark) as next_points from cells
      loop
        if builtin_assessment_private.fas_score_literal(t->'rows',column_index,higher,cell.mark)
          is distinct from cell.points then
          raise exception 'Fila literal distinta: % col % marca %',t->>'id',column_index,cell.mark;
        end if;
        exact_checks:=exact_checks+1;
        candidate:=cell.mark+mark_step;
        expected:=case when higher and cell.points<=cell.next_points then cell.points
          when not higher and cell.points>=cell.next_points then cell.next_points else null end;
        while candidate<cell.next_mark loop
          if builtin_assessment_private.fas_score_literal(t->'rows',column_index,higher,candidate)
            is distinct from expected then
            raise exception 'Intervalo distinto: % col % marca %',t->>'id',column_index,candidate;
          end if;
          interval_checks:=interval_checks+1;
          candidate:=candidate+mark_step;
        end loop;
      end loop;
    end loop;
  end loop;

  for band in select value from jsonb_array_elements(seed.definition->'ageBands') loop
    foreach test_category in array array['men','women'] loop
      select jsonb_agg(jsonb_build_object('test_id',x->>'id','value',0)) into marks
      from jsonb_array_elements(seed.definition->'tests') x
      where x->>'requiredBelowAge' is null or (band->>'minAge')::integer<(x->>'requiredBelowAge')::integer;
      preview:=builtin_assessment_private.preview_definition(seed.definition,seed.catalog_version,seed.scoring_version,
        test_category,(band->>'minAge')::integer,null,marks);
      for item in select value from jsonb_array_elements(preview->'results') loop
        if not exists(select 1 from public.fas_periodic_standards s where s.catalog_version=seed.catalog_version
          and s.test_id=item->>'test_id' and s.category=test_category and s.age_band=band->>'id'
          and s.threshold=(item->>'threshold')::bigint) then
          raise exception 'Mínimo distinto del publicado.';
        end if;
        target_checks:=target_checks+2;
      end loop;
      select jsonb_agg(jsonb_build_object('test_id',x->>'test_id','value',(x->>'threshold')::bigint)) into marks
      from jsonb_array_elements(preview->'results') x;
      if (builtin_assessment_private.preview_definition(seed.definition,seed.catalog_version,seed.scoring_version,
        test_category,(band->>'minAge')::integer,null,marks)->>'meets_all_minimums') is distinct from 'true' then
        raise exception 'Los mínimos de la API no superan el baremo.';
      end if;
      select jsonb_agg(jsonb_build_object('test_id',x->>'test_id','value',(x->>'maximum_mark')::bigint)) into marks
      from jsonb_array_elements(preview->'results') x;
      if exists(select 1 from jsonb_array_elements(builtin_assessment_private.preview_definition(
        seed.definition,seed.catalog_version,seed.scoring_version,test_category,(band->>'minAge')::integer,null,marks)->'results') x
        where x->>'points' is distinct from '100') then
        raise exception 'Los máximos de la API no obtienen 100 puntos.';
      end if;
    end loop;
  end loop;
  if exact_checks<>4152 or interval_checks<9000 or target_checks<>128 then
    raise exception 'Cobertura insuficiente: % % %',exact_checks,interval_checks,target_checks;
  end if;
  insert into tgcf_checks values(exact_checks,interval_checks,target_checks);
end $$;

-- Un intento con la política anterior permanece intacto y el nuevo guarda 0.
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
select set_config('request.jwt.claims',jsonb_build_object('sub',auth.uid(),'role','authenticated','aal','aal2')::text,true);
update public.profiles set fecha_nacimiento=(now() at time zone 'Europe/Madrid')::date-interval '60 years' where id=auth.uid();
set local role authenticated;

do $$
declare
  actor uuid:=auth.uid(); revision uuid; snapshot jsonb; row_before jsonb; row_after jsonb;
  attempt uuid; old_attempt uuid; detail text; baseline_count bigint; preview jsonb;
  marks jsonb:='[{"test_id":"upper_body_push_ups_2_min","value":20},{"test_id":"abdominal_plank","value":60000},{"test_id":"run_2000_m","value":962000}]';
begin
  if actor is null then raise exception 'Falta una cuenta de prueba Dev.'; end if;
  revision:=(public.builtin_assessment_reference('fas_periodic_assessment')->>'id')::uuid;
  old_attempt:=public.record_builtin_assessment(revision,null,'women',60,null,jsonb_set(marks,'{2,value}','982000'),now());
  select result_snapshot into row_before from public.fas_periodic_assessments where id=old_attempt;
  if row_before is null then raise exception 'Falta el resultado de control.'; end if;

  begin
    perform public.record_builtin_assessment(revision,null,'women',60,null,marks,now());
    raise exception 'Un cliente anterior guardó una puntuación discrepante.';
  exception when invalid_parameter_value then
    get stacked diagnostics detail=pg_exception_detail;
    if detail is distinct from 'fas_scoring_policy_changed' then raise; end if;
  end;
  begin
    perform public.record_fas_periodic_assessment(null,'women',60,marks,now());
    raise exception 'El RPC legado guardó una puntuación discrepante.';
  exception when invalid_parameter_value then
    get stacked diagnostics detail=pg_exception_detail;
    if detail is distinct from 'fas_scoring_policy_changed' then raise; end if;
  end;
  attempt:=public.record_builtin_assessment(revision,null,'women',60,null,marks,now(),'literal_rows_v2');
  select result_snapshot into snapshot from public.fas_periodic_assessments where id=attempt;
  if snapshot->>'scoring_policy' is distinct from 'literal_rows_v2' or snapshot->>'meets_all_minimums' is distinct from 'false'
    or not exists(select 1 from jsonb_array_elements(snapshot->'results') x
      where x->>'test_id'='run_2000_m' and x->>'points'='0' and x->>'meets_minimum'='false')
    or not exists(select 1 from public.fas_periodic_results where assessment_id=attempt and test_id='run_2000_m' and not meets_minimum) then
    raise exception 'El servidor no guardó o no mostró la fila literal de 16:02.';
  end if;

  marks:=jsonb_set(marks,'{2,value}','970000');
  preview:=public.admin_builtin_assessment_preview(revision,'women',60,null,marks);
  if preview->'meets_all_minimums' is distinct from 'null'::jsonb or not exists(
    select 1 from jsonb_array_elements(preview->'results') x where x->>'test_id'='run_2000_m'
      and x->'points'='null'::jsonb and x->'meets_minimum'='null'::jsonb) then
    raise exception 'El servidor no marcó 16:10 como indeterminado.';
  end if;
  select count(*) into baseline_count from public.fas_periodic_assessments where user_id=actor;
  begin
    perform public.record_builtin_assessment(revision,null,'women',60,null,marks,now(),'literal_rows_v2');
    raise exception 'Se guardó un resultado indeterminado.';
  exception when invalid_parameter_value then
    get stacked diagnostics detail=pg_exception_detail;
    if detail is distinct from 'fas_score_indeterminate' then raise; end if;
  end;
  if (select count(*) from public.fas_periodic_assessments where user_id=actor)<>baseline_count then
    raise exception 'El guardado rechazado dejó un intento.';
  end if;
  select result_snapshot into row_after from public.fas_periodic_assessments where id=old_attempt;
  if row_before is distinct from row_after then raise exception 'Cambió un resultado guardado.'; end if;
end $$;

reset role;
select * from tgcf_checks;
rollback;
