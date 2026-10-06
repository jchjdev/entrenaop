begin;
do $$
declare ref jsonb; dose jsonb; hist jsonb; p jsonb; profile jsonb; task jsonb; wk date:='2026-10-05';
begin
  select definition into profile from public.exercise_training_profiles where code='push_up_standard' and definition_version=1;
  task:='{"schema_version":1,"exercise_code":"push_up_standard","exercise_version":1,
    "protocol_key":"push_test_v1","protocol_version":1,"setup_key":"floor",
    "measurement":"REPS","load_mode":"bodyweight","policy_version":"performance_v1",
    "target_value":8,"target_rir":3,"intent":"work"}';
  ref:=jsonb_build_object('id','fixture','task',task,'targets','[8,8]'::jsonb,'observed_on',wk-7,
    'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2,'role','specific');
  p:=public.performance_task_v1(ref,profile,'[]',wk,wk+90);
  if p->>'status'<>'ready' or p->>'outcome'<>'initial' then raise exception 'Entrada: %',p; end if;
  dose:=p->'dose';
  select jsonb_agg(jsonb_build_object('completed_on',wk-d,'execution_id',d,'dose',dose,'status','completed',
    'sets',jsonb_build_array(
      jsonb_build_object('status','completed','prescription',task,'result','{"value":8,"rir":3,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}'::jsonb),
      jsonb_build_object('status','completed','prescription',task,'result','{"value":8,"rir":3,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}'::jsonb))))
    into hist from unnest(array[2,5]) d;
  p:=public.performance_task_v1(ref,profile,hist,wk,wk+90,p);
  if p->>'outcome'<>'progress' or p->'dose'->'targets'<>'[9,8]'::jsonb then raise exception 'Progresión: %',p; end if;
  -- No reutilizar dos éxitos antiguos después de cambiar la dosis.
  p:=public.performance_task_v1(ref,profile,hist,wk+7,wk+90,p);
  if p->>'outcome'='progress' then raise exception 'Reutiliza respuesta a otra dosis'; end if;
  hist:=jsonb_set(hist,'{0,sets,0,result,rir}','null');
  p:=public.performance_task_v1(ref,profile,hist,wk,wk+90);
  if p->>'outcome'='progress' then raise exception 'Progresa con esfuerzo desconocido'; end if;
  p:=public.performance_task_v1(ref,profile,'[]',wk,wk+5);
  if p->>'phase'<>'taper' or jsonb_array_length(p->'dose'->'targets')<>1 then raise exception 'Puesta a punto: %',p; end if;
  p:=public.performance_task_v1(ref,profile,'[]',wk+28,wk+90);
  if p->>'status'<>'needs_calibration' then raise exception 'No detecta interrupción'; end if;
  if public.valid_performance_result('{"value":1}',task||'{"measurement":"PASS_FAIL"}') then raise exception 'Resultado booleano convertido en marca'; end if;
  if not public.valid_performance_result('{"succeeded":true}',task||'{"measurement":"PASS_FAIL"}') then raise exception 'No admite éxito explícito'; end if;
  if public.valid_performance_result('{"value":0.18}',task||'{"measurement":"REACTIVE_METRICS"}') then raise exception 'Contacto sin instrumento'; end if;
  if not public.valid_performance_result('{"value":0.18,"jump_height_meters":0.3,"measurement_method":"Plataforma de contacto"}',task||'{"measurement":"REACTIVE_METRICS"}') then raise exception 'Métrica reactiva válida rechazada'; end if;
end $$;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
do $$
declare g uuid; r uuid; obj jsonb;
begin
  select id into g from public.preparation_goals where user_id=auth.uid() and status='active' limit 1;
  if g is null then
    insert into public.preparation_goals(user_id,program_id,target_date)
      select auth.uid(),id,current_date+90 from public.preparation_programs where enabled limit 1 returning id into g;
  end if;
  perform public.save_performance_context('{"1":60,"4":60}','{}',false,true);
  obj:=jsonb_build_object('goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS',
    'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo, técnica completa","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb,
    'targets','[8,8]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,
    'reported_rir',3,'rest_seconds',120,'frequency',2);
  r:=public.save_performance_reference(g,obj);
  if not exists(select 1 from public.performance_training_references where id=r and active) then raise exception 'No persiste referencia'; end if;
  perform public.save_performance_reference(g,obj);
  if exists(select 1 from public.performance_training_references where id=r and active) then raise exception 'No conserva revisión anterior'; end if;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin perform public.save_performance_reference(g,obj); raise exception 'Referencia ajena aceptada';
    exception when insufficient_privilege then null; end;
end $$;
select 'Política, comparabilidad, puesta a punto, retorno, referencias y permisos: OK' as result;
rollback;
