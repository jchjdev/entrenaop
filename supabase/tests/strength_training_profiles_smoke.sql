-- Contrato deportivo y permisos. Todos los datos de prueba terminan en ROLLBACK.
begin;
select set_config('test.admin_id',(select user_id::text from public.admin_permissions limit 1),true);
select set_config('test.user_id',(select id::text from auth.users u where not exists(
  select 1 from public.admin_permissions a where a.user_id=u.id) limit 1),true);
-- El catálogo puede crecer; los permisos se contrastan con los enlaces reales,
-- no con el tamaño de la semilla que había al escribir esta prueba.
select set_config('test.all_profiles',(select count(*)::text
  from public.exercise_training_profiles),true);
select set_config('test.visible_profiles',(select count(*)::text
  from public.exercise_training_profiles p
  where exists(select 1 from public.exercises e
    where e.training_profile_code=p.code and e.training_profile_version=p.definition_version
      and e.origin='system' and e.is_public)
  or exists(select 1 from public.program_test_training_bindings b
    join public.preparation_programs g on g.id=b.program_id
    where b.profile_code=p.code and b.profile_version=p.definition_version and g.enabled)),true);
select set_config('test.visible_bindings',(select count(*)::text
  from public.program_test_training_bindings b
  join public.preparation_programs p on p.id=b.program_id where p.enabled),true);

do $$
declare v_definition jsonb; v_rejected boolean;
begin
  if (select count(*) from public.exercise_training_profiles where catalog_version=1)<>63 then
    raise exception 'La semilla no contiene 63 perfiles.'; end if;
  if (select count(*) from public.exercises e join public.exercise_training_profiles p on p.code=e.training_profile_code and p.definition_version=e.training_profile_version where p.catalog_version=1)<>63 then
    raise exception 'No se enlazaron las 63 variantes de la biblioteca.'; end if;
  select definition into v_definition from public.exercise_training_profiles where code='push_up_standard' and definition_version=1;
  insert into public.exercise_training_profiles(code,definition_version,catalog_version,definition)
  values('private_profile_fixture',1,999,v_definition||'{"code":"private_profile_fixture","name":"Perfil interno de prueba"}'::jsonb);
  if not public.valid_strength_exercise_definition(v_definition) then raise exception 'Perfil válido rechazado.'; end if;
  if public.valid_strength_exercise_definition(v_definition||'{"movement_modes":["desconocido"]}'::jsonb)
    or public.valid_strength_exercise_definition(v_definition||'{"measurement_options":[{"mode":"MAX_LOAD","load_modes":["bodyweight"]}]}'::jsonb)
    or public.valid_strength_exercise_definition(v_definition||'{"required_equipment":["push_up_handles"]}'::jsonb)
    or public.valid_strength_exercise_definition(v_definition||'{"primary_muscles":[]}'::jsonb)
    or public.valid_strength_exercise_definition(v_definition||'{"fatigue_score":4}'::jsonb)
    or public.valid_strength_exercise_definition('null'::jsonb) then
    raise exception 'La validación admitió metadatos incompatibles.'; end if;
  v_rejected:=false;
  begin update public.exercise_training_profiles set definition=definition||'{"name":"Cambio"}'::jsonb
    where code='push_up_standard'; exception when sqlstate '22023' then v_rejected:=true; end;
  if not v_rejected then raise exception 'Una definición histórica se pudo cambiar.'; end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.user_id'),true);

do $$
declare v_rejected boolean; v_personal uuid;
begin
  if current_setting('test.user_id')='' or current_setting('test.admin_id')='' then
    raise exception 'La prueba necesita administrador y usuario.'; end if;
  if (select count(*) from public.exercise_training_profiles)<>current_setting('test.visible_profiles')::int
    or exists(select 1 from public.exercise_training_profiles where code='private_profile_fixture') then
    raise exception 'RLS no distingue perfiles enlazados de contenido interno.'; end if;
  if (select count(*) from public.program_test_training_bindings)<>current_setting('test.visible_bindings')::int then
    raise exception 'El deportista leyó enlaces de un programa borrador.'; end if;
  v_rejected:=false;
  begin perform public.set_admin_exercise_training_profile(
    '20000000-0000-4000-8000-000000000001','push_up_standard',1);
    exception when sqlstate '42501' then v_rejected:=true; end;
  if not v_rejected then raise exception 'El usuario concedió metadatos oficiales.'; end if;
  v_rejected:=false;
  begin perform public.set_admin_program_test_training_binding(
    (select id from public.program_assessment_tests limit 1),'pull_up_pronated',1,'REPS','Revisión temporal de prueba.');
    exception when sqlstate '42501' then v_rejected:=true; end;
  if not v_rejected then raise exception 'El usuario vinculó pruebas oficiales.'; end if;
  v_personal:=public.create_personal_exercise('Ejercicio personal temporal',null,null,
    array['espalda'],array['barra'],'inicial','repeticiones');
  if not exists(select 1 from public.exercises where id=v_personal and training_profile_code is null and origin='user') then
    raise exception 'El flujo personal exige metadatos deportivos.'; end if;
  v_rejected:=false;
  begin update public.exercises set training_profile_code='push_up_standard',training_profile_version=1
    where id=v_personal; exception when check_violation then v_rejected:=true; end;
  if not v_rejected then raise exception 'El ejercicio personal adquirió perfil oficial por escritura directa.'; end if;
end $$;

select set_config('request.jwt.claim.sub',current_setting('test.admin_id'),true);
do $$
declare v_program text; v_test uuid; v_hang uuid; v_rejected boolean;
begin
  if (select count(*) from public.exercise_training_profiles)<>current_setting('test.all_profiles')::int+1
    or not exists(select 1 from public.exercise_training_profiles where code='private_profile_fixture') then
    raise exception 'ADMIN no puede leer el catálogo interno.'; end if;
  v_program:=public.create_admin_preparation_program('Programa de fuerza temporal','access');
  perform public.save_admin_program_scoring_rule(v_program,'strength_smoke_v1',
    'https://www.boe.es','Fuente de ensayo','average',10,1,5);
  v_test:=public.create_admin_program_assessment_test_v5(
    v_program,'pull_ups','Dominadas temporales','repetitions','higher',
    'Agarre prono, brazos extendidos y repeticiones válidas.','both','dominadas',
    1,1,18,60,1,'none',null,null);
  v_hang:=public.create_admin_program_assessment_test_v5(
    v_program,'hang','Suspensión temporal','seconds','higher',
    'Agarre supino y barbilla sobre la barra; finalizar al perder posición.','both','suspension',
    2,0.1,18,60,1,'none',null,null);
  v_rejected:=false;
  begin perform public.set_admin_program_test_training_binding(v_test,'front_plank_forearms',1,'DURATION','Revisión temporal de prueba.');
    exception when sqlstate '22023' then v_rejected:=true; end;
  if not v_rejected then raise exception 'Se vinculó duración a una prueba de repeticiones.'; end if;
  v_rejected:=false;
  begin perform public.set_admin_program_test_training_binding(v_test,'pull_up_pronated',1,'MAX_LOAD','Revisión temporal de prueba.');
    exception when sqlstate '22023' then v_rejected:=true; end;
  if not v_rejected then raise exception 'Se vinculó una medición no admitida por la variante.'; end if;
  perform public.set_admin_program_test_training_binding(v_test,'pull_up_pronated',1,'REPS','Agarre y medición revisados expresamente.');
  perform public.set_admin_program_test_training_binding(v_hang,'supinated_flexed_arm_hang',1,'DURATION','Agarre y posición revisados expresamente.');
  perform public.update_admin_program_assessment_test_v5(v_test,'Dominadas renombradas',
    'repetitions','higher','Agarre prono, brazos extendidos y repeticiones válidas.',
    'both',1,1,18,60,false,1,'none',null,null);
  if not exists(select 1 from public.program_test_training_bindings where test_id=v_test) then
    raise exception 'Un nombre editorial invalidó el protocolo.'; end if;
  perform public.update_admin_program_assessment_test_v5(v_test,'Dominadas renombradas',
    'repetitions','higher','Otro agarre y otro criterio de amplitud; necesita revisión.',
    'both',1,1,18,60,false,1,'none',null,null);
  if exists(select 1 from public.program_test_training_bindings where test_id=v_test) then
    raise exception 'Un protocolo alterado conservó el enlace anterior.'; end if;
  perform public.set_admin_program_test_training_binding(v_test,'pull_up_pronated',1,'REPS','Protocolo temporal revisado de nuevo.');
  perform set_config('test.strength_program',v_program,true);
  perform set_config('test.strength_test',v_test::text,true);
end $$;

reset role;
update public.preparation_programs set enabled=true where id=current_setting('test.strength_program');
set local role authenticated;
do $$
declare v_clone text; v_rejected boolean; v_test uuid:=current_setting('test.strength_test')::uuid;
begin
  v_rejected:=false;
  begin perform public.set_admin_program_test_training_binding(v_test,null,null,null,null);
    exception when sqlstate '22023' then v_rejected:=true; end;
  if not v_rejected then raise exception 'Se modificó un enlace publicado.'; end if;
  v_clone:=public.clone_admin_program_assessment_version_v2(
    current_setting('test.strength_program'),'Copia fuerza temporal','strength_smoke_v2');
  if (select count(*) from public.program_test_training_bindings where program_id=v_clone)<>2 then
    raise exception 'La copia perdió enlaces deportivos.'; end if;
  perform set_config('request.jwt.claim.sub',current_setting('test.user_id'),true);
  if (select count(*) from public.program_test_training_bindings where program_id=current_setting('test.strength_program'))<>2 then
    raise exception 'El deportista no lee los enlaces publicados.'; end if;
  if exists(select 1 from public.program_test_training_bindings where program_id=v_clone) then
    raise exception 'El deportista leyó los enlaces de la copia borrador.'; end if;
  if (select count(*) from public.program_test_training_bindings b
    join public.exercise_training_profiles d on d.code=b.profile_code
      and d.definition_version=b.profile_version
    where b.program_id=current_setting('test.strength_program'))<>2 then
    raise exception 'El deportista no puede resolver las definiciones publicadas.'; end if;
  if exists(select 1 from public.exercise_training_profiles where code='private_profile_fixture') then
    raise exception 'Publicar un programa expuso perfiles no utilizados.'; end if;
end $$;
select 'strength_training_profiles_smoke: OK' as result;
rollback;
