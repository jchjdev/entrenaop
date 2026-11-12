begin;
set local statement_timeout='45s';

do $test$
declare
  coach uuid:=gen_random_uuid();
  other uuid:=gen_random_uuid();
  pupil uuid;
  pupils uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
  relation uuid;
  operation uuid:=gen_random_uuid();
  exercise uuid;
  old_recipe uuid;
  new_recipe uuid;
  old_program uuid;
  new_program uuid;
  to_start uuid;
  execution uuid;
  to_adapt uuid;
  adapted_recipe uuid;
  to_move uuid;
  payload jsonb;
  content jsonb;
  preview jsonb;
  selection jsonb;
  result jsonb;
  fingerprint text;
begin
  insert into auth.users(id,email)
    select id,id||'@program-update.invalid' from unnest(pupils||array[coach,other]) u(id);
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
    select gen_random_uuid(),id,'totp','verified',now(),now() from unnest(array[coach,other]) u(id);
  insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
    values(coach,true,3,'Fixture actualización'),(other,true,1,'Fixture aislamiento');
  insert into public.trainer_client_relations(trainer_id,client_id,accepted_at)
    select coach,id,now() from unnest(pupils) u(id);
  select id into strict exercise from public.exercises where is_public order by id limit 1;
  payload:=jsonb_build_object('name','Fuerza A','blocks',jsonb_build_array(jsonb_build_object(
    'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,
      'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',90)))))));

  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  old_recipe:=public.save_trainer_workout(gen_random_uuid(),payload);
  content:=jsonb_build_object('name','Programa de grupo','mode','guide','phases',
    jsonb_build_array(jsonb_build_object('name','Base','sessions',
      jsonb_build_array(jsonb_build_object('template_id',old_recipe,'name','Fuerza A')))));
  old_program:=public.save_trainer_program(gen_random_uuid(),content);
  foreach pupil in array pupils loop
    select id into strict relation from public.trainer_client_relations where client_id=pupil and trainer_id=coach;
    perform public.assign_trainer_program(gen_random_uuid(),relation,old_program,
      jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',current_date),
        jsonb_build_object('phase',0,'session',0,'date',current_date+2)), 'Nota conservada');
  end loop;

  select (item->>'id')::uuid into strict to_start from jsonb_array_elements(public.list_trainer_agenda(current_date,current_date)) item
    where item->>'client_id'=pupils[1]::text;
  select (item->>'id')::uuid into strict to_adapt from jsonb_array_elements(public.list_trainer_agenda(current_date,current_date)) item
    where item->>'client_id'=pupils[2]::text;
  select (item->>'id')::uuid into strict to_move from jsonb_array_elements(public.list_trainer_agenda(current_date,current_date)) item
    where item->>'client_id'=pupils[3]::text;
  fingerprint:=public.preview_trainer_assignment_change(to_adapt,0,current_date,'Adaptada',payload)->>'fingerprint';
  adapted_recipe:=(public.change_trainer_assignment_reviewed(gen_random_uuid(),to_adapt,0,current_date,
    'Adaptada',fingerprint,payload)->>'template_id')::uuid;
  fingerprint:=public.preview_trainer_assignment_change(to_move,0,current_date+1,'Nota conservada')->>'fingerprint';
  perform public.change_trainer_assignment_reviewed(gen_random_uuid(),to_move,0,current_date+1,'Nota conservada',fingerprint);

  new_recipe:=public.save_trainer_workout(gen_random_uuid(),
    jsonb_set(payload,'{blocks,0,exercises,0,sets,0,target_reps}','10'),old_recipe);
  new_program:=public.save_trainer_program(gen_random_uuid(),
    jsonb_set(content,'{phases,0,sessions,0,template_id}',to_jsonb(new_recipe)),old_program);
  preview:=public.preview_trainer_program_updates(new_program);
  if jsonb_array_length(preview)<>6 or not exists (
    select 1 from jsonb_array_elements(preview) x where x->>'id'=to_adapt::text and x->>'reason'='adapted'
  ) then raise exception 'Vista previa incompleta o adaptación desprotegida: %',preview; end if;
  select jsonb_agg(jsonb_build_object('id',x->'id','revision',x->'revision','template_id',x->'template_id') order by x->>'id')
    into selection from jsonb_array_elements(preview) x where x->>'reason'='eligible';
  if jsonb_array_length(selection)<>5 then raise exception 'Selección incorrecta'; end if;

  perform set_config('request.jwt.claim.sub',other::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
  begin perform public.preview_trainer_program_updates(new_program);
    raise exception 'Un preparador ajeno ve las pautas'; exception when insufficient_privilege then null; end;
  begin perform public.apply_trainer_program_updates(operation,new_program,selection);
    raise exception 'Un preparador ajeno actualiza las pautas'; exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub',pupils[1]::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupils[1],'role','authenticated','aal','aal1')::text,true);
  execution:=public.start_scheduled_workout(to_start);
  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
  result:=public.apply_trainer_program_updates(operation,new_program,selection);
  if result<>jsonb_build_object('updated',4,'skipped',1)
    or public.apply_trainer_program_updates(operation,new_program,selection)<>result then
    raise exception 'El lote o el reintento no respetan la ejecución: %',result;
  end if;
  reset role;
  if not exists(select 1 from public.scheduled_workouts where id=to_start and template_id=old_recipe and execution_id is not null)
    or not exists(select 1 from public.scheduled_workouts where id=to_adapt and template_id=adapted_recipe)
    or not exists(select 1 from public.scheduled_workouts s join public.trainer_assignments a on a.scheduled_id=s.id
      join trainer_private.program_deliveries d on d.id=a.program_delivery_id
      where s.id=to_move and s.template_id=new_recipe and s.scheduled_date=current_date+1
        and a.note='Nota conservada' and a.program_phase_index=0 and d.program_id=old_program)
    or (select count(*) from public.scheduled_workouts where template_id=new_recipe)<>4 then
    raise exception 'Cambian citas protegidas o se pierde la cita original';
  end if;

  perform set_config('request.jwt.claim.sub',pupils[1]::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupils[1],'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  perform public.discard_workout_execution(execution,'DESCARTAR');
  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
  preview:=public.preview_trainer_program_updates(new_program);
  select jsonb_agg(jsonb_build_object('id',x->'id','revision',x->'revision','template_id',x->'template_id'))
    into selection from jsonb_array_elements(preview) x where x->>'id'=to_start::text and x->>'reason'='eligible';
  if selection is null or public.apply_trainer_program_updates(gen_random_uuid(),new_program,selection)
    <>jsonb_build_object('updated',1,'skipped',0) then
    raise exception 'Una cita pendiente vuelve del descarte pero el lote la bloquea: %',preview;
  end if;
  new_program:=public.save_trainer_program(gen_random_uuid(),
    jsonb_set(content,'{phases,0,sessions}',jsonb_build_array(
      jsonb_build_object('template_id',new_recipe,'name','Fuerza A'),
      jsonb_build_object('template_id',old_recipe,'name','Fuerza B'))),new_program);
  preview:=public.preview_trainer_program_updates(new_program);
  if (select count(*) from jsonb_array_elements(preview) x where x->>'reason'='uncertain')<>5 then
    raise exception 'La vista previa acepta una correspondencia ambigua: %',preview;
  end if;
  reset role;
  if not exists(select 1 from public.scheduled_workouts s join public.trainer_assignments a on a.scheduled_id=s.id
    where s.id=to_start and s.template_id=new_recipe and s.status='planned' and s.execution_id is null
      and a.result_revision>0) then raise exception 'Se pierde el estado o la revisión tras el descarte'; end if;
end $test$;

select 'trainer_update_program_assignments: OK' as result;
rollback;
