begin;

-- Los programas editoriales materializan copias con origin=algorithm, pero no
-- consumen el algoritmo adaptativo Pro. El contexto solo existe entre dos pasos
-- del RPC ya autorizado y queda vacío al terminar la misma transacción.
create table trainer_private.guided_workout_start_contexts (
  template_id uuid primary key references public.workout_templates(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_id xid8 not null
);
alter table trainer_private.guided_workout_start_contexts enable row level security;
revoke all on table trainer_private.guided_workout_start_contexts from public,anon,authenticated,service_role;

do $migration$
declare definition text;
  anchor text := '    where t.id = p_template_id and t.origin = ''algorithm'') then';
begin
  definition := pg_get_functiondef('trainer_private.start_workout_execution(uuid)'::regprocedure);
  if strpos(definition, anchor) = 0 then
    raise exception 'Revisar la guarda Pro del inicio de entrenamiento.';
  end if;
  execute replace(definition, anchor,
    '    where t.id = p_template_id and t.origin = ''algorithm'') and not exists (' || E'\n'
    || '    select 1 from trainer_private.guided_workout_start_contexts c' || E'\n'
    || '    where c.template_id = p_template_id and c.user_id = current_user_id' || E'\n'
    || '      and c.transaction_id = pg_current_xact_id()) then');

  definition := pg_get_functiondef('public.start_guided_program_session(uuid,integer,integer,uuid,boolean,integer)'::regprocedure);
  anchor := '  execution:=public.start_workout_execution(template);';
  if strpos(definition, anchor) = 0 then
    raise exception 'Revisar la materialización autorizada de programas.';
  end if;
  execute replace(definition, anchor,
    '  insert into trainer_private.guided_workout_start_contexts(template_id,user_id,transaction_id)' || E'\n'
    || '    values(template,auth.uid(),pg_current_xact_id());' || E'\n'
    || anchor || E'\n'
    || '  delete from trainer_private.guided_workout_start_contexts where template_id=template;');
end;
$migration$;

-- No aparece una variante pública del constructor sin guarda ni un contexto
-- que el cliente pueda fijar con set_config, JWT, metadatos o un recibo antiguo.
revoke all on function trainer_private.start_workout_execution(uuid) from public,anon,authenticated,service_role;
commit;
