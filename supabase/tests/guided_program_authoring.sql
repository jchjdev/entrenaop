-- Autoría, permisos e inmutabilidad. No deja contenido de prueba.
begin;
select set_config('request.jwt.claims','{"aal":"aal2"}',true);
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
set local role authenticated;
do $$
declare payload jsonb; content jsonb; phase jsonb; slot jsonb;
  exercise uuid; session_id uuid; warmup uuid; second_warmup uuid; program uuid; revision uuid;
begin
  if not coalesce(public.is_admin(),false) then raise exception 'La prueba necesita un administrador.'; end if;
  select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' limit 1;
  payload:=jsonb_build_object('name','Prueba editorial transaccional','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',8,'rest_after_seconds',90)
    )))
  )));
  session_id:=public.create_admin_workout_draft(null,payload);
  perform public.publish_admin_workout_draft(session_id);
  warmup:=public.save_guided_warmup(payload);
  if exists(select 1 from public.guided_warmups w join public.workout_templates t on t.id=w.template_id
    where w.id=warmup and (t.visibility<>'private' or t.origin<>'system')) then
    raise exception 'El calentamiento se expone como sesión general.';
  end if;
  if exists(select 1 from public.guided_warmups w join public.workout_blocks b on b.template_id=w.template_id
    where w.id=warmup and b.format<>'warm_up') then raise exception 'No conserva el formato de calentamiento.'; end if;
  second_warmup:=public.save_guided_warmup(payload,warmup);
  if (select version from public.guided_warmups where id=second_warmup)<>2 then raise exception 'No se versiona el calentamiento.'; end if;
  slot:=jsonb_build_object('template_id',session_id,'name','Sesión A','warmup_id',warmup,
    'rest',jsonb_build_object('min_seconds',60,'max_seconds',180));
  phase:=jsonb_build_object('name','Entrenamiento','instructions','','sessions',jsonb_build_array(slot));
  content:=jsonb_build_object('name','Guía temporal','mode','guide','phases',jsonb_build_array(phase));
  program:=public.save_guided_program(content);
  perform public.set_guided_program_status(program,'published');
  revision:=public.save_guided_program(content||' {"name":"Guía revisada"}'::jsonb,program);
  if revision=program or (select version from public.guided_programs where id=revision)<>2
    or (select p.content->>'name' from public.guided_programs p where p.id=program)<>'Guía temporal' then
    raise exception 'Se ha modificado la versión publicada.';
  end if;
  begin
    perform public.save_guided_program(jsonb_set(content,'{phases,0,sessions,0,rest,max_seconds}','30'));
    raise exception 'Aceptó descansos invertidos.';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_guided_program(content||'{"mode":"phased"}'::jsonb);
    raise exception 'Aceptó fases sin duración ni condiciones.';
  exception when sqlstate '22023' then null; end;
  content:=jsonb_set(content,'{mode}','"phased"');
  content:=jsonb_set(content,'{phases,0,duration_weeks}','2');
  content:=jsonb_set(content,'{phases,0,instructions}','"Revisar las sesiones antes de confirmar el avance."');
  perform public.save_guided_program(content);
  begin
    update public.guided_programs set status='published' where id=revision;
    raise exception 'Permite publicar sin RPC.';
  exception when insufficient_privilege then null; end;
  perform set_config('entrenaop.test_guided_program',program::text,true);
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000019',true);
do $$
begin
  if (select count(*) from public.guided_programs where id=current_setting('entrenaop.test_guided_program')::uuid)<>1 then
    raise exception 'El deportista no puede consultar el programa publicado.';
  end if;
  if exists(select 1 from public.guided_programs where status='draft') then raise exception 'Se filtran borradores.'; end if;
  begin
    perform public.save_guided_program('{}'::jsonb);
    raise exception 'Un deportista pudo crear contenido oficial.';
  exception when insufficient_privilege then null; end;
  begin
    perform public.save_guided_warmup('{}'::jsonb);
    raise exception 'Un deportista pudo crear calentamientos.';
  exception when insufficient_privilege then null; end;
  begin
    perform public.set_guided_program_status(current_setting('entrenaop.test_guided_program')::uuid,'archived');
    raise exception 'Un deportista pudo retirar contenido oficial.';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
