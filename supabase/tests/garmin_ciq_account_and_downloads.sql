-- Contrato exclusivamente sintético. Nunca deja usuarios, concesiones o citas.
begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); other_owner uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); os uuid:=gen_random_uuid();
 template uuid; scheduled uuid:=gen_random_uuid(); ex uuid; payload jsonb; r jsonb; linked uuid; exported uuid; old_revision text;
 token text:=repeat('a',64); code text:=repeat('b',64); i integer;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@ciq.invalid'),(pupil,pupil||'@ciq.invalid'),(other_owner,other_owner||'@ciq.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(os,other_owner,'aal1');
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture CIQ con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 ex:=trainer_private.save_exercise(gen_random_uuid(),'{"name":"CIQ isométrico propio","description":"Fixture","muscle_groups":["core"],"equipment":[],"difficulty":"intermedio","exercise_type":"duración"}');
 payload:=jsonb_build_object('name','Sesión CIQ','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,
  'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object('exercise_id',ex,'sets',jsonb_build_array(
   jsonb_build_object('target_duration_seconds',7,'rest_after_seconds',60)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),payload);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);
 if has_table_privilege('authenticated','device_private.ciq_links','SELECT') or
    has_table_privilege('service_role','device_private.ciq_exports','SELECT') or
    has_function_privilege('anon','public.garmin_ciq_command(text,uuid,uuid,jsonb)','EXECUTE') or
    has_function_privilege('authenticated','public.garmin_ciq_command(text,uuid,uuid,jsonb)','EXECUTE') then
  raise exception 'Credenciales o fachada expuestas'; end if;
 r:=public.garmin_ciq_command('begin',null,null,jsonb_build_object('token_hash',token,'code_hash',code));linked:=(r->>'id')::uuid;
 begin perform public.garmin_ciq_command('approve',pupil,os,jsonb_build_object('id',linked,'code_hash',code));raise exception 'Acepta sesión ajena';
 exception when insufficient_privilege then null;end;
 r:=public.garmin_ciq_command('status',null,null,jsonb_build_object('token_hash',token));
 if r->>'status'<>'pending' then raise exception 'No exige consentimiento';end if;
 r:=public.garmin_ciq_command('review',pupil,ps,jsonb_build_object('code_hash',code));
 if r->>'id'<>linked::text then raise exception 'Previsualización incorrecta';end if;
 r:=public.garmin_ciq_command('approve',pupil,ps,jsonb_build_object('id',linked,'code_hash',code));
 if r->>'linked'<>'true' then raise exception 'No vincula';end if;
 r:=public.garmin_ciq_command('approve',pupil,ps,jsonb_build_object('id',linked,'code_hash',code));
 if r->>'error'<>'invalid_code' then raise exception 'Código reutilizable';end if;
 r:=public.garmin_ciq_command('manifest',null,null,jsonb_build_object('token_hash',token));
 if r->>'complete'<>'true' or jsonb_array_length(r->'entries')<>1 then raise exception 'Manifiesto incompleto';end if;
 exported:=(r->'entries'->0->>'id')::uuid;old_revision:=r->'entries'->0->>'revision';
 r:=public.garmin_ciq_command('manifest',null,null,jsonb_build_object('token_hash',token));
 if r->'entries'->0->>'id'<>exported::text then raise exception 'Duplica el reintento';end if;
 r:=public.garmin_ciq_command('download',null,null,jsonb_build_object('token_hash',token,'id',exported));
 if r->'snapshot'->'blocks'->0->'items'->0->>'exercise_name'<>'CIQ isométrico propio' then raise exception 'Pierde títulos';end if;
 begin perform public.garmin_ciq_command('revoke',other_owner,os,jsonb_build_object('id',linked));raise exception 'Revoca cuenta ajena';
 exception when insufficient_privilege then null;end;
 update public.scheduled_workouts set scheduled_date=current_date+1 where id=scheduled;
 begin perform public.garmin_ciq_command('download',null,null,jsonb_build_object('token_hash',token,'id',exported));raise exception 'Descarga revisión obsoleta';
 exception when serialization_failure then null;end;
 r:=public.garmin_ciq_command('manifest',null,null,jsonb_build_object('token_hash',token));
 if r->'entries'->0->>'revision'=old_revision then raise exception 'Oculta la nueva revisión';end if;
 exported:=(r->'entries'->0->>'id')::uuid;
 update public.scheduled_workouts set status='cancelled' where id=scheduled;
 begin perform public.garmin_ciq_command('download',null,null,jsonb_build_object('token_hash',token,'id',exported));raise exception 'Descarga cita retirada';
 exception when insufficient_privilege then null;end;
 r:=public.garmin_ciq_command('manifest',null,null,jsonb_build_object('token_hash',token));
 if jsonb_array_length(r->'entries')<>0 then raise exception 'Sigue mostrando la cita retirada';end if;
 for i in 1..4 loop
  insert into device_private.ciq_links(token_hash,owner_id,valid_until)
   values(encode(sha256(convert_to(gen_random_uuid()::text,'UTF8')),'hex'),pupil,clock_timestamp()+interval '90 days');
 end loop;
 r:=public.garmin_ciq_command('begin',null,null,jsonb_build_object('token_hash',repeat('e',64),'code_hash',repeat('f',64)));
 r:=public.garmin_ciq_command('approve',pupil,ps,jsonb_build_object('id',r->>'id','code_hash',repeat('f',64)));
 if r->>'error'<>'device_limit' then raise exception 'Supera cinco dispositivos';end if;
 update public.trainer_client_relations set ended_at=clock_timestamp() where id=relation;
 r:=public.garmin_ciq_command('account',pupil,ps,'{}');
 if r->>'allowed'<>'false' then raise exception 'Conserva derechos comerciales sin Pro ni entrenador';end if;
 begin perform public.garmin_ciq_command('manifest',null,null,jsonb_build_object('token_hash',token));raise exception 'Acceso comercial perdido';
 exception when insufficient_privilege then null;end;
 begin perform public.garmin_ciq_command('download',null,null,jsonb_build_object('token_hash',token,'id',exported));raise exception 'Descarga sin derechos comerciales';
 exception when insufficient_privilege then
  if sqlerrm<>'access_required' then raise exception 'No comprueba derechos antes de descargar: %',sqlerrm;end if;
 end;
 -- Un enlace consumido también caduca aunque no se haya revocado manualmente.
 update device_private.ciq_links set created_at=clock_timestamp()-interval '91 days',valid_until=clock_timestamp()-interval '1 day'
  where owner_id=pupil and id<>linked;
 begin perform public.garmin_ciq_command('status',null,null,jsonb_build_object('token_hash',
  (select token_hash from device_private.ciq_links where owner_id=pupil and id<>linked limit 1)));
  raise exception 'Credencial caducada funciona';exception when insufficient_privilege then null;end;
 -- Perder el servicio no impide retirar el permiso del reloj.
 perform public.garmin_ciq_command('revoke',pupil,ps,jsonb_build_object('id',linked));
 begin perform public.garmin_ciq_command('download',null,null,jsonb_build_object('token_hash',token,'id',exported));raise exception 'Credencial revocada funciona';
 exception when insufficient_privilege then null;end;
 r:=public.garmin_ciq_command('begin',null,null,jsonb_build_object('token_hash',repeat('c',64),'code_hash',repeat('d',64)));
 update device_private.ciq_links set pair_until=clock_timestamp()-interval '1 second' where id=(r->>'id')::uuid;
 begin perform public.garmin_ciq_command('status',null,null,jsonb_build_object('token_hash',repeat('c',64)));raise exception 'Intento caducado funciona';
 exception when insufficient_privilege then null;end;
end $$;
set constraints all immediate;
select 'CIQ account and downloads contract passed' as result;
rollback;
