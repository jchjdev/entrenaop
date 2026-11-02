-- Retirar Pro conserva consulta e historial; nunca concede otro inicio adaptativo.
begin;
set local statement_timeout = '45s';

do $$
declare
  athlete uuid := gen_random_uuid();
  stranger uuid := gen_random_uuid();
  trainer uuid := gen_random_uuid();
  goal uuid;
  relation uuid := gen_random_uuid();
  exercise uuid;
  template uuid;
  own_template uuid;
  coach_template uuid;
  coach_schedule uuid := gen_random_uuid();
  official uuid;
  grant_id uuid;
  block_id uuid;
  item_id uuid;
  schedules uuid[] := array[gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  templates uuid[] := '{}';
  preview jsonb;
  pro_preview jsonb;
  setup jsonb;
  initial_state jsonb;
  payload jsonb;
  opened uuid;
  other_opened uuid;
  set_id uuid;
  before_count integer;
  error_detail text;
  i integer;
begin
  insert into auth.users(id,email) values
    (athlete, athlete || '@adaptive-pro.invalid'),
    (stranger, stranger || '@adaptive-pro.invalid'),
    (trainer, trainer || '@adaptive-pro.invalid');
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
    values(gen_random_uuid(),trainer,'totp','verified',now(),now());
  insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
    values(trainer,true,1,'Ensayo de acceso adaptativo');
  insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at)
    values(relation,trainer,athlete,now());
  insert into public.preparation_goals(user_id,program_id,target_date)
    values(athlete,'fas_periodic_assessment',current_date+90) returning id into goal;
  -- Representa un antiguo Pro sin depender de las compras reales del proyecto.
  insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
    values(athlete,'development_manual',now()-interval '2 days',now()-interval '1 day','Ensayo vencido');
  select id into exercise from public.exercises where is_public
    and id <> '20000000-0000-4000-8000-000000000004' order by id limit 1;
  if exercise is null then raise exception 'Falta un ejercicio oficial para el ensayo.'; end if;
  for i in 1..3 loop
    insert into public.workout_templates(name,origin,owner_user_id,visibility,status,version)
      values('Adaptativo conservado ' || i,'algorithm',athlete,'private','published',1)
      returning id into template;
    templates := array_append(templates,template);
    insert into public.workout_blocks(template_id,order_index,name,format)
      values(template,0,'Trabajo publicado','straight_sets') returning id into block_id;
    insert into public.workout_items(block_id,exercise_id,order_index)
      values(block_id,exercise,0) returning id into item_id;
    insert into public.workout_sets(item_id,order_index,target_reps,rest_after_seconds)
      values(item_id,0,8,60);
    insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,
      scheduled_date,preparation_goal_id,source)
      values(schedules[i],athlete,template,'Adaptativo conservado ' || i,1,current_date,goal,'algorithm');
  end loop;
  payload := jsonb_build_object('name','Sesión propia Free','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,
      'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',athlete,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  if public.get_my_pro_access()->>'tier' <> 'free' then raise exception 'El ensayo debe empezar en Free.'; end if;
  select count(*) into before_count from public.workout_executions where user_id=athlete;
  preview := public.get_scheduled_workout_preview(athlete,schedules[1]);
  if preview->>'pro_required' <> 'true'
    or preview#>>'{template,id}' <> templates[1]::text then
    raise exception 'Free no conserva la pauta exacta o recibe permiso de otro inicio.';
  end if;
  setup := public.get_preparation_training_setup(goal);
  initial_state := setup->'program_state';
  if setup->>'pro_required' <> 'true' then raise exception 'La preparación no explica el bloqueo comercial.'; end if;
  for i in 1..3 loop
    begin
      if i=1 then perform public.start_scheduled_workout(schedules[1]);
      elsif i=2 then perform public.start_reviewed_scheduled_workout(athlete,schedules[1],preview->>'revision');
      else perform public.start_workout_execution(templates[1]); end if;
      raise exception 'Free inicia una sesión adaptativa por la entrada %.',i;
    exception when raise_exception then
      get stacked diagnostics error_detail = pg_exception_detail;
      if error_detail is distinct from 'pro_required' then raise; end if;
    end;
  end loop;
  if (select count(*) from public.workout_executions where user_id=athlete) <> before_count then
    raise exception 'Rechazar el inicio deja una ejecución parcial.';
  end if;
  if (public.get_preparation_training_setup(goal)->'program_state') is distinct from initial_state then
    raise exception 'Comprobar el derecho modifica el estado deportivo.';
  end if;
  -- Las sesiones propias y las oficiales siguen siendo utilizables en Free.
  own_template := public.create_personal_workout_template(payload);
  perform public.start_workout_execution(own_template);
  select t.id into official from public.workout_templates t where t.origin='system'
    and t.visibility='public' and t.status='published' and exists(
      select 1 from public.workout_blocks b join public.workout_items w on w.block_id=b.id
      join public.workout_sets s on s.item_id=w.id where b.template_id=t.id)
    order by t.id limit 1;
  if official is null then raise exception 'Falta una sesión oficial del catálogo.'; end if;
  perform public.start_workout_execution(official);
  reset role;
  insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
    values(athlete,'development_manual',now()-interval '1 day',now()+interval '1 day','Ensayo temporal')
    returning id into grant_id;
  set local role authenticated;
  pro_preview := public.get_scheduled_workout_preview(athlete,schedules[1]);
  if pro_preview->>'pro_required' <> 'false'
    or pro_preview->>'revision' <> preview->>'revision' then
    raise exception 'El permiso comercial cambia la revisión de la pauta.';
  end if;
  -- Retirada entre consultar e iniciar: el servidor vuelve a comprobar Pro.
  reset role;
  update public.pro_access_grants set revoked_at=now() where id=grant_id;
  set local role authenticated;
  begin
    perform public.start_reviewed_scheduled_workout(athlete,schedules[1],pro_preview->>'revision');
    raise exception 'Una consulta anterior conserva derechos retirados.';
  exception when raise_exception then
    get stacked diagnostics error_detail = pg_exception_detail;
    if error_detail is distinct from 'pro_required' then raise; end if;
  end;
  reset role;
  update public.pro_access_grants set revoked_at=null where id=grant_id;
  set local role authenticated;
  opened := public.start_reviewed_scheduled_workout(athlete,schedules[1],pro_preview->>'revision');
  if opened is null then raise exception 'Pro no puede empezar la pauta revisada.'; end if;
  -- Un Pro también puede comenzar desde el inicio directo por plantilla.
  other_opened := public.start_workout_execution(templates[2]);
  if other_opened is null then raise exception 'Pro no puede empezar su plantilla adaptativa.'; end if;
  reset role;
  update public.pro_access_grants set ends_at=now()-interval '1 second' where id=grant_id;
  set local role authenticated;
  if public.get_my_pro_access()->>'tier' <> 'free' then raise exception 'No se ha aplicado la caducidad.'; end if;
  if public.get_scheduled_workout_preview(athlete,schedules[1])->>'pro_required' <> 'false'
    or public.start_reviewed_scheduled_workout(athlete,schedules[1],preview->>'revision') <> opened
    or public.start_scheduled_workout(schedules[1]) <> opened
    or public.start_workout_execution(templates[1]) <> opened then
    raise exception 'Perder Pro impide continuar una sesión ya abierta.';
  end if;
  if public.start_workout_execution(templates[2]) <> other_opened then
    raise exception 'La sesión directa abierta no se puede continuar.';
  end if;
  begin
    perform public.start_scheduled_workout(schedules[3]);
    raise exception 'Free abre otra pauta al conservar una ejecución anterior.';
  exception when raise_exception then
    get stacked diagnostics error_detail = pg_exception_detail;
    if error_detail is distinct from 'pro_required' then raise; end if;
  end;
  -- Finalizar conserva el historial; una sesión descartada no se convierte en
  -- una puerta para empezar otra vez la misma plantilla sin Pro.
  for set_id in select id from public.workout_execution_sets where execution_id=opened loop
    perform public.skip_workout_set(set_id);
  end loop;
  perform public.finish_workout_execution(opened,5);
  if public.get_scheduled_workout_preview(athlete,schedules[1])->>'pro_required' <> 'false'
    or not exists(select 1 from public.workout_executions where id=opened and status='completed') then
    raise exception 'El cierre de una ejecución abierta no conserva su resultado.';
  end if;
  perform public.discard_workout_execution(other_opened,'DESCARTAR');
  begin
    perform public.start_workout_execution(templates[2]);
    raise exception 'Descartar permite reiniciar la plantilla sin Pro.';
  exception when raise_exception then
    get stacked diagnostics error_detail = pg_exception_detail;
    if error_detail is distinct from 'pro_required' then raise; end if;
  end;
  -- La privacidad se comprueba antes del derecho comercial.
  perform set_config('request.jwt.claim.sub',stranger::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',stranger,'role','authenticated','aal','aal1')::text,true);
  begin
    perform public.get_scheduled_workout_preview(stranger,schedules[1]);
    raise exception 'Otra cuenta consulta la pauta.';
  exception when insufficient_privilege then null; end;
  begin
    perform public.start_workout_execution(templates[3]);
    raise exception 'Otra cuenta comienza la plantilla.';
  exception when raise_exception then
    if sqlerrm <> 'Workout template is not accessible' then raise; end if;
  end;
  -- El servicio del preparador no exige otro Pro al alumno Free.
  perform set_config('request.jwt.claim.sub',trainer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
  coach_template := public.save_trainer_workout(gen_random_uuid(),payload);
  perform public.assign_trainer_workout(coach_schedule,relation,coach_template,current_date,null);
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',athlete,'role','authenticated','aal','aal1')::text,true);
  preview := public.get_scheduled_workout_preview(athlete,coach_schedule);
  if preview->>'pro_required' <> 'false'
    or public.start_reviewed_scheduled_workout(athlete,coach_schedule,preview->>'revision') is null then
    raise exception 'El alumno Free pierde la pauta de su preparador.';
  end if;
  if has_function_privilege('authenticated','trainer_private.start_workout_execution(uuid)','EXECUTE')
    or has_function_privilege('authenticated','public.require_pro_access()','EXECUTE')
    or has_table_privilege('authenticated','public.workout_executions','INSERT') then
    raise exception 'Una entrada interna permite saltar el inicio autorizado.';
  end if;
end
$$;
reset role;
select 'Consulta conservada, nuevos inicios Pro, continuidad, privacidad y servicio Free: OK' as result;
rollback;
