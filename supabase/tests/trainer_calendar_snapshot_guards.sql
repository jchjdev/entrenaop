begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid(); deleted_user uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); template uuid; personal uuid; scheduled uuid; exercise uuid; recipe jsonb; recipients jsonb; plan jsonb; receipt jsonb;
 monday date:=current_date-(extract(isodow from current_date)::integer-1)+14; before_revision bigint; initial_revision bigint;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@calendar-guards.invalid'),(pupil,pupil||'@calendar-guards.invalid'),
  (stranger,stranger||'@calendar-guards.invalid'),(deleted_user,deleted_user||'@calendar-guards.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture revisión de agenda');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 -- Vincular ya incrementa la revisión del alumno: invalida vistas compartidas
 -- también cuando aún no hay sesiones. El resto de perfiles sigue sin contador.
 select revision into initial_revision from trainer_private.calendar_revisions where user_id=pupil;
 if initial_revision is distinct from 1::bigint or exists(select 1 from trainer_private.calendar_revisions where user_id in(trainer,stranger,deleted_user)) then raise exception 'Revisión inicial del vínculo incorrecta';end if;
 if has_table_privilege('authenticated','trainer_private.calendar_revisions','SELECT')
  or has_table_privilege('authenticated','trainer_private.calendar_revisions','INSERT')
  or has_function_privilege('authenticated','trainer_private.lock_calendar_revisions(uuid[])','EXECUTE')
  or has_function_privilege('anon','trainer_private.bump_calendar_revision()','EXECUTE')
  or has_function_privilege('authenticated','public.deliver_trainer_batch(uuid,jsonb,uuid,date,uuid,jsonb,text,uuid,bigint)','EXECUTE')
  or has_function_privilege('authenticated','trainer_private.deliver_batch(uuid,jsonb,uuid,date,uuid,jsonb,text,uuid,bigint)','EXECUTE') then raise exception 'Revisión o envío sin huella expuesto al cliente'; end if;
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 recipe:=jsonb_build_object('name','Receta de agenda','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 recipients:=jsonb_build_array(jsonb_build_object('client_id',pupil,'relation_id',relation));
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 template:=public.save_trainer_workout(gen_random_uuid(),recipe);
 begin perform public.deliver_trainer_batch(gen_random_uuid(),recipients,p_template_id=>template,p_date=>monday);raise exception 'Bypass legacy público';exception when insufficient_privilege then null;end;
 begin perform trainer_private.deliver_batch(gen_random_uuid(),recipients,template,monday,null,null,null,null,null);raise exception 'Bypass legacy interno';exception when insufficient_privilege then null;end;
 plan:=public.preview_trainer_recurrence(recipients,template,monday,1,array[1,3]);
 begin perform trainer_private.lock_calendar_revisions(array[stranger]);raise exception 'Llamada directa al contador';exception when insufficient_privilege then null;end;
 -- Perfil existente o UUID inexistente: se rechazan por vínculo antes de tocar
 -- un contador o FK. La señal externa es la misma en ambos casos.
 begin perform public.create_trainer_recurrence(gen_random_uuid(),jsonb_build_array(jsonb_build_object('client_id',stranger,'relation_id',relation)),template,monday,1,array[1,3],null,plan->>'fingerprint');raise exception 'Admite perfil ajeno';exception when insufficient_privilege then null;end;
 begin perform public.create_trainer_recurrence(gen_random_uuid(),jsonb_build_array(jsonb_build_object('client_id',gen_random_uuid(),'relation_id',relation)),template,monday,1,array[1,3],null,plan->>'fingerprint');raise exception 'Sonda de FK ajena';exception when insufficient_privilege then null;end;
 reset role;
 if (select revision from trainer_private.calendar_revisions where user_id=pupil) is distinct from initial_revision
  or exists(select 1 from trainer_private.calendar_revisions where user_id=stranger) then raise exception 'Preview o rechazo escribe contador'; end if;
 set local role authenticated;
 receipt:=public.create_trainer_recurrence(gen_random_uuid(),recipients,template,monday,1,array[1,3],null,plan->>'fingerprint');
 reset role;
 if (select revision from trainer_private.calendar_revisions where user_id=pupil)<>initial_revision+2 then raise exception 'Agenda nueva no registra las dos altas'; end if;
 -- Un cambio sin contador anterior también invalida copia/serie en RR: lo
 -- acredita el runner de dos conexiones; aquí contrastamos el trigger real.
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 personal:=public.create_personal_workout_template(jsonb_set(recipe,'{name}','"Personal de alumno"'));
 scheduled:=public.schedule_workout(personal,monday+2);
 reset role;
 select revision into before_revision from trainer_private.calendar_revisions where user_id=pupil;
 set local role authenticated;
 perform public.reschedule_workout(scheduled,monday+4);
 reset role;
 if (select revision from trainer_private.calendar_revisions where user_id=pupil)<>before_revision+1 then raise exception 'UPDATE personal no incrementa revisión'; end if;
 delete from public.scheduled_workouts where id=scheduled;
 if (select revision from trainer_private.calendar_revisions where user_id=pupil)<>before_revision+2 then raise exception 'DELETE no incrementa revisión'; end if;

 -- Fixture de un perfil sin vínculo para verificar el cascade real. La receta
 -- puede ser pública o ajena: el INSERT como postgres no representa una API.
 insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,scheduled_date,source)
  values(deleted_user,template,'Fixture cascade',1,monday,'user');
 if not exists(select 1 from trainer_private.calendar_revisions where user_id=deleted_user) then raise exception 'INSERT no crea contador'; end if;
 delete from auth.users where id=deleted_user;
 if exists(select 1 from trainer_private.calendar_revisions where user_id=deleted_user)
  or exists(select 1 from public.scheduled_workouts where user_id=deleted_user) then raise exception 'Cascade reconstruye revisión o conserva agenda'; end if;
 if exists(select 1 from trainer_private.calendar_revisions where user_id=stranger) then raise exception 'Se creó revisión de perfil ajeno'; end if;
end $$;
select 'trainer_calendar_snapshot_guards: OK' as result;
rollback;
