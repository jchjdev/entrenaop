begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); ts uuid:=gen_random_uuid(); weak uuid:=gen_random_uuid();
 template uuid; scheduled uuid:=gen_random_uuid(); second uuid:=gen_random_uuid(); recipe jsonb;
 preview jsonb; claim jsonb; receipt jsonb; lease uuid:=gen_random_uuid(); jid uuid; code text;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@garmin-training.invalid'),(pupil,pupil||'@garmin-training.invalid'),(stranger,stranger||'@garmin-training.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2'),(weak,trainer,'aal1');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture Garmin con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 recipe:=jsonb_build_object('name','Carrera sintética Garmin','blocks',jsonb_build_array(jsonb_build_object(
  'name','Carrera','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
   'exercise_id','20000000-0000-4000-8000-000000000004','sets',jsonb_build_array(jsonb_build_object(
    'target_duration_seconds',120,'rest_after_seconds',0,'target_pace_min_seconds_per_km',300,'target_pace_max_seconds_per_km',360,
    'recovery_type','walking','recovery_duration_seconds',30)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date+1,null);
 perform trainer_private.assign_trainer_workout(second,relation,template,current_date+2,null);

 perform set_config('fixture.owner',pupil::text,true);perform set_config('fixture.session',ps::text,true);
 perform set_config('fixture.scheduled',scheduled::text,true);
end $$;
set local role authenticated;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid;sid uuid:=current_setting('fixture.scheduled')::uuid;
 sess uuid:=current_setting('fixture.session')::uuid;p jsonb;claim jsonb;removal jsonb;stable_id uuid;begin
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',sess,'aal','aal1')::text,true);
 if has_table_privilege('authenticated','device_private.apple_training_deliveries','SELECT') then raise exception 'Tabla privada expuesta';end if;
 if not (public.apple_training_command(owner,'list')->>'allowed')::boolean then raise exception 'Alumno activo excluido';end if;
 begin perform public.apple_training_command(gen_random_uuid(),'list');raise exception 'Cuenta ajena admitida';exception when insufficient_privilege then null;end;
 p:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));
 begin perform public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision','old','attempt_id',gen_random_uuid()));raise exception 'Acepta receta obsoleta';exception when serialization_failure then null;end;
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));stable_id:=(claim->>'plan_id')::uuid;
 begin perform public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));raise exception 'Dos escritores activos';exception when lock_not_available then null;end;
 begin perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',gen_random_uuid()));raise exception 'ACK ajeno admitido';exception when serialization_failure then null;end;
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 if public.apple_training_command(owner,'list')->'deliveries'->0->>'status'<>'submitted' then raise exception 'ACK no conservado';end if;
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));
 if (claim->>'plan_id')::uuid<>stable_id then raise exception 'Repetición duplica identidad';end if;
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',gen_random_uuid(),'aal','aal1')::text,true);
 begin perform public.apple_training_command(owner,'list');raise exception 'Sesión revocada admitida';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid;sid uuid:=current_setting('fixture.scheduled')::uuid;begin
 -- Simula una retirada concurrente y la finalización del servicio sin borrar datos.
 update public.scheduled_workouts set status='cancelled' where id=sid;
 update public.trainer_access set enabled=false where trainer_id in (select trainer_id from public.trainer_client_relations where client_id=owner);
 if trainer_private.assignment_delete_block(sid)<>'references' then raise exception 'Referencia Apple no protegida';end if;
 begin delete from public.scheduled_workouts where id=sid;raise exception 'Borrado deja plan huérfano';exception when foreign_key_violation then null;end;
end $$;
set local role authenticated;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid;sid uuid:=current_setting('fixture.scheduled')::uuid;removal jsonb;begin
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',current_setting('fixture.session'),'aal','aal1')::text,true);
 if (public.apple_training_command(owner,'list')->>'allowed')::boolean then raise exception 'Derecho vencido sigue enviando';end if;
 begin perform public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));raise exception 'Envío sin derechos';exception when insufficient_privilege then null;end;
 removal:=public.apple_training_command(owner,'removal',jsonb_build_object('scheduled_id',sid));
 perform public.apple_training_command(owner,'removed',jsonb_build_object('scheduled_id',sid,'revision',removal->>'revision','attempt_id',removal->>'attempt_id'));
 if public.apple_training_command(owner,'list')->'deliveries'->0->>'status'<>'removed' then raise exception 'No retira al vencer acceso';end if;
end $$;
select 'Apple: ámbito, cuenta, sesión, receta, exclusión, ACK, duplicados, retirada y protección de borrado verificados' as result;
rollback;
