-- Contrato completo de autoría nativa. Solo Dev, siempre transaccional.
begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
select set_config('request.jwt.claims',jsonb_build_object('sub',auth.uid(),'role','authenticated','aal','aal2')::text,true);
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
update public.profiles set fecha_nacimiento=(now() at time zone 'Europe/Madrid')::date-interval '36 years' where id=auth.uid();
insert into public.preparation_goals(user_id,program_id,target_date) values
  (auth.uid(),'fas_periodic_assessment',current_date+30),(auth.uid(),'armed_forces_troop_entry',current_date+30);
set local role authenticated;

do $$
declare actor uuid:=auth.uid(); other_id uuid:=gen_random_uuid(); seed_fas jsonb; seed_troop jsonb; f jsonb; t jsonb; original jsonb;
  workspace jsonb; report jsonb; request_id uuid:=gen_random_uuid(); definition jsonb; invalid_definition jsonb;
  fas_goal uuid; troop_goal uuid; new_fas_goal uuid; new_troop_goal uuid; legacy_id uuid; fresh_id uuid; legacy_snapshot jsonb;
  marks jsonb:='[{"test_id":"upper_body_push_ups_2_min","value":20},{"test_id":"abdominal_plank","value":60000},{"test_id":"run_2000_m","value":700000},{"test_id":"agility_speed_circuit","value":15899}]';
  b jsonb; v_category text; zeros jsonb; result jsonb; value jsonb; i integer; count_minimums integer:=0; rejected boolean; old_edit integer; error_detail text;
begin
  if not public.is_admin() then raise exception 'La prueba necesita una cuenta admin con segundo factor ya verificado.'; end if;
  workspace:=public.admin_builtin_assessment_workspace('fas_periodic_assessment');
  select x into seed_fas from jsonb_array_elements(workspace->'revisions') x where x->>'revision'='1';
  workspace:=public.admin_builtin_assessment_workspace('armed_forces_troop_entry');
  select x into seed_troop from jsonb_array_elements(workspace->'revisions') x where x->>'revision'='1';
  if seed_fas is null or seed_troop is null then raise exception 'Falta alguna semilla.'; end if;
  if (select sum(jsonb_array_length(x->'rows')) from jsonb_array_elements(seed_fas->'definition'->'tests') x)<>306 then
    raise exception 'Se alteraron las 306 filas FAS.'; end if;
  if jsonb_array_length(seed_troop->'definition'->'standards')<>24 then raise exception 'Faltan mínimos Tropa.'; end if;
  -- El calculador completo reproduce los 64 mínimos originales, por columna.
  for b in select x from jsonb_array_elements(seed_fas->'definition'->'ageBands') x loop
    select jsonb_agg(jsonb_build_object('test_id',x->>'id','value',0)) into zeros from jsonb_array_elements(seed_fas->'definition'->'tests') x
      where x->>'requiredBelowAge' is null or (b->>'minAge')::integer < (x->>'requiredBelowAge')::integer;
    foreach v_category in array array['men','women'] loop
      result:=public.admin_builtin_assessment_preview((seed_fas->>'id')::uuid,v_category,(b->>'minAge')::integer,null,zeros);
      for value in select x from jsonb_array_elements(result->'results') x loop
        if not exists(select 1 from public.fas_periodic_standards s where s.catalog_version=seed_fas->>'catalog_version'
          and s.test_id=value->>'test_id' and s.category=v_category and s.age_band=b->>'id' and s.threshold=(value->>'threshold')::bigint) then
          raise exception 'Un mínimo FAS no coincide con su tabla completa.';
        end if;
        count_minimums:=count_minimums+1;
      end loop;
    end loop;
  end loop;
  if count_minimums<>64 then raise exception 'No se comprobaron los 64 mínimos.'; end if;
  select id into fas_goal from public.preparation_goals where user_id=actor and program_id='fas_periodic_assessment' and status='active';
  select id into troop_goal from public.preparation_goals where user_id=actor and program_id='armed_forces_troop_entry' and status='active';
  legacy_id:=public.record_fas_periodic_assessment(fas_goal,'men',36,marks,now());
  select jsonb_agg(to_jsonb(x) order by test_id) into legacy_snapshot from public.fas_periodic_results x where assessment_id=legacy_id;

  f:=public.admin_builtin_assessment_create_revision('fas_periodic_assessment',(seed_fas->>'id')::uuid,request_id);
  if public.admin_builtin_assessment_create_revision('fas_periodic_assessment',(seed_fas->>'id')::uuid,request_id)->>'id'<>f->>'id' then
    raise exception 'El reintento creó un segundo borrador.'; end if;
  rejected:=false;
  begin perform public.admin_builtin_assessment_create_revision('armed_forces_troop_entry',(seed_troop->>'id')::uuid,request_id);
  exception when serialization_failure then rejected:=true; end;
  if not rejected then raise exception 'Se reutilizó una solicitud para otro programa.'; end if;

  -- Los metadatos incompletos se guardan en borrador, pero no se publican.
  definition:=jsonb_set(jsonb_set(f->'definition','{name}','""'),'{effectiveFrom}','""');
  f:=public.admin_builtin_assessment_save((f->>'id')::uuid,(f->>'edit_version')::integer,definition,'');
  report:=public.admin_builtin_assessment_review((f->>'id')::uuid);
  if jsonb_array_length(report->'issues')=0 then raise exception 'Se aprobó un borrador incompleto.'; end if;
  rejected:=false;
  begin perform public.admin_builtin_assessment_publish((f->>'id')::uuid,(f->>'edit_version')::integer);
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se publicó un borrador incompleto.'; end if;

  -- La estructura y la identidad de filas se protegen incluso al guardar.
  invalid_definition:=jsonb_set(f->'definition','{tests,0,unit}','"milliseconds"'); rejected:=false;
  begin perform public.admin_builtin_assessment_save((f->>'id')::uuid,(f->>'edit_version')::integer,invalid_definition,'Cambio inválido');
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se cambió la unidad histórica de una prueba.'; end if;
  definition:=jsonb_set(seed_fas->'definition','{version}',to_jsonb(f->>'scoring_version'));
  definition:=jsonb_set(definition,'{effectiveFrom}',to_jsonb((now() at time zone 'Europe/Madrid')::date::text));
  invalid_definition:=jsonb_set(definition,'{tests,0,rows,0,1,0}','0');
  f:=public.admin_builtin_assessment_save((f->>'id')::uuid,(f->>'edit_version')::integer,invalid_definition,'Ensayo incoherente');
  report:=public.admin_builtin_assessment_review((f->>'id')::uuid);
  if jsonb_array_length(report->'issues')=0 then raise exception 'Se permitió introducir una incoherencia nueva de puntos.'; end if;
  rejected:=false;
  begin perform public.admin_builtin_assessment_publish((f->>'id')::uuid,(f->>'edit_version')::integer);
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se publicó una incoherencia nueva.'; end if;
  -- Una columna coherente puede actualizarse; las anomalías originales de
  -- carrera se conservan literalmente y siguen dando aviso, no un falso error.
  for i in 0..jsonb_array_length(definition->'tests'->0->'rows')-1 loop
    definition:=jsonb_set(definition,array['tests','0','rows',i::text,'1','0'],
      to_jsonb(least(100,(definition->'tests'->0->'rows'->i->1->>0)::integer+1)));
  end loop;
  old_edit:=(f->>'edit_version')::integer;
  f:=public.admin_builtin_assessment_save((f->>'id')::uuid,old_edit,definition,'Revisión de ensayo coherente');
  rejected:=false;
  begin perform public.admin_builtin_assessment_save((f->>'id')::uuid,old_edit,definition,'Escritura retrasada');
  exception when serialization_failure then rejected:=true; end;
  if not rejected then raise exception 'Se perdió el control de concurrencia.'; end if;
  report:=public.admin_builtin_assessment_review((f->>'id')::uuid);
  if jsonb_array_length(report->'issues')<>0 or jsonb_array_length(report->'warnings')=0 or (report->>'change_count')::integer=0 then
    raise exception 'La revisión FAS válida no conserva sus advertencias y cambios: %',report; end if;

  -- Un admin sin AAL2 no ve borradores ni puede modificarlos.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','aal','aal1')::text,true);
  if exists(select 1 from public.builtin_assessment_revisions where status='draft') then raise exception 'AAL1 ve borradores.'; end if;
  rejected:=false;
  begin perform public.admin_builtin_assessment_workspace('fas_periodic_assessment');
  exception when insufficient_privilege then rejected:=true; end;
  if not rejected then raise exception 'AAL1 accede al espacio editorial.'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','aal','aal2')::text,true);
  f:=public.admin_builtin_assessment_publish((f->>'id')::uuid,(f->>'edit_version')::integer);
  if (select count(*) from public.fas_periodic_standards where catalog_version=f->>'catalog_version')<>64 then raise exception 'La proyección FAS está incompleta.'; end if;
  select jsonb_agg(to_jsonb(x) order by test_id) into result from public.fas_periodic_results x where assessment_id=legacy_id;
  if result is distinct from legacy_snapshot then raise exception 'Publicar alteró un intento histórico.'; end if;
  if public.builtin_assessment_reference('fas_periodic_assessment',fas_goal)->>'id'<>seed_fas->>'id' then raise exception 'Se migró una preparación activa sin consentimiento.'; end if;
  -- Un cliente antiguo continúa funcionando en su preparación fijada a semilla.
  perform public.record_fas_periodic_assessment(fas_goal,'men',36,marks,now());
  update public.preparation_goals set status='archived',archived_at=now() where id=fas_goal;
  insert into public.preparation_goals(user_id,program_id,target_date) values(actor,'fas_periodic_assessment',current_date+30) returning id into new_fas_goal;
  if public.builtin_assessment_reference('fas_periodic_assessment',new_fas_goal)->>'id'<>f->>'id' then raise exception 'La alta nueva no eligió la revisión publicada.'; end if;
  rejected:=false;
  begin perform public.record_fas_periodic_assessment(new_fas_goal,'men',36,marks,now());
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Un cliente antiguo guardó en una revisión nueva.'; end if;
  fresh_id:=public.record_builtin_assessment((f->>'id')::uuid,new_fas_goal,'men',36,null,marks,now());
  select result_snapshot into result from public.fas_periodic_assessments where id=fresh_id;
  if result->>'revision_id'<>f->>'id' then raise exception 'El snapshot perdió su revisión.'; end if;
  select x into value from jsonb_array_elements(result->'results') x where x->>'test_id'='agility_speed_circuit';
  if (value->>'scored_mark')::integer<>15800 or (value->>'points')::integer<20 or not (value->>'meets_minimum')::boolean then
    raise exception 'No se respetó la resolución de décimas en agilidad: %',value; end if;
  if not exists(select 1 from public.fas_periodic_results where assessment_id=fresh_id and test_id='agility_speed_circuit' and meets_minimum) then
    raise exception 'La vista nueva no coincide con los puntos del servidor.'; end if;
  -- La calculadora personal conserva los campos y pide actualizar expresamente
  -- cuando una publicación deja obsoleta la revisión que estaba abierta.
  rejected:=false;
  begin perform public.record_builtin_assessment((seed_fas->>'id')::uuid,null,'men',36,null,marks,now());
  exception when invalid_parameter_value then
    get stacked diagnostics error_detail=pg_exception_detail;
    rejected:=error_detail='builtin_reference_changed';
  end;
  if not rejected then raise exception 'Falta la señal recuperable de cambio de baremo personal.'; end if;
  rejected:=false;
  begin perform public.record_builtin_assessment((seed_fas->>'id')::uuid,new_fas_goal,'men',36,null,marks,now());
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se cruzaron revisión y preparación.'; end if;
  f:=public.admin_builtin_assessment_withdraw((f->>'id')::uuid,(f->>'edit_version')::integer);
  if public.builtin_assessment_reference('fas_periodic_assessment',new_fas_goal)->>'id'<>f->>'id' then raise exception 'Retirar rompió un vínculo histórico.'; end if;
  perform public.record_builtin_assessment((f->>'id')::uuid,new_fas_goal,'men',36,null,marks,now());
  if public.builtin_assessment_reference('fas_periodic_assessment')->>'id'<>seed_fas->>'id' then raise exception 'Se selecciona una revisión retirada en la calculadora.'; end if;

  t:=public.admin_builtin_assessment_create_revision('armed_forces_troop_entry',(seed_troop->>'id')::uuid,gen_random_uuid());
  definition:=jsonb_set(t->'definition','{standards,0,threshold}',to_jsonb((t->'definition'->'standards'->0->>'threshold')::bigint+1));
  t:=public.admin_builtin_assessment_save((t->>'id')::uuid,(t->>'edit_version')::integer,definition,'Revisión de mínimos de ensayo');
  t:=public.admin_builtin_assessment_publish((t->>'id')::uuid,(t->>'edit_version')::integer);
  if (select count(*) from public.assessment_standards where catalog_version=t->>'catalog_version')<>24 then raise exception 'Tropa no conserva sus 24 mínimos.'; end if;
  perform public.record_troop_goal_assessment(troop_goal,seed_troop->>'catalog_version','men',marks,now());
  update public.preparation_goals set status='archived',archived_at=now() where id=troop_goal;
  insert into public.preparation_goals(user_id,program_id,target_date) values(actor,'armed_forces_troop_entry',current_date+30) returning id into new_troop_goal;
  fresh_id:=public.record_builtin_assessment((t->>'id')::uuid,new_troop_goal,'men',null,'entry',marks,now());
  if not exists(select 1 from public.physical_assessments where id=fresh_id and catalog_version=t->>'catalog_version') then raise exception 'Tropa guardó otra versión.'; end if;
  rejected:=false;
  begin update public.preparation_goals set program_id='fas_periodic_assessment' where id=new_troop_goal;
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'El propietario reconvirtió una preparación con historial.'; end if;
  perform set_config('request.jwt.claim.sub',other_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',other_id,'role','authenticated','aal','aal2')::text,true);
  rejected:=false;
  begin perform public.builtin_assessment_reference('armed_forces_troop_entry',new_troop_goal);
  exception when insufficient_privilege then rejected:=true; end;
  if not rejected then raise exception 'Otra cuenta leyó el contexto de la preparación.'; end if;
  rejected:=false;
  begin perform public.admin_builtin_assessment_workspace('armed_forces_troop_entry');
  exception when insufficient_privilege then rejected:=true; end;
  if not rejected then raise exception 'Un usuario no admin entró en autoría.'; end if;
  rejected:=false;
  begin perform public.admin_builtin_assessment_create_revision('armed_forces_troop_entry',(seed_troop->>'id')::uuid,gen_random_uuid());
  exception when insufficient_privilege then rejected:=true; end;
  if not rejected then raise exception 'Un usuario no admin creó una revisión.'; end if;
  rejected:=false;
  begin perform public.record_builtin_assessment((t->>'id')::uuid,new_troop_goal,'men',null,'entry',marks,now());
  exception when insufficient_privilege then rejected:=true; end;
  if not rejected then raise exception 'Otra cuenta guardó marcas en una preparación ajena.'; end if;
  perform set_config('request.jwt.claim.sub',actor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','aal','aal2')::text,true);
end $$;

reset role;
-- Las guardas protegen también contra una operación accidental de mantenimiento.
do $$
declare rejected boolean;
begin
  rejected:=false;
  begin update public.assessment_standards set threshold=threshold+1 where catalog_version='es_def_15_2026_troop_v1';
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se sobreescribió un mínimo publicado.'; end if;
  rejected:=false;
  begin insert into public.assessment_standards(catalog_version,test_id,category,milestone,threshold)
    values('es_def_15_2026_troop_v1','run_2000_m','men','entry',1);
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se añadió una fila a un catálogo inmutable.'; end if;
  insert into public.assessment_catalogs(version,name,source_url,effective_from)
    values('builtin_unpublished_smoke','Ensayo sin publicar','https://example.test/',current_date);
  insert into public.assessment_standards(catalog_version,test_id,category,milestone,threshold)
    values('builtin_unpublished_smoke','run_2000_m','men','entry',1);
  rejected:=false;
  begin update public.assessment_standards set catalog_version='es_def_15_2026_troop_v1' where catalog_version='builtin_unpublished_smoke';
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se movió una fila hacia un catálogo inmutable.'; end if;
  rejected:=false;
  begin update public.physical_test_definitions set unit='repetitions' where id='run_2000_m';
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se cambió una unidad histórica compartida.'; end if;
  rejected:=false;
  begin update public.builtin_assessment_revisions set definition=jsonb_set(definition,'{name}','"Cambio oculto"') where revision=1;
  exception when invalid_parameter_value then rejected:=true; end;
  if not rejected then raise exception 'Se sobreescribió una revisión publicada.'; end if;
end $$;
rollback;
