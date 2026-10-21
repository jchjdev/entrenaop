-- Cartera duradera: aislamiento, archivo y vuelta. Nunca deja fixtures.
begin;
set local statement_timeout='30s';
do $$
declare
 trainer uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
 secret text:=encode(extensions.gen_random_bytes(32),'hex');
 second_secret text:=encode(extensions.gen_random_bytes(32),'hex');
 relation uuid; next_relation uuid; j jsonb;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@portfolio.invalid'),
   (other,other||'@portfolio.invalid'),(pupil,pupil||'@portfolio.invalid');
 update public.profiles set full_name='Alumno de la primera etapa' where id=pupil;
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
   (gen_random_uuid(),trainer,'totp','verified',now(),now()),
   (gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(other);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
   values(trainer,true,1,'Fixture de cartera');
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 perform public.create_trainer_invitation(gen_random_uuid(),secret);
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 relation:=public.accept_trainer_invitation(secret);
 if exists(select 1 from public.trainer_clients) then raise exception 'El alumno lee carteras profesionales'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 j:=public.list_trainer_clients();
 if jsonb_array_length(j)<>1 or j->0->>'active_relation_id'<>relation::text then raise exception 'No crea la ficha activa'; end if;
 begin perform public.archive_trainer_client(pupil,true); raise exception 'Archiva un alumno activo';
   exception when sqlstate '22023' then null; end;
 begin perform public.list_trainer_clients('invalid'); raise exception 'Admite estado ajeno';
   exception when sqlstate '22023' then null; end;
 begin perform public.list_trainer_clients('active',now(),null); raise exception 'Admite cursor parcial';
   exception when sqlstate '22023' then null; end;
 if jsonb_array_length(public.list_trainer_clients('active',(j->0->>'updated_at')::timestamptz,pupil))<>0
   then raise exception 'La página repite su cursor'; end if;
 begin update public.trainer_clients set archived_at=now() where client_id=pupil;
   raise exception 'Admite escritura directa'; exception when insufficient_privilege then null; end;
 begin insert into public.trainer_clients(trainer_id,client_id,display_name,created_at,updated_at)
   values(trainer,other,'Ficha inventada',now(),now());
   raise exception 'Admite insertar fichas sin aceptación'; exception when insufficient_privilege then null; end;
 begin delete from public.trainer_clients where client_id=pupil;
   raise exception 'Admite borrado directo'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 if exists(select 1 from public.trainer_clients) then raise exception 'AAL1 lee cartera'; end if;
 begin perform public.list_trainer_clients(); raise exception 'AAL1 lista cartera'; exception when insufficient_privilege then null; end;
 begin perform public.archive_trainer_client(pupil,false); raise exception 'AAL1 archiva'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_client_relations(pupil); raise exception 'AAL1 consulta etapas'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if exists(select 1 from public.trainer_clients) or jsonb_array_length(public.list_trainer_clients())<>0
   then raise exception 'Otro entrenador/admin lee la cartera ajena'; end if;
 begin perform public.get_trainer_client_relations(pupil); raise exception 'Consulta etapas ajenas'; exception when insufficient_privilege then null; end;
 begin perform public.archive_trainer_client(pupil,true); raise exception 'Archiva ficha ajena'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 perform public.end_trainer_relation(relation);
 reset role;
 update public.profiles set full_name='Nombre cambiado después de terminar' where id=pupil;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 j:=public.list_trainer_clients('inactive');
 if jsonb_array_length(j)<>1 or j->0->>'person_name'<>'Alumno de la primera etapa'
   or (public.get_trainer_access()->>'active_clients')::int<>0 then raise exception 'La baja pierde ficha o mantiene cupo'; end if;
 perform public.archive_trainer_client(pupil,true);
 perform public.archive_trainer_client(pupil,true);
 if jsonb_array_length(public.list_trainer_clients('archived'))<>1
   or jsonb_array_length(public.get_trainer_client_relations(pupil))<>1 then raise exception 'Archivo borra la etapa'; end if;
 perform public.archive_trainer_client(pupil,false);
 if jsonb_array_length(public.list_trainer_clients('inactive'))<>1 or jsonb_array_length(public.list_trainer_clients())<>0
   then raise exception 'Recuperar reactiva el servicio'; end if;
 perform public.archive_trainer_client(pupil,true);
 perform public.create_trainer_invitation(gen_random_uuid(),second_secret);
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 begin perform public.accept_trainer_invitation(secret); raise exception 'Reabre la etapa con el código antiguo';
   exception when sqlstate '22023' then null; end;
 next_relation:=public.accept_trainer_invitation(second_secret);
 if next_relation=relation then raise exception 'Reutiliza la etapa terminada'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 j:=public.list_trainer_clients();
 if jsonb_array_length(j)<>1 or (j->0->>'episode_count')::int<>2
   or j->0->>'person_name'<>'Nombre cambiado después de terminar'
   or jsonb_array_length(public.list_trainer_clients('archived'))<>0
   or (public.get_trainer_access()->>'active_clients')::int<>1 then raise exception 'La vuelta duplica o pierde la ficha'; end if;
 j:=public.get_trainer_client_relations(pupil);
 if jsonb_array_length(j)<>2 then raise exception 'Pierde historial al volver'; end if;
 if jsonb_array_length(public.get_trainer_client_relations(pupil,(j->1->>'accepted_at')::timestamptz,(j->1->>'id')::uuid))<>0
   then raise exception 'El historial repite cursor'; end if;
 reset role;
 set local role anon;
 begin perform 1 from public.trainer_clients; raise exception 'Anon lee cartera'; exception when insufficient_privilege then null; end;
 begin perform public.list_trainer_clients(); raise exception 'Anon lista cartera'; exception when insufficient_privilege then null; end;
 reset role;
end $$;
select 'trainer_client_portfolio: OK' as result;
rollback;
