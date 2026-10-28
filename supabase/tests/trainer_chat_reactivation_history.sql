begin;
set local statement_timeout='45s';
do $$
declare
 coach uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid();
 outsider uuid:=gen_random_uuid(); old_stage uuid:=gen_random_uuid(); current_stage uuid:=gen_random_uuid();
 foreign_stage uuid:=gen_random_uuid(); other_pupil_stage uuid:=gen_random_uuid();
 first_message uuid:=gen_random_uuid(); new_message uuid:=gen_random_uuid();
 result jsonb; page jsonb; row_data jsonb; context jsonb; collected uuid[]:='{}';
 before_at timestamptz; before_id uuid; expected uuid[]; stamp timestamptz:=now()-interval '1 hour';
begin
 insert into auth.users(id,email) values
 (coach,coach||'@chat-history.invalid'),(pupil,pupil||'@chat-history.invalid'),
 (stranger,stranger||'@chat-history.invalid'),(outsider,outsider||'@chat-history.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
 (gen_random_uuid(),coach,'totp','verified',now(),now()),
 (gen_random_uuid(),stranger,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,5,'Continuidad del chat');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at,ended_at,ended_by) values
 (old_stage,coach,pupil,now()-interval '3 days',now()-interval '1 day',coach);
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values
 (current_stage,coach,pupil,now()),(foreign_stage,stranger,pupil,now()),(other_pupil_stage,coach,outsider,now());
 insert into trainer_private.messages(id,relation_id,sender_id,body,created_at) values
 (first_message,old_stage,pupil,'Anterior',stamp),
 (gen_random_uuid(),foreign_stage,pupil,'Otro preparador',now()),
 (gen_random_uuid(),other_pupil_stage,outsider,'Otro alumno',now());
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 if jsonb_array_length(public.list_trainer_messages(current_stage))<>1 then raise exception 'Reactivación oculta el historial';end if;
 context:=public.get_trainer_conversation(old_stage);
 if (context->>'can_send')::boolean then raise exception 'Reabre envíos de etapa cerrada';end if;
 begin perform public.send_trainer_message(gen_random_uuid(),old_stage,'No permitido');raise exception 'Escribe en etapa cerrada';exception when insufficient_privilege then null;end;
 new_message:=gen_random_uuid();
 perform public.send_trainer_message(new_message,current_stage,'Continúa la conversación');
 result:=public.list_trainer_messages(current_stage);
 if jsonb_array_length(result)<>2 or result->0->>'id'<>new_message::text or result->1->>'id'<>first_message::text then raise exception 'No une ambas etapas en orden';end if;
 if not (public.get_trainer_conversation(current_stage)->>'can_send')::boolean then raise exception 'No permite responder en etapa activa';end if;
 result:=public.list_trainer_messages(old_stage);
 if jsonb_array_length(result)<>1 or result->0->>'id'<>first_message::text then raise exception 'Modifica la consulta histórica cerrada';end if;
 -- El histórico de fuerza no puede incluir la conversación de carrera.
 begin perform public.list_trainer_messages(other_pupil_stage);raise exception 'Alumno lee otro alumno';exception when insufficient_privilege then null;end;
 begin perform public.list_trainer_messages(current_stage,now(),null);raise exception 'Cursor parcial';exception when invalid_parameter_value then null;end;
 reset role;
 if (select relation_id from trainer_private.messages where id=first_message)<>old_stage then raise exception 'Traslada mensajes';end if;
 if (select relation_id from trainer_private.messages where id=new_message)<>current_stage then raise exception 'El envío pierde su etapa';end if;
 -- 121 mensajes con fechas empatadas entre etapas: cursor compuesto sin huecos.
 insert into trainer_private.messages(id,relation_id,sender_id,body,created_at)
 select gen_random_uuid(),case when i%2=0 then old_stage else current_stage end,pupil,'Página '||i,stamp
 from generate_series(1,121) i;
 select array_agg(m.id order by m.created_at desc,m.id desc) into expected
 from trainer_private.messages m where relation_id in(old_stage,current_stage);
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 loop
  page:=public.list_trainer_messages(current_stage,before_at,before_id);
  if jsonb_array_length(page)>50 then raise exception 'Página sin cota';end if;
  exit when jsonb_array_length(page)=0;
  for row_data in select value from jsonb_array_elements(page) loop
   if row_data->>'body' in('Otro preparador','Otro alumno') then raise exception 'Mezcla conversaciones ajenas';end if;
   collected:=array_append(collected,(row_data->>'id')::uuid);
  end loop;
  before_at:=(page->(jsonb_array_length(page)-1)->>'created_at')::timestamptz;
  before_id:=(page->(jsonb_array_length(page)-1)->>'id')::uuid;
  if cardinality(collected)>150 then raise exception 'Cursor no progresa';end if;
 end loop;
 if collected is distinct from expected then raise exception 'Historial paginado pierde o duplica mensajes';end if;
 -- Acuses originales por ID: leer el agregado no exige cambiar avisos ni sus fuentes.
 perform public.read_trainer_messages(coach,array[first_message]);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal1')::text,true);
 begin perform public.list_trainer_messages(current_stage);raise exception 'Preparador sin MFA';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',stranger::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',stranger,'role','authenticated','aal','aal2')::text,true);
 begin perform public.list_trainer_messages(current_stage);raise exception 'Otro preparador lee histórico';exception when insufficient_privilege then null;end;
 if jsonb_array_length(public.list_trainer_messages(foreign_stage))<>1 then raise exception 'Contamina conversación del otro preparador';end if;
 reset role;
 -- Volver a desactivar conserva exactamente su etapa en consulta, sin envíos.
 update public.trainer_client_relations set ended_at=now(),ended_by=coach where id=current_stage;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 if (public.get_trainer_conversation(current_stage)->>'can_send')::boolean then raise exception 'Baja permite envío';end if;
 if exists(select 1 from jsonb_array_elements(public.list_trainer_messages(current_stage)) x where x->>'id'=first_message::text) then raise exception 'Baja cambia la consulta por etapa';end if;
 reset role;
 set local role anon;
 begin perform public.list_trainer_messages(current_stage);raise exception 'Anónimo consulta chat';exception when insufficient_privilege then null;end;
 reset role;
end $$;
select 'trainer_chat_reactivation_history: OK' as result;
rollback;
