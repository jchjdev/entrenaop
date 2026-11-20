begin;
set local statement_timeout = '25s';

do $$
declare
  fixture_program_id constant text := 'fas_periodic_assessment';
  admin_id uuid := gen_random_uuid();
  athlete_id uuid := gen_random_uuid();
  previous_name text;
  new_name text := 'TGCF prueba ' || gen_random_uuid();
  previous_program jsonb;
  previous_catalogs jsonb;
  previous_revisions jsonb;
begin
  select p.name, to_jsonb(p)-'name' into strict previous_name, previous_program
    from public.preparation_programs p where p.id=fixture_program_id;
  select jsonb_agg(to_jsonb(c) order by c.catalog_version) into previous_catalogs
    from public.preparation_program_catalogs c where c.program_id=fixture_program_id;
  select jsonb_agg(to_jsonb(r) order by r.revision) into previous_revisions
    from public.builtin_assessment_revisions r where r.program_id=fixture_program_id;
  insert into auth.users(id,email,email_confirmed_at) values
    (admin_id,admin_id||'@rename-preparation.invalid',now()),
    (athlete_id,athlete_id||'@rename-preparation.invalid',now());
  insert into public.admin_permissions(user_id,reason)
    values(admin_id,'Prueba transaccional de nombres de preparaciones');
  if has_function_privilege('anon','public.admin_rename_preparation_program(text,text,text)','execute') then
    raise exception 'Una sesión anónima tiene permiso para renombrar';
  end if;

  perform set_config('request.jwt.claim.sub',athlete_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',athlete_id,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  begin
    perform public.admin_rename_preparation_program(fixture_program_id,previous_name,new_name);
    raise exception 'Un deportista pudo renombrar la preparación';
  exception when insufficient_privilege then null; end;
  reset role;

  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  begin
    perform public.admin_rename_preparation_program(fixture_program_id,previous_name,new_name);
    raise exception 'ADMIN pudo renombrar sin MFA';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated','aal','aal2')::text,true);
  begin
    perform public.admin_rename_preparation_program(fixture_program_id,previous_name,'  ');
    raise exception 'Aceptó un nombre vacío';
  exception when invalid_parameter_value then null; end;
  perform public.admin_rename_preparation_program(fixture_program_id,previous_name,'  '||new_name||'  ');
  perform public.admin_rename_preparation_program(fixture_program_id,previous_name,new_name);
  begin
    perform public.admin_rename_preparation_program(fixture_program_id,previous_name,'Nombre con revisión antigua');
    raise exception 'Sobrescribió el nombre con una edición desfasada';
  exception when serialization_failure then null; end;
  reset role;

  if not exists(select 1 from public.preparation_programs p
      where p.id=fixture_program_id and p.name=new_name and to_jsonb(p)-'name'=previous_program)
    or (select jsonb_agg(to_jsonb(c) order by c.catalog_version) from public.preparation_program_catalogs c
        where c.program_id=fixture_program_id) is distinct from previous_catalogs
    or (select jsonb_agg(to_jsonb(r) order by r.revision) from public.builtin_assessment_revisions r
        where r.program_id=fixture_program_id) is distinct from previous_revisions then
    raise exception 'No se conservó la preparación o sus versiones de baremo';
  end if;
end $$;

rollback;
