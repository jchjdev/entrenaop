-- Formularios fijados a versión, respuestas completas, MFA y aislamiento.
begin;
set local statement_timeout='45s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 rel uuid:=gen_random_uuid(); operation uuid:=gen_random_uuid(); delivery uuid:=gen_random_uuid();
 submitted uuid:=gen_random_uuid(); f uuid; revised uuid; pending uuid:=gen_random_uuid();
 payload jsonb; answers jsonb; j jsonb; bad jsonb;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@trainer-forms.invalid'),
  (pupil,pupil||'@trainer-forms.invalid'),(other,other||'@trainer-forms.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(other);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture formularios');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,trainer,pupil,now());
 payload:='{"title":"Revisión semanal","description":null,"questions":[
  {"id":"number","position":0,"prompt":"Minutos","type":"number","required":true,"options":[],"minimum":0,"maximum":1000},
  {"id":"boolean","position":1,"prompt":"¿Has entrenado?","type":"yesNo","required":true,"options":[]},
  {"id":"text","position":2,"prompt":"Comentarios","type":"longText","required":false,"options":[]},
  {"id":"choice","position":3,"prompt":"Horario","type":"singleChoice","required":true,"options":[{"id":"morning","label":"Mañana"},{"id":"evening","label":"Tarde"}]},
  {"id":"multiple","position":4,"prompt":"Material","type":"multipleChoice","required":true,"maximum_selections":2,"options":[{"id":"band","label":"Goma"},{"id":"bar","label":"Barra"}]},
  {"id":"scale","position":5,"prompt":"Sensación","type":"scale","required":true,"options":[],"minimum":1,"maximum":5}
 ]}'::jsonb;
 answers:='{"number":0,"boolean":false,"choice":"morning","multiple":["bar"],"scale":1}'::jsonb;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 f:=public.save_trainer_form(operation,payload);
 if public.save_trainer_form(operation,payload)<>f then raise exception 'Reintento duplica formulario'; end if;
 begin perform public.save_trainer_form(operation,jsonb_set(payload,'{title}','"Otro"')); raise exception 'Cambia reintento'; exception when invalid_parameter_value then null; end;
 if jsonb_array_length(public.list_trainer_forms())<>1 then raise exception 'Biblioteca incorrecta'; end if;
 if has_table_privilege('authenticated','trainer_private.forms','SELECT') or
  has_function_privilege('authenticated','trainer_private.form_assignment_json(uuid)','EXECUTE') then raise exception 'Abre tablas/helper'; end if;
 foreach bad in array array[
  jsonb_set(payload,'{questions,0,type}','"attachment"'),
  jsonb_set(payload,'{questions,0,id}','"bad id"'),
  jsonb_set(payload,'{questions,1,id}','"number"'),
  jsonb_set(payload,'{questions,1,position}','0'),
  jsonb_set(payload,'{questions,0,required}','"true"'),
  jsonb_set(payload,'{questions,5,maximum}','22'),
  jsonb_set(payload,'{questions,3,options,1,id}','"morning"'),
  payload||'{"trainer_id":"forged"}'::jsonb
 ] loop
  begin perform public.save_trainer_form(gen_random_uuid(),bad); raise exception 'Acepta formulario inválido: %',bad; exception when invalid_parameter_value then null; end;
 end loop;
 perform public.assign_trainer_form(delivery,rel,f,current_date);
 perform public.assign_trainer_form(delivery,rel,f,current_date);
 begin perform public.assign_trainer_form(delivery,rel,f,current_date+1); raise exception 'Cambia fecha de reintento'; exception when invalid_parameter_value then null; end;
 revised:=public.save_trainer_form(gen_random_uuid(),jsonb_set(payload,'{title}','"Revisión nueva"'),f);
 if (public.get_trainer_form(f)->>'current')::boolean or (public.get_trainer_form(revised)->>'version')::integer<>2 then raise exception 'Revisión incorrecta'; end if;
 if jsonb_array_length(public.list_trainer_form_assignments(pupil))<>1 then raise exception 'Duplica entrega'; end if;
 perform public.assign_trainer_form(pending,rel,revised,current_date+1);

 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if public.list_trainer_forms()<>'[]'::jsonb or public.list_trainer_form_assignments(pupil)<>'[]'::jsonb then raise exception 'ADMIN lee biblioteca ajena'; end if;
 begin perform public.get_trainer_form(f); raise exception 'ADMIN abre formulario ajeno'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_form_submission(delivery); raise exception 'ADMIN abre respuesta ajena'; exception when insufficient_privilege then null; end;
 begin perform public.assign_trainer_form(gen_random_uuid(),rel,revised,current_date); raise exception 'Otro asigna'; exception when insufficient_privilege then null; end;

 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 j:=public.list_my_trainer_forms();
 if jsonb_array_length(j)<>2 or (public.get_trainer_form_submission(delivery)->'content'->>'title')<>'Revisión semanal' then raise exception 'Pierde versión fijada'; end if;
 foreach bad in array array[
  answers-'boolean', answers-'number', answers||'{"other":null}'::jsonb,
  jsonb_set(answers,'{number}','"0"'), jsonb_set(answers,'{boolean}','0'),
  jsonb_set(answers,'{choice}','"other"'),jsonb_set(answers,'{multiple}','["bar","bar"]'),
  jsonb_set(answers,'{multiple}','["other"]'),jsonb_set(answers,'{scale}','1.5'),
  jsonb_set(answers,'{number}','-1'),jsonb_set(answers,'{text}','"   "')
 ] loop
  begin perform public.submit_trainer_form(submitted,delivery,bad); raise exception 'Acepta respuesta inválida: %',bad; exception when invalid_parameter_value then null; end;
 end loop;
 perform public.submit_trainer_form(submitted,delivery,answers);
 perform public.submit_trainer_form(submitted,delivery,answers);
 begin perform public.submit_trainer_form(submitted,delivery,jsonb_set(answers,'{number}','1')); raise exception 'Reescribe respuesta'; exception when invalid_parameter_value then null; end;
 begin perform public.submit_trainer_form(gen_random_uuid(),delivery,answers); raise exception 'Repite entrega con nueva orden'; exception when invalid_parameter_value then null; end;
 j:=public.get_trainer_form_submission(delivery);
 if j->'answers'->'number'<>'0'::jsonb or j->'answers'->'boolean'<>'false'::jsonb or j->>'submitted_at' is null then raise exception 'Confunde cero/falso con ausencia'; end if;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=trainer;
 set local role authenticated;
 begin perform public.submit_trainer_form(gen_random_uuid(),pending,answers); raise exception 'Responde con acceso profesional desactivado'; exception when insufficient_privilege then null; end;
 if (public.get_trainer_form_submission(pending)->>'can_respond')::boolean then raise exception 'Ofrece respuesta con acceso desactivado'; end if;
 if public.get_trainer_form_submission(delivery)->'answers' is distinct from answers then raise exception 'Desactivar acceso pierde consulta'; end if;
 reset role;
 update public.trainer_access set enabled=true where trainer_id=trainer;
 set local role authenticated;
 perform public.end_trainer_relation(rel);
 begin perform public.submit_trainer_form(gen_random_uuid(),pending,answers); raise exception 'Responde tras baja'; exception when insufficient_privilege then null; end;
 perform public.submit_trainer_form(submitted,delivery,answers);
 if public.get_trainer_form_submission(delivery)->'answers' is distinct from answers then raise exception 'Baja pierde consulta'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 if jsonb_array_length(public.list_trainer_form_assignments(pupil))<>2 then raise exception 'Baja pierde cartera'; end if;
 begin perform public.assign_trainer_form(gen_random_uuid(),rel,revised,current_date); raise exception 'Asigna tras baja'; exception when insufficient_privilege then null; end;
 reset role;
 update trainer_private.form_limits set version_limit=2 where trainer_id=trainer;
 set local role authenticated;
 begin perform public.save_trainer_form(gen_random_uuid(),payload); raise exception 'Supera cuota de versiones'; exception when invalid_parameter_value then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.list_trainer_forms(); raise exception 'Lee sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_form_submission(delivery); raise exception 'Lee respuesta sin MFA'; exception when insufficient_privilege then null; end;
 reset role;
end $$;
select 'trainer_followup_forms: OK' as result;
rollback;
