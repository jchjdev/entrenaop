begin;
set local statement_timeout='90s';
do $$
declare owner uuid:=gen_random_uuid();other uuid:=gen_random_uuid();admin uuid:=gen_random_uuid();work uuid:=gen_random_uuid();
 final_work uuid:=gen_random_uuid();reopened uuid:=gen_random_uuid();bad uuid:=gen_random_uuid();collision uuid:=gen_random_uuid();
 base uuid;foreign_base uuid;result_id uuid;exercise uuid;recipe jsonb;raw jsonb;intent jsonb;changed jsonb;origin jsonb;revision_origin jsonb;
 first_receipt jsonb;receipt jsonb;again jsonb;before_bytes bigint;before_count integer;candidate record;
begin
 insert into auth.users(id,email) values(owner,owner||'@session-work.invalid'),(other,other||'@session-work.invalid'),(admin,admin||'@session-work.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),owner,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now()),(gen_random_uuid(),admin,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(admin);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(owner,true,1,'Fixture sesiones'),(other,true,1,'Aislamiento sesiones');
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 if exercise is null then raise exception 'La prueba requiere un ejercicio público';end if;
 recipe:=jsonb_build_object('name','Sesión final','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 origin:='{"baseId":null,"programId":null,"parentWorkId":null,"phaseId":null,"positionId":null,"duplicate":false}';
 raw:=jsonb_build_object('schema',1,'context','{}'::jsonb,'editor',jsonb_build_object('schema',1,'running',false,
  'nameText',repeat('Nombre ',40),'descriptionText',repeat('texto pendiente privado ',200),'durationText','pendiente',
  'segments','[{"countText":"-","targetText":"pendiente","paceText":"","paceMaxText":"abc","recoveryTimeText":"?","byDistance":false,"recoveryByDistance":true,"recoveryType":null}]'::jsonb,
  'blocks',jsonb_build_array(jsonb_build_object('nameText','','format','straightSets','roundsText','-','restText','x','capText','',
   'exercises',jsonb_build_array(jsonb_build_object('exerciseId',exercise,'targetType','repetitions','automaticSlot',false,'customSets',true,
    'countText','','targetText','pendiente','restText','?','loadText','no sé','rirText','-','amrapRepetitionsText','','amrapRirText','',
    'variations','[{"setIndex":0,"targetText":"","restText":"-","loadText":"x","rirText":"?"}]'::jsonb))))));
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if public.get_trainer_session_work(owner,work) is not null or public.list_trainer_session_work(owner)<>'[]'::jsonb then raise exception 'Inventa un trabajo';end if;
 first_receipt:=public.save_trainer_session_work(owner,work,0,origin,raw);
 if first_receipt->'receipt'->'work'->'state'<>raw or first_receipt->>'current_revision'<>'1' then raise exception 'Pierde raw o revisión inicial';end if;
 if public.save_trainer_session_work(owner,work,0,origin,raw)<>first_receipt then raise exception 'Replay inicial distinto';end if;
 receipt:=public.list_trainer_session_work(owner);
 if receipt->0->'state'<>jsonb_build_object('editor',jsonb_build_object('nameText',left(raw->'editor'->>'nameText',160)))
  or receipt::text like '%texto pendiente privado%' or public.get_trainer_session_work(owner,work)->'state'<>raw then raise exception 'Listado expone cuerpo o get lo pierde';end if;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,origin,receipt->0->'state');raise exception 'Guarda resumen como snapshot';exception when invalid_parameter_value then null;end;
 perform public.save_trainer_session_work(owner,work,1,origin,raw);
 changed:=jsonb_set(raw,'{editor,nameText}','"Cambio posterior"');
 perform public.save_trainer_session_work(owner,work,2,origin,changed);
 again:=public.save_trainer_session_work(owner,work,0,origin,raw);
 if again->'receipt'<>first_receipt->'receipt' or again->>'current_revision'<>'3' then raise exception 'Recibo viejo sustituido por head';end if;
 begin perform public.save_trainer_session_work(owner,work,1,origin,changed);raise exception 'Replay cambia payload';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),-1,origin,raw);raise exception 'Revisión negativa';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),2147483647,origin,raw);raise exception 'Revisión excesiva';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,origin,jsonb_set(raw,'{context}','{"showInLibrary":true}'));raise exception 'Admite contexto ADMIN';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,origin,jsonb_set(raw,'{editor,token}','"secreto"'));raise exception 'Admite campos arbitrarios';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,jsonb_set(origin,'{parentWorkId}',to_jsonb(gen_random_uuid())),raw);raise exception 'Admite hijos sin contrato';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,jsonb_set(origin,'{baseId}','8'),raw);raise exception 'Admite base numérica';exception when invalid_parameter_value then null;end;
 begin perform public.finalize_trainer_session_work(owner,work,3);raise exception 'Finaliza sin intención';exception when invalid_parameter_value then null;end;

 -- raw conserva datos incompletos de ambas ramas. El motor valida intent, sin
 -- afirmar que SQL reproduce la proyección del formulario Flutter.
 intent:=raw||jsonb_build_object('intent',recipe);
 perform public.save_trainer_session_work(owner,reopened,0,origin,intent);
 begin perform public.save_trainer_session_work(owner,reopened,1,origin,raw);raise exception 'Borra intención por save';exception when serialization_failure then null;end;
 begin perform public.discard_trainer_session_work(owner,reopened,1);raise exception 'Descarta envío sin reconciliar';exception when serialization_failure then null;end;
 receipt:=public.reopen_trainer_session_work(owner,reopened,1);
 if receipt->'receipt'->'work'->'state'<>raw or receipt->>'current_revision'<>'2' then raise exception 'Reopen pierde raw';end if;
 if public.reopen_trainer_session_work(owner,reopened,1)<>receipt then raise exception 'Reopen duplicado';end if;
 begin perform public.finalize_trainer_session_work(owner,reopened,1);raise exception 'Envío antiguo actúa tras reopen';exception when serialization_failure then null;end;
 perform public.save_trainer_session_work(owner,reopened,2,origin,intent);
 again:=public.reopen_trainer_session_work(owner,reopened,1);
 if again->'receipt'<>receipt->'receipt' or again->>'current_revision'<>'3' or not(public.get_trainer_session_work(owner,reopened)->'state' ? 'intent') then raise exception 'Replay reopen cancela intención nueva';end if;

 perform public.save_trainer_session_work(owner,final_work,0,origin,intent);
 reset role;
 update trainer_private.session_work_limits set active_limit=active_count where owner_id=owner;
 set local role authenticated;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,origin,raw);raise exception 'Excede activos';exception when program_limit_exceeded then null;end;
 result_id:=public.finalize_trainer_session_work(owner,final_work,1);
 if result_id is null or public.get_trainer_session_work(owner,final_work)->>'lifecycle'<>'finalized' then raise exception 'Finalización no cierra';end if;
 if public.finalize_trainer_session_work(owner,final_work,1)<>result_id then raise exception 'Duplica finalización';end if;
 receipt:=public.reopen_trainer_session_work(owner,final_work,1);
 if receipt->'receipt'->'work'->>'result_id'<>result_id::text or receipt->'receipt'->'work'->>'lifecycle'<>'finalized' then raise exception 'Reabre resultado confirmado';end if;
 begin perform public.reopen_trainer_session_work(owner,final_work,0);raise exception 'Reopen obsoleto adopta otro recibo';exception when serialization_failure then null;end;
 reset role;
 if (select count(*) from trainer_private.workout_writes where trainer_id=owner and operation_id=final_work)<>1 then raise exception 'UUID de motor no es trabajo';end if;
 update trainer_private.session_work_limits set active_limit=100 where owner_id=owner;
 set local role authenticated;
 base:=public.save_trainer_workout(gen_random_uuid(),recipe);
 revision_origin:=jsonb_set(origin,'{baseId}',to_jsonb(base));
 perform public.save_trainer_session_work(owner,bad,0,revision_origin,raw||jsonb_build_object('intent','{"name":"inválida","blocks":[]}'::jsonb));
 reset role;
 select retained_bytes into before_bytes from trainer_private.session_work_limits where owner_id=owner;
 select count(*) into before_count from trainer_private.workout_writes where trainer_id=owner;
 set local role authenticated;
 begin
  perform public.finalize_trainer_session_work(owner,bad,1);
  raise exception 'Motor acepta receta inválida';
 exception when raise_exception then
  if sqlerrm<>'Workout must contain between 1 and 10 blocks' then raise;end if;
 end;
 receipt:=public.get_trainer_session_work(owner,bad);
 if receipt->>'lifecycle'<>'open' or receipt->>'revision'<>'1'
  or receipt->'state' is distinct from raw||jsonb_build_object('intent','{"name":"inválida","blocks":[]}'::jsonb) then
  raise exception 'El rechazo deportivo altera o pierde el trabajo y su intención';end if;
 reset role;
 if (select retained_bytes from trainer_private.session_work_limits where owner_id=owner)<>before_bytes
  or (select count(*) from trainer_private.workout_writes where trainer_id=owner)<>before_count
  or (select status from public.workout_templates where id=base)<>'published' then raise exception 'Fallo deja efectos';end if;
 set local role authenticated;
 perform public.reopen_trainer_session_work(owner,bad,1);
 perform public.save_trainer_session_work(owner,bad,2,revision_origin,intent);
 result_id:=public.finalize_trainer_session_work(owner,bad,3);
 reset role;
 if (select status from public.workout_templates where id=base)<>'archived' or (select previous_version_id from public.workout_templates where id=result_id)<>base then raise exception 'No usa motor de versiones';end if;
 set local role authenticated;
 perform public.save_trainer_session_work(owner,collision,0,origin,intent);
 perform public.save_trainer_workout(collision,recipe);
 begin perform public.finalize_trainer_session_work(owner,collision,1);raise exception 'Adopta recibo legacy exacto';exception when invalid_parameter_value then null;end;

 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 begin perform public.list_trainer_session_work(owner);raise exception 'Fence list';exception when insufficient_privilege then null;end;
 begin perform public.get_trainer_session_work(owner,work);raise exception 'Fence get';exception when insufficient_privilege then null;end;
 begin perform public.save_trainer_session_work(owner,work,0,origin,raw);raise exception 'Fence save';exception when insufficient_privilege then null;end;
 begin perform public.discard_trainer_session_work(owner,work,3);raise exception 'Fence discard';exception when insufficient_privilege then null;end;
 begin perform public.reopen_trainer_session_work(owner,work,3);raise exception 'Fence reopen';exception when insufficient_privilege then null;end;
 begin perform public.finalize_trainer_session_work(owner,final_work,1);raise exception 'Fence finalize';exception when insufficient_privilege then null;end;
 if public.get_trainer_session_work(other,work) is not null or public.list_trainer_session_work(other)<>'[]'::jsonb then raise exception 'Lee trabajo ajeno';end if;
 foreign_base:=public.save_trainer_workout(gen_random_uuid(),recipe);
 perform set_config('request.jwt.claim.sub',admin::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin,'role','authenticated','aal','aal2')::text,true);
 if public.get_trainer_session_work(admin,work) is not null then raise exception 'ADMIN lee trabajo ajeno';end if;
 begin perform public.save_trainer_session_work(admin,gen_random_uuid(),0,origin,raw);raise exception 'ADMIN concede autoría';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,jsonb_set(origin,'{baseId}',to_jsonb(foreign_base)),raw);raise exception 'Revisa base ajena';exception when insufficient_privilege then null;end;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=owner;
 set local role authenticated;
 if public.get_trainer_session_work(owner,bad)->>'result_id'<>result_id::text or public.finalize_trainer_session_work(owner,bad,3)<>result_id then raise exception 'Revocación pierde recibo final';end if;
 if jsonb_array_length(public.list_trainer_session_work(owner))=0 then raise exception 'Revocación borra índice';end if;
 begin perform public.save_trainer_session_work(owner,work,0,origin,raw);raise exception 'Revocado guarda replay';exception when insufficient_privilege then null;end;
 begin perform public.finalize_trainer_session_work(owner,reopened,3);raise exception 'Revocado finaliza nuevo';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_session_work(owner,bad);raise exception 'Lee sin MFA';exception when insufficient_privilege then null;end;
 begin perform public.finalize_trainer_session_work(owner,bad,3);raise exception 'Recibo sin MFA';exception when insufficient_privilege then null;end;
 reset role;
 update public.trainer_access set enabled=true where trainer_id=owner;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 select retained_bytes into before_bytes from trainer_private.session_work_limits where owner_id=owner;
 set local role authenticated;
 receipt:=public.discard_trainer_session_work(owner,work,3);
 if public.discard_trainer_session_work(owner,work,3)<>receipt then raise exception 'Replay descarte distinto';end if;
 begin perform public.save_trainer_session_work(owner,work,4,origin,raw);raise exception 'Reabre descartado';exception when serialization_failure then null;end;
 reset role;
 if (select retained_bytes from trainer_private.session_work_limits where owner_id=owner)<before_bytes then raise exception 'Descarte libera retención';end if;
 update trainer_private.session_work_limits set hourly_limit=0 where owner_id=owner;
 set local role authenticated;
 -- Un recibo exacto no consume otra acción aunque el límite nuevo sea cero.
 perform public.save_trainer_session_work(owner,work,0,origin,raw);
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,origin,raw);raise exception 'Excede tasa';exception when program_limit_exceeded then null;end;
 reset role;
 update trainer_private.session_work_limits set hourly_limit=1200,byte_limit=retained_bytes+1 where owner_id=owner;
 set local role authenticated;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,origin,changed);raise exception 'Excede bytes';exception when program_limit_exceeded then null;end;
 reset role;
 update trainer_private.session_work_limits set byte_limit=67108864,snapshot_limit=10 where owner_id=owner;
 set local role authenticated;
 begin perform public.save_trainer_session_work(owner,gen_random_uuid(),0,origin,raw);raise exception 'Excede snapshot configurado';exception when program_limit_exceeded then null;end;
 reset role;
 for candidate in select c.oid,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='trainer_private' and c.relname in ('session_work_limits','session_work_bodies','session_works','session_work_operations') loop
  if not candidate.relrowsecurity or has_table_privilege('authenticated',candidate.oid,'SELECT,INSERT,UPDATE,DELETE') or has_table_privilege('anon',candidate.oid,'SELECT,INSERT,UPDATE,DELETE') then raise exception 'Tabla privada expuesta';end if;
 end loop;
 if exists(select 1 from trainer_private.session_work_operations where owner_id=owner and action='save' and expected_revision=2147483647) then raise exception 'Persistió revisión excesiva';end if;
 raise notice 'OK sesiones profesionales: raw/CAS/ledger/intención/reopen/motor/identidad/MFA/revocación/cuotas/grants';
end $$;
rollback;
