-- Pautas de preparación publicadas y observaciones sintéticas de los relojes.
begin;
set local timezone='Europe/Madrid';
set local statement_timeout='55s';

do $$
declare
 provider text; athlete uuid; login_session uuid; goal uuid; reference uuid; scheduled uuid;
 wk date:=current_date-extract(isodow from current_date)::int+1;
 started timestamptz:=greatest(date_trunc('day',now()),now()-interval '3 minutes');
 zone_minutes int:=extract(timezone from started)::int/60;
 preview jsonb; delivery jsonb; observation jsonb; input jsonb; receipt jsonb;
 lease uuid; job uuid; execution uuid; external_id text;
begin
 foreach provider in array array['apple','garmin'] loop
  athlete:=gen_random_uuid(); login_session:=gen_random_uuid();
  insert into auth.users(id,email) values(athlete,athlete||'@adaptive-device.invalid');
  insert into auth.sessions(id,user_id,aal) values(login_session,athlete,'aal1');
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',athlete,'role','authenticated',
    'session_id',login_session,'aal','aal1')::text,true);
  update public.profiles set fecha_nacimiento='1996-01-01' where id=athlete;
  insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
  values(athlete,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture preparación y reloj');
  insert into public.preparation_goals(user_id,program_id,target_date)
  values(athlete,'fas_periodic_assessment',wk+100) returning id into goal;
  insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,
    age_band,is_pre_effective_reference,completed_at)
  values(athlete,goal,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '5 days') returning id into reference;
  insert into public.fas_periodic_marks values(reference,'run_2000_m',550000);
  perform public.materialize_running_week_plan(goal,wk,jsonb_build_object('policy_version','running_2k_v6',
   'basis','recent','mode','normal','outcome','maintain','normal_budget',30,'anchor_seconds',550,
   'week_start',wk,'load_weeks',0,'rotation',1,'reference_source','fasPeriodicAssessment','reference_record_id',reference,
   'sessions',jsonb_build_array(public.running_session_v2('E',0,550,30)||jsonb_build_object('date',current_date))));
  select id into strict scheduled from public.scheduled_workouts where user_id=athlete and preparation_goal_id=goal;

  if provider='apple' then
   preview:=public.apple_training_command(athlete,'preview',jsonb_build_object('scheduled_id',scheduled));
   delivery:=public.apple_training_command(athlete,'prepare',jsonb_build_object('scheduled_id',scheduled,
    'revision',preview->>'revision','attempt_id',gen_random_uuid()));
   perform public.apple_training_command(athlete,'record',jsonb_build_object('scheduled_id',scheduled,
    'revision',delivery->>'revision','attempt_id',delivery->>'attempt_id'));
   perform public.apple_results_command(athlete,'enable','{"enabled":true}');
   observation:=jsonb_build_object('workout_id',gen_random_uuid(),'plan_id',delivery->>'plan_id','revision',delivery->>'revision',
    'matches_prescription',true,'started_at',started,'ended_at',started+interval '120 seconds','timer_seconds',120,
    'distance_meters',300,'average_heart_rate',140,'max_heart_rate',156,'offset_minutes',zone_minutes,
    'intervals',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'started_at',started,
     'ended_at',started+interval '120 seconds','timer_seconds',120,'distance_meters',300)));
   input:=jsonb_build_object('observations',jsonb_build_array(observation));
   perform public.apple_results_command(athlete,'ingest',input);
   perform public.apple_results_command(athlete,'ingest',input);
  else
   lease:=gen_random_uuid(); job:=gen_random_uuid(); external_id:='9100550';
   perform public.garmin_account_command('begin',athlete,login_session,jsonb_build_object('state_hash',repeat('d',64),'verifier_cipher','fixture'));
   perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('d',64),'claim_id',lease));
   perform public.garmin_account_command('complete',athlete,null,jsonb_build_object('generation',1,'claim_id',lease,
    'tokens_cipher','fixture-encrypted','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day',
    'garmin_user_id',athlete::text,'can_read',true,'can_send',true));
   delivery:=device_private.garmin_training_command('preview',athlete,athlete,login_session,jsonb_build_object('scheduled_id',scheduled));
   -- Simula únicamente la entrega confirmada por la API externa y su FIT ya decodificado.
   insert into device_private.training_deliveries(owner_id,scheduled_id,provider,adapter_version,connection_generation,revision,snapshot,status,workout_id,schedule_id)
   values(athlete,scheduled,'garmin',1,1,delivery->>'revision',delivery->'snapshot','sent',123,456);
   perform public.garmin_activity_command('enqueue',null,null,jsonb_build_object('id',job,'event_key',repeat('e',64),
    'provider_user_id',athlete::text,'callback_cipher','fixture-callback','metadata',jsonb_build_object('activityId',external_id,'activityName','Fixture')));
   perform public.garmin_activity_command('claim',null,null,jsonb_build_object('id',job,'lease_id',lease));
   observation:=jsonb_build_object('schemaVersion',1,'externalId',external_id,'name','Fixture',
    'startedAt',started,'offsetSeconds',zone_minutes*60,'elapsedSeconds',120,'timerSeconds',120,'distanceMeters',300,
    'averageHeartRate',140,'maxHeartRate',156,'prescriptionReference','fixture-preparacion',
    'laps',jsonb_build_array(jsonb_build_object('index',0,'timerSeconds',120,'elapsedSeconds',120,'distanceMeters',300)));
   receipt:=public.garmin_activity_command('save',null,null,jsonb_build_object('id',job,'lease_id',lease,'activity',observation));
   perform set_config('request.jwt.claim.sub','',true);
   perform set_config('request.jwt.claims','{"role":"service_role"}',true);
   input:=receipt||jsonb_build_object('id',job,'lease_id',lease,'scheduled_id',scheduled,'delivery_revision',delivery->>'revision',
    'mapping',jsonb_build_array(jsonb_build_object('block_order',0,'item_order',0,'set_order',0,'skipped',false,
     'lap_indices','[0]'::jsonb,'recovery_lap_indices','[]'::jsonb)));
   receipt:=public.garmin_activity_command('automatic.complete',athlete,null,input);
   if receipt->>'completed' is distinct from 'true' or
    public.garmin_activity_command('automatic.complete',athlete,null,input)->>'execution_id' is distinct from receipt->>'execution_id' then
    raise exception 'Garmin no completa de forma idempotente: %',receipt;
   end if;
  end if;

  select execution_id into execution from public.scheduled_workouts where id=scheduled and source='algorithm' and status='completed';
  if execution is null or (select count(*) from public.workout_executions where user_id=athlete)<>1 or not exists(
   select 1 from public.workout_executions e join public.workout_execution_sets s on s.execution_id=e.id
   where e.id=execution and e.result_source='device' and e.average_heart_rate_bpm=140 and e.max_heart_rate_bpm=156
    and e.final_rpe is null and s.actual_duration_seconds=120 and s.actual_distance_meters=300) then
   raise exception '% no completa una sola ejecución de preparación con las mediciones y sin inventar esfuerzo',provider;
  end if;
 end loop;
end $$;

select 'Garmin y Apple cierran una sola ejecución de preparación con los datos observados de la fixture' as result;
rollback;
