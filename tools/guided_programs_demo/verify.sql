-- Comprueba el contenido demo ya publicado sin dejar registros de entrenamiento.
begin;
do $$
declare
  owner_id uuid := gen_random_uuid();
  program record; link record; work_set record; execution uuid; follow_id uuid;
  omit_warmup boolean; checked integer := 0; source_before jsonb; source_after jsonb;
begin
  insert into auth.users(id,email) values(owner_id,owner_id||'@guided-demo.example.invalid');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  set local role authenticated;

  if (select count(*) from public.get_guided_program_catalog('Demo',null,0,100,false)
      where content->>'demo_key' in ('guided-demo-v1-guide','guided-demo-v1-phased'))<>2 then
    raise exception 'Los dos programas no están visibles para un deportista.';
  end if;
  for program in select * from public.guided_programs
    where content->>'demo_key' in ('guided-demo-v1-guide','guided-demo-v1-phased') order by content->>'demo_key'
  loop
    if program.status<>'published' or
      jsonb_array_length(program.content->'phases') <> (case when program.content->>'mode'='guide' then 1 else 3 end) or
      (select count(*) from public.guided_program_links where program_id=program.id)<>3 then
      raise exception 'No conserva el modo y las tres sesiones solicitadas.';
    end if;
    follow_id := public.follow_guided_program(program.id);
    for link in select * from public.guided_program_links
      where program_id=program.id order by phase_index,session_index
    loop
      select jsonb_agg(jsonb_build_array(s.id,s.rest_after_seconds,s.target_reps) order by s.id)
        into source_before from public.workout_blocks b
        join public.workout_items i on i.block_id=b.id join public.workout_sets s on s.item_id=i.id
        where b.template_id=link.template_id;
      omit_warmup := checked%2=0;
      execution := public.start_guided_program_session(program.id,link.phase_index,link.session_index,
        gen_random_uuid(),omit_warmup,75);
      if not exists(select 1 from public.workout_executions
        where id=execution and user_id=owner_id and status='in_progress' and session_type='strength') then
        raise exception 'No inicia en el ejecutor de fuerza habitual.';
      end if;
      if not exists(select 1 from public.workout_execution_sets
        where execution_id=execution and block_format='warm_up') or
        exists(select 1 from public.workout_execution_sets where execution_id=execution and block_format='warm_up'
          and status<>(case when omit_warmup then 'skipped' else 'pending' end)) then
        raise exception 'No respeta la elección de calentamiento.';
      end if;
      if exists(select 1 from public.workout_execution_sets where execution_id=execution
        and block_format='straight_sets' and rest_after_seconds<>75) then
        raise exception 'No aplica el descanso elegido.';
      end if;
      for work_set in select * from public.workout_execution_sets
        where execution_id=execution and status='pending' order by block_order,item_order,set_order
      loop
        perform public.complete_workout_set_idempotent(gen_random_uuid(),work_set.id,
          p_actual_reps=>work_set.target_reps,p_actual_rpe=>7,p_actual_rir=>3);
      end loop;
      perform public.finish_workout_execution_idempotent(gen_random_uuid(),execution,7,null,null,null,'manual');
      if not exists(select 1 from public.workout_executions where id=execution and status='completed') then
        raise exception 'No termina la sesión en el historial habitual.';
      end if;
      select jsonb_agg(jsonb_build_array(s.id,s.rest_after_seconds,s.target_reps) order by s.id)
        into source_after from public.workout_blocks b
        join public.workout_items i on i.block_id=b.id join public.workout_sets s on s.item_id=i.id
        where b.template_id=link.template_id;
      if source_before is distinct from source_after then
        raise exception 'El entrenamiento ha modificado la sesión pública.';
      end if;
      if program.content->>'mode'='phased' then
        if (select phase_index from public.guided_program_follows where id=follow_id)<>link.phase_index then
          raise exception 'Ha avanzado sin confirmación.';
        end if;
        perform public.advance_guided_program(follow_id,link.phase_index);
      end if;
      checked := checked+1;
    end loop;
    if (select completed_at is not null from public.guided_program_follows where id=follow_id)
        is distinct from (program.content->>'mode'='phased') then
      raise exception 'No distingue la guía repetible del programa terminado.';
    end if;
  end loop;
  if checked<>6 then raise exception 'No se han comprobado las seis sesiones.'; end if;
  reset role;
end $$;
select 'Dos programas y seis sesiones comprobados; catálogo, ejecución, calentamientos, descansos y fases correctos.' as result;
rollback;
