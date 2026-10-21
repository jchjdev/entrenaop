begin;
set local statement_timeout='90s';
do $$
declare owner uuid:=gen_random_uuid();other uuid:=gen_random_uuid();admin uuid:=gen_random_uuid();work_id uuid:=gen_random_uuid();
 work_a uuid:=gen_random_uuid();work_b uuid:=gen_random_uuid();bad_work uuid:=gen_random_uuid();pending_work uuid:=gen_random_uuid();collision uuid:=gen_random_uuid();collision2 uuid:=gen_random_uuid();
 exercise uuid;template uuid;foreign_template uuid;base uuid;unchanged_base uuid;finalized uuid;legacy uuid;
 raw jsonb;changed jsonb;valid jsonb;pending jsonb;content jsonb;phase_content jsonb;recipe jsonb;first_receipt jsonb;result jsonb;again jsonb;
 before_bytes bigint;before_programs integer;count_ops integer;charged bigint;candidate record;
begin
 insert into auth.users(id,email) values(owner,owner||'@program-work.invalid'),(other,other||'@program-work.invalid'),(admin,admin||'@program-work.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),owner,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now()),(gen_random_uuid(),admin,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(owner),(admin);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(owner,true,1,'Fixture trabajos'),(other,true,1,'Aislamiento trabajos');
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 recipe:=jsonb_build_object('name','Sesión de trabajo','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 raw:='{"schema":1,"name":" A ","description":"texto pendiente","audience":"","equipment":"","mode":"guide","categories":[],"primary":null,
  "phases":[{"name":"","weeks":"pendiente","instructions":"no completado","pending":[],"replacements":{},"sessions":[]}]}'::jsonb;
 raw:=jsonb_set(jsonb_set(raw,'{name}',to_jsonb(repeat('Nombre ',40))),'{description}',to_jsonb(repeat('texto pendiente privado ',2000)));
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if public.get_trainer_program_work(owner,work_id) is not null or public.list_trainer_program_work(owner)<>'[]'::jsonb then raise exception 'Lectura inicial inventa trabajo';end if;
 first_receipt:=public.save_trainer_program_work(owner,work_id,0,raw);
 if first_receipt->'receipt'->'work'->'state'<>raw or (first_receipt->>'current_revision')::int<>1 then raise exception 'No conserva raw/revisión inicial';end if;
 if public.save_trainer_program_work(owner,work_id,0,raw)<>first_receipt then raise exception 'Reintento inicial duplica trabajo';end if;
 result:=public.list_trainer_program_work(owner);
 if result->0->'state'<>jsonb_build_object('name',left(raw->>'name',160)) or octet_length(result::text)>1500
  or result::text like '%texto pendiente%' or public.get_trainer_program_work(owner,work_id)->'state'<>raw then
  raise exception 'Listado expone checkpoint completo o load pierde raw';end if;
 result:=public.save_trainer_program_work(owner,work_id,1,raw);
 if (result->>'current_revision')::int<>2 then raise exception 'No-op nuevo no avanza revisión';end if;
 changed:=jsonb_set(raw,'{name}','"C de otra pestaña"');
 perform public.save_trainer_program_work(owner,work_id,2,changed);
 again:=public.save_trainer_program_work(owner,work_id,0,raw);
 if again->'receipt'<>first_receipt->'receipt' or (again->>'current_revision')::int<>3
  or again->>'current_lifecycle'<>'open' or again->'receipt'->'work'->'state'<>raw then raise exception 'Recibo antiguo se sustituye por HEAD';end if;
 begin perform public.save_trainer_program_work(owner,work_id,1,jsonb_set(raw,'{name}','"B obsoleto"'));raise exception 'Otra petición toma el recibo ajeno';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(owner,work_id,2,jsonb_set(raw,'{name}','"B obsoleto"'));raise exception 'CAS viejo sobrescribe C';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(owner,work_id,3,raw,gen_random_uuid());raise exception 'Base mutable';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(owner,work_id,3,jsonb_set(raw,'{schema}','2'));raise exception 'Schema mutable';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(owner,gen_random_uuid(),-1,raw);raise exception 'Revisión negativa';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(owner,gen_random_uuid(),2147483647,raw);raise exception 'Revisión sin cota';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(owner,gen_random_uuid(),0,raw||'{"token":"no guardar"}'::jsonb);raise exception 'Estado arbitrario';exception when invalid_parameter_value then null;end;

 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 -- Los headers ya son B pero el trabajo capturado era A. Ninguna de las cinco
 -- RPC puede usar expected_owner como autoridad para leer o escribir en B.
 begin perform public.list_trainer_program_work(owner);raise exception 'Fence list ignora cambio de cuenta';exception when insufficient_privilege then null;end;
 begin perform public.get_trainer_program_work(owner,work_id);raise exception 'Fence get ignora cambio de cuenta';exception when insufficient_privilege then null;end;
 begin perform public.save_trainer_program_work(owner,work_id,0,raw);raise exception 'Fence save escribe rawA enB';exception when insufficient_privilege then null;end;
 begin perform public.discard_trainer_program_work(owner,work_id,3);raise exception 'Fence discard ignora cambio';exception when insufficient_privilege then null;end;
 begin perform public.finalize_trainer_program_work(owner,work_id,3,'{}');raise exception 'Fence finalize ignora cambio';exception when insufficient_privilege then null;end;
 if public.get_trainer_program_work(other,work_id) is not null or public.list_trainer_program_work(other)<>'[]'::jsonb then raise exception 'Cuenta B lee trabajo A';end if;
 perform public.save_trainer_program_work(other,work_id,0,jsonb_set(raw,'{name}','"Trabajo de B"'));
 begin perform public.get_trainer_program_work(owner,work_id);raise exception 'Fence con IDs coincidentes';exception when insufficient_privilege then null;end;
 foreign_template:=public.save_trainer_workout(gen_random_uuid(),recipe);
 perform set_config('request.jwt.claim.sub',admin::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin,'role','authenticated','aal','aal2')::text,true);
 if public.get_trainer_program_work(admin,work_id) is not null or public.list_trainer_program_work(admin)<>'[]'::jsonb then raise exception 'ADMIN amplía permiso privado';end if;
 begin perform public.save_trainer_program_work(admin,work_id,0,raw);raise exception 'ADMIN sin acceso profesional escribe';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 if public.get_trainer_program_work(owner,work_id)->'state'<>changed then raise exception 'UUID igual cruza propietario';end if;
 template:=public.save_trainer_workout(gen_random_uuid(),recipe);
 valid:=jsonb_build_object('schema',1,'name',chr(160)||'Programa'||chr(133),'description',' Descripción ','audience',' Personas ','equipment',' Barra ',
  'mode','guide','categories','[]'::jsonb,'primary',null,'phases',jsonb_build_array(jsonb_build_object('name','Ignorada en guía','weeks','incorrecto',
  'instructions',chr(8195)||'Avanza con control'||chr(65279),'pending','[]'::jsonb,'replacements','{}'::jsonb,'sessions',jsonb_build_array(jsonb_build_object(
   'id',template,'name',chr(133)||'Fuerza'||chr(160),'warmup',null,'adjustable',false,'minimum','-','maximum','todavía inválido')))));
 valid:=jsonb_set(jsonb_set(valid,'{phases,0,sessions,0,positionId}',to_jsonb(gen_random_uuid())),
  '{phases,0,replacementPositions}','{}');
 content:=jsonb_build_object('name','Programa','description','Descripción','audience','Personas','equipment','Barra','mode','guide',
  'phases',jsonb_build_array(jsonb_build_object('name','Entrenamiento','duration_weeks',null,'instructions','Avanza con control',
   'sessions',jsonb_build_array(jsonb_build_object('template_id',template,'name','Fuerza','warmup_id',null,'rest',jsonb_build_object('min_seconds',null,'max_seconds',null))))));
 base:=public.save_trainer_program(gen_random_uuid(),content);
 unchanged_base:=public.save_trainer_program(gen_random_uuid(),content);
 perform public.save_trainer_program_work(owner,work_a,0,valid,base);
 if public.get_trainer_program_work(owner,work_a)->'state'<>valid then raise exception 'No preserva positionId/replacementPositions del esquema compartido';end if;
 perform public.save_trainer_program_work(owner,work_b,0,valid,base);
 begin perform public.finalize_trainer_program_work(owner,work_a,1,jsonb_set(content,'{name}','"Contenido que no estaba guardado"'));
  raise exception 'Programa arbitrario no deriva del snapshot';exception when invalid_parameter_value then null;end;
 if (public.get_trainer_program_work(owner,work_a)->>'revision')::int<>1
  or public.get_trainer_program_work(owner,work_a)->>'lifecycle'<>'open' then raise exception 'Divergencia cambia trabajo';end if;
 reset role;
 update trainer_private.program_work_limits set active_limit=active_count where owner_id=owner;
 set local role authenticated;
 begin perform public.save_trainer_program_work(owner,gen_random_uuid(),0,raw);raise exception 'Supera activos configurados';exception when program_limit_exceeded then null;end;
 finalized:=public.finalize_trainer_program_work(owner,work_a,1,content);
 if finalized is null or public.get_trainer_program_work(owner,work_a)->>'lifecycle'<>'finalized'
  or (public.get_trainer_program_work(owner,work_a)->>'revision')::int<>2 then raise exception 'Finalización no es atómica/monótona o se bloquea por cupo activo';end if;
 if public.finalize_trainer_program_work(owner,work_a,1,content)<>finalized then raise exception 'Base archivada invalida recibo final';end if;
 begin perform public.finalize_trainer_program_work(owner,work_b,1,content);raise exception 'Dos trabajos revisan la misma base';exception when serialization_failure then null;end;
 if public.get_trainer_program_work(owner,work_b)->>'lifecycle'<>'open' then raise exception 'Conflicto pierde el otro trabajo';end if;
 reset role;
 if (select status from trainer_private.programs where id=base)<>'archived' then raise exception 'No usa versionado existente';end if;
 update trainer_private.program_work_limits set active_limit=100 where owner_id=owner;
 set local role authenticated;
 -- El motor final rechaza una sesión privada ajena y revierte también el
 -- archivo provisional de base, el programa insertado y los cargos del trabajo.
 pending:=jsonb_set(valid,'{phases,0,sessions,0,id}',to_jsonb(foreign_template));
 perform public.save_trainer_program_work(owner,bad_work,0,pending,unchanged_base);
 reset role;
 select retained_bytes into before_bytes from trainer_private.program_work_limits where owner_id=owner;
 select count(*) into before_programs from trainer_private.programs where trainer_id=owner;
 set local role authenticated;
 begin perform public.finalize_trainer_program_work(owner,bad_work,1,jsonb_set(content,'{phases,0,sessions,0,template_id}',to_jsonb(foreign_template)));
  raise exception 'Finaliza con sesión ajena';exception when insufficient_privilege then null;end;
 reset role;
 if (select retained_bytes from trainer_private.program_work_limits where owner_id=owner)<>before_bytes
  or (select count(*) from trainer_private.programs where trainer_id=owner)<>before_programs
  or (select status from trainer_private.programs where id=unchanged_base)<>'published' then raise exception 'Finalización fallida deja efectos parciales';end if;
 set local role authenticated;
 pending:=jsonb_set(valid,'{phases,0,pending}',jsonb_build_array(gen_random_uuid()));
 perform public.save_trainer_program_work(owner,pending_work,0,pending);
 begin perform public.finalize_trainer_program_work(owner,pending_work,1,content);raise exception 'Finaliza pendientes';exception when invalid_parameter_value then null;end;
 pending:=jsonb_set(valid,'{phases,0,replacements}',jsonb_build_object(gen_random_uuid()::text,template));
 perform public.save_trainer_program_work(owner,pending_work,1,pending);
 begin perform public.finalize_trainer_program_work(owner,pending_work,2,content);raise exception 'Finaliza sustituciones pendientes';exception when invalid_parameter_value then null;end;
 -- Hexadecimal, signo y whitespace Unicode de dart2js; campos ocultos inválidos
 -- permanecen crudos y no afectan la proyección final.
 pending:=jsonb_set(jsonb_set(valid,'{mode}','"phased"'),'{phases,0,weeks}',to_jsonb(chr(160)||'+0x02'||chr(8195)));
 pending:=jsonb_set(pending,'{phases,0,name}','" Base "');
 phase_content:=jsonb_set(jsonb_set(jsonb_set(content,'{mode}','"phased"'),'{phases,0,name}','"Base"'),'{phases,0,duration_weeks}','2');
 perform public.save_trainer_program_work(owner,pending_work,2,pending);
 legacy:=public.finalize_trainer_program_work(owner,pending_work,3,phase_content);
 if legacy is null then raise exception 'Parser no coincide con web';end if;
 -- La misma UUID del trabajo nunca acepta el recibo legacy ajeno, ni aunque
 -- coincida exactamente la receta. Ambos trabajos y bases se conservan.
 perform public.save_trainer_program_work(owner,collision,0,valid);
 legacy:=public.save_trainer_program(collision,content);
 begin perform public.finalize_trainer_program_work(owner,collision,1,content);raise exception 'Usa recibo legacy exacto como finalización propia';exception when invalid_parameter_value then null;end;
 perform public.save_trainer_program_work(owner,collision2,0,valid);
 legacy:=public.save_trainer_program(collision2,jsonb_set(content,'{name}','"Otro programa legacy"'));
 begin perform public.finalize_trainer_program_work(owner,collision2,1,content);raise exception 'Usa recibo legacy distinto';exception when invalid_parameter_value then null;end;
 result:=public.discard_trainer_program_work(owner,work_id,3);
 if result->>'current_lifecycle'<>'discarded' or (result->>'current_revision')::int<>4 then raise exception 'Descarte no avanza revisión';end if;
 if public.discard_trainer_program_work(owner,work_id,3)<>result then raise exception 'Descarte duplica recibo';end if;
 again:=public.save_trainer_program_work(owner,work_id,0,raw);
 if again->'receipt'<>first_receipt->'receipt' or again->>'current_lifecycle'<>'discarded' or (again->>'current_revision')::int<>4 then raise exception 'Recibo antiguo reabre descartado';end if;
 begin perform public.save_trainer_program_work(owner,work_id,4,raw);raise exception 'Reabre trabajo descartado';exception when serialization_failure then null;end;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=owner;
 set local role authenticated;
 if public.get_trainer_program_work(owner,work_a)->>'finalized_program_id'<>finalized::text or jsonb_array_length(public.list_trainer_program_work(owner))=0 then raise exception 'Revocar acceso borra consulta propia';end if;
 if public.finalize_trainer_program_work(owner,work_a,1,content)<>finalized then raise exception 'Revocar acceso impide recibo final confirmado';end if;
 begin perform public.finalize_trainer_program_work(owner,work_a,1,jsonb_set(content,'{name}','"Petición distinta"'));raise exception 'Recibo final cambia tras revocar acceso';exception when invalid_parameter_value then null;end;
 begin perform public.finalize_trainer_program_work(owner,work_b,1,content);raise exception 'Revocado finaliza trabajo nuevo';exception when insufficient_privilege then null;end;
 begin perform public.save_trainer_program_work(owner,work_id,0,raw);raise exception 'Revocado usa replay de autoría';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_program_work(owner,work_a);raise exception 'Lee sin MFA';exception when insufficient_privilege then null;end;
 begin perform public.finalize_trainer_program_work(owner,work_a,1,content);raise exception 'Replay final sin MFA';exception when insufficient_privilege then null;end;
 reset role;
 update public.trainer_access set enabled=true where trainer_id=owner;
 -- Toda retención de cuerpos, HEAD, recibos y peticiones finales está cargada.
 select 4096+coalesce((select sum(logical_bytes) from trainer_private.program_work_bodies where owner_id=owner),0)
  +coalesce((select sum(logical_bytes) from trainer_private.program_works where owner_id=owner),0)
  +coalesce((select sum(logical_bytes) from trainer_private.program_work_operations where owner_id=owner),0) into charged;
 if charged<>(select retained_bytes from trainer_private.program_work_limits where owner_id=owner) then raise exception 'Presupuesto omite estados/recibos/metadata';end if;
 -- Cuotas y tasa no se evaden con no-op o recibos antiguos.
 update trainer_private.program_work_limits set active_limit=1,snapshot_limit=1 where owner_id=other;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 begin perform public.save_trainer_program_work(other,work_id,1,raw);raise exception 'Ignora cota por snapshot';exception when program_limit_exceeded then null;end;
 reset role;
 update trainer_private.program_work_limits set snapshot_limit=524288,byte_limit=retained_bytes where owner_id=other;
 set local role authenticated;
 begin perform public.save_trainer_program_work(other,work_id,1,jsonb_set(raw,'{name}','"B nuevo"'));raise exception 'Ignora retención total';exception when program_limit_exceeded then null;end;
 reset role;
 update trainer_private.program_work_limits set byte_limit=67108864,hourly_limit=1 where owner_id=other;
 set local role authenticated;
 begin perform public.save_trainer_program_work(other,work_id,1,jsonb_set(raw,'{name}','"B nuevo"'));raise exception 'No-op/edición evade tasa';exception when program_limit_exceeded then null;end;
 result:=public.save_trainer_program_work(other,work_id,0,jsonb_set(raw,'{name}','"Trabajo de B"'));
 if (result->>'current_revision')::int<>1 then raise exception 'Tasa/cuota rompe replay sin efectos';end if;
 reset role;
 if (select count(*) from trainer_private.program_work_operations where owner_id=other)<>1 then raise exception 'Fallo o replay consume tasa';end if;
 -- Vectores contrastados con Dart compilado a JavaScript: no aplicar el wrap
 -- de int64 nativo ni tratar U+0085 como whitespace del parser web.
 for candidate in select * from(values
  ('+12',12),('0012',12),('0X10',16),('+0x10',16),('-0x0',0),
  (chr(160)||'12'||chr(65279),12),('0x'||repeat('0',1000)||'10',16),
  (repeat('0',1000)||'12',12),(chr(133)||'12',null),('12'||chr(133),null),
  ('+ 1',null),('1.0',null),('1e2',null),('1_000',null),('0b10',null),('0o10',null),
  ('9007199254740993',null),('0xffffffffffffffff',null),('١٢',null),('１２',null)
 )as vectors(raw_value,expected) loop
  if trainer_private.program_work_integer(candidate.raw_value) is distinct from candidate.expected then
   raise exception 'Parseo entero distinto de Dart web: %',candidate.raw_value;end if;
 end loop;
 if trainer_private.program_work_trim(chr(133)||'Nombre'||chr(160))<>'Nombre'
  or trainer_private.program_work_trim(chr(8203)||'Nombre')<>chr(8203)||'Nombre' then raise exception 'Trim distinto de Dart web';end if;
 pending:=jsonb_set(valid,'{phases,0,replacementPositions}',jsonb_build_object(gen_random_uuid()::text,valid#>>'{phases,0,sessions,0,positionId}'));
 perform trainer_private.validate_program_work_state(pending);
 begin perform trainer_private.program_work_projection(pending);raise exception 'Finaliza mapa de posiciones pendiente sin replacements legacy';exception when invalid_parameter_value then null;end;
 begin perform trainer_private.validate_program_work_state(jsonb_set(valid,'{phases,0,replacement_positions}','{}'));
  raise exception 'Admite alias snake de fase sin contrato';exception when invalid_parameter_value then null;end;
 begin perform trainer_private.validate_program_work_state(jsonb_set(valid,'{phases,0,sessions,0,position_id}','"sin contrato"'));
  raise exception 'Admite alias snake de sesión sin contrato';exception when invalid_parameter_value then null;end;
 if has_table_privilege('authenticated','trainer_private.program_works','SELECT')
  or has_function_privilege('authenticated','trainer_private.program_work_projection(jsonb)','EXECUTE')
  or has_function_privilege('authenticated','trainer_private.lock_program_work_owner(uuid)','EXECUTE')
  or has_function_privilege('anon','public.get_trainer_program_work(uuid,uuid)','EXECUTE') then raise exception 'Grants exponen trabajos/helpers';end if;
end $$;
select 'trainer_program_work_drafts: OK' as result;
rollback;
