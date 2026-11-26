-- Calentamientos privados y oficiales, versiones y ejecución de una pauta real.
begin;
set local statement_timeout = '45s';
do $$
declare
  trainer uuid := gen_random_uuid();
  athlete uuid := gen_random_uuid();
  admin uuid := gen_random_uuid();
  relation uuid := gen_random_uuid();
  assigned uuid := gen_random_uuid();
  exercise uuid;
  warmup uuid;
  warmup_revision uuid;
  official uuid;
  official_template uuid;
  admin_session uuid;
  required_session uuid;
  optional_session uuid;
  execution uuid;
  warm_set uuid;
  recipe jsonb;
  running jsonb;
begin
  insert into auth.users(id,email) select id, id || '@session-warmups.invalid'
    from unnest(array[trainer,athlete,admin]) as id;
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
    select gen_random_uuid(), id, 'totp', 'verified', now(), now() from unnest(array[trainer,admin]) as id;
  insert into public.admin_permissions(user_id) values(admin);
  insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
    values(trainer,true,2,'Prueba de calentamientos');
  insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at)
    values(relation,trainer,athlete,now());
  select id into strict exercise from public.exercises
  where origin='system' and is_public and trashed_at is null
    and id <> '20000000-0000-4000-8000-000000000004' order by id limit 1;
  recipe := jsonb_build_object('name','Movilidad de prueba','blocks',jsonb_build_array(
    jsonb_build_object('name','Activación','format','straight_sets','rounds',1,'rest_after_seconds',0,
      'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',
        '[{"target_reps":8,"rest_after_seconds":15},{"target_reps":10,"rest_after_seconds":25}]'::jsonb)))));
  running := '{"name":"Carrera con activación",
    "blocks":[{"name":"Carrera","format":"running","exercises":[
      {"exercise_id":"20000000-0000-4000-8000-000000000004","sets":[
        {"target_duration_seconds":600,"rest_after_seconds":0}]}]}]}'::jsonb;

  perform set_config('request.jwt.claim.sub',trainer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  warmup := public.save_trainer_workout(gen_random_uuid(), recipe || '{"is_private_warmup":true}');
  if jsonb_array_length(public.list_trainer_workouts()) <> 0 or
     jsonb_array_length(public.search_trainer_workouts('movilidad')) <> 0 then
    raise exception 'Un calentamiento privado aparece en las sesiones pautables.';
  end if;
  begin
    perform public.assign_trainer_workout(gen_random_uuid(),relation,warmup,current_date,null);
    raise exception 'Se ha pautado un calentamiento de biblioteca como sesión.';
  exception when invalid_parameter_value or insufficient_privilege then null; end;
  required_session := public.save_trainer_workout(gen_random_uuid(), running ||
    jsonb_build_object('warmup_template_id',warmup,'warmup_can_be_skipped',false));
  perform public.assign_trainer_workout(assigned,relation,required_session,current_date,null);
  warmup_revision := public.save_trainer_workout(gen_random_uuid(),
    jsonb_set(recipe,'{name}','"Movilidad revisada"') || '{"is_private_warmup":true}',warmup);
  if not exists(select 1 from public.workout_templates where id=warmup_revision and is_private_warmup
    and previous_version_id=warmup and version=2) then raise exception 'No conserva las versiones privadas.'; end if;
  optional_session := public.save_trainer_workout(gen_random_uuid(), recipe ||
    jsonb_build_object('warmup_template_id',warmup_revision));
  if not exists(select 1 from public.workout_templates where id=optional_session
    and warmup_can_be_skipped) then raise exception 'El calentamiento debería ser opcional por defecto.'; end if;

  perform set_config('request.jwt.claim.sub',admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',admin,'role','authenticated','aal','aal2')::text,true);
  if exists(select 1 from public.workout_templates where id=warmup_revision) then
    raise exception 'ADMIN ve la biblioteca privada de un preparador.';
  end if;
  begin
    perform public.create_admin_workout_draft(null, recipe || jsonb_build_object('warmup_template_id',warmup_revision));
    raise exception 'ADMIN ha incorporado un calentamiento privado de otro usuario.';
  exception when insufficient_privilege then null; end;
  official := public.save_guided_warmup(recipe);
  reset role;
  update public.guided_warmups set status='published' where id=official returning template_id into official_template;
  set local role authenticated;
  admin_session := public.create_admin_workout_draft(null, running || jsonb_build_object('warmup_template_id',official_template));
  reset role;
  if not exists (select 1 from public.workout_blocks where template_id=admin_session and attached_warmup and order_index=0)
    then raise exception 'La sesión oficial de carrera perdió el calentamiento.'; end if;
  if not exists (select 1 from public.workout_blocks where template_id=admin_session and format='running' and order_index=1)
    then raise exception 'El tramo principal no quedó después del calentamiento.'; end if;

  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',athlete,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  if exists(select 1 from public.workout_templates where id in (warmup,warmup_revision)) then
    raise exception 'El alumno ve la biblioteca privada sin que se la hayan compartido.';
  end if;
  execution := public.start_scheduled_workout(assigned);
  select id into strict warm_set from public.workout_execution_sets
  where execution_id=execution and block_format='warm_up' and set_order=0
    and target_reps=8 and rest_after_seconds=15 and not warmup_can_be_skipped;
  begin
    perform public.skip_workout_set(warm_set);
    raise exception 'Se pudo saltar un calentamiento obligatorio.';
  exception when invalid_parameter_value then null; end;
  if (select array_agg(target_reps order by set_order) from public.workout_execution_sets
    where execution_id=execution and block_format='warm_up') is distinct from array[8,10] then
    raise exception 'Cambió la dosis de un calentamiento ya pautado.';
  end if;
  reset role;
end;
$$;
select 'reusable_session_warmups: OK' as result;
rollback;
