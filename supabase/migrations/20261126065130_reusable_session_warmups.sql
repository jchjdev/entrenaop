begin;

alter table public.workout_templates
  add column is_private_warmup boolean not null default false,
  add column warmup_template_id uuid,
  add column warmup_name text,
  add column warmup_can_be_skipped boolean not null default true,
  add constraint workout_template_warmup_shape check (
    (warmup_template_id is null and warmup_name is null and warmup_can_be_skipped)
    or (warmup_template_id is not null and warmup_name is not null and not is_private_warmup)
  );
alter table public.workout_blocks
  add column attached_warmup boolean not null default false,
  add constraint workout_block_attached_warmup_format check (not attached_warmup or format = 'warm_up');
alter table public.workout_execution_sets
  add column warmup_can_be_skipped boolean not null default true;

create index trainer_private_warmup_library on public.workout_templates (owner_user_id, name, id)
where origin = 'coach' and is_private_warmup and status = 'published' and trashed_at is null;

-- La versión de sesión recibe una copia de la prescripción. El identificador
-- de la biblioteca solo sirve para reeditar el selector de la sesión.
create function workout_private.attach_session_warmup(
  p_template public.workout_templates, p_source_id uuid, p_can_skip boolean
) returns void language plpgsql set search_path = '' as $$
declare
  source public.workout_templates;
  source_name text;
  block public.workout_blocks;
  item public.workout_items;
  new_block uuid;
  new_item uuid;
  block_count integer;
  position integer := 0;
begin
  select * into source from public.workout_templates t
  where t.id = p_source_id and t.status in ('published', 'archived') and t.trashed_at is null
  for share;
  if source.origin = 'coach' and p_template.origin = 'coach'
     and source.is_private_warmup and source.owner_user_id = auth.uid() then
    source_name := source.name;
  elsif source.origin = 'system' then
    select w.name into source_name from public.guided_warmups w
    where w.template_id = source.id and w.status = 'published';
  end if;
  if source_name is null or p_template.origin not in ('coach', 'system') then
    raise exception 'El calentamiento no está disponible.' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.workout_blocks b
    join public.workout_items i on i.block_id = b.id
    join public.exercises e on e.id = i.exercise_id
    where b.template_id = source.id and (
      e.trashed_at is not null
      or not ((e.origin = 'system' and e.is_public)
        or (p_template.origin = 'coach' and e.origin = 'coach' and e.created_by = auth.uid()))
    )
  ) then raise exception 'El calentamiento contiene ejercicios que ya no se pueden usar.' using errcode = '22023'; end if;
  select count(*) into block_count from public.workout_blocks b where b.template_id = source.id;
  if block_count = 0 or exists (
    select 1 from public.workout_blocks b where b.template_id = source.id and b.format <> 'warm_up'
  ) or exists (
    select 1 from public.workout_blocks b where b.template_id = p_template.id and b.format = 'warm_up'
  ) then raise invalid_parameter_value; end if;

  for block in select * from public.workout_blocks b where b.template_id = p_template.id
    order by b.order_index desc loop
    update public.workout_blocks set order_index = block.order_index + block_count where id = block.id;
  end loop;
  for block in select * from public.workout_blocks b where b.template_id = source.id order by b.order_index loop
    new_block := gen_random_uuid();
    insert into public.workout_blocks select (jsonb_populate_record(null::public.workout_blocks,
      to_jsonb(block) || jsonb_build_object('id', new_block, 'template_id', p_template.id,
        'order_index', position, 'attached_warmup', true))).*;
    position := position + 1;
    for item in select * from public.workout_items i where i.block_id = block.id loop
      new_item := gen_random_uuid();
      insert into public.workout_items select (jsonb_populate_record(null::public.workout_items,
        to_jsonb(item) || jsonb_build_object('id', new_item, 'block_id', new_block))).*;
      insert into public.workout_sets select (jsonb_populate_record(null::public.workout_sets,
        to_jsonb(s) || jsonb_build_object('id', gen_random_uuid(), 'item_id', new_item))).*
      from public.workout_sets s where s.item_id = item.id;
    end loop;
  end loop;
  update public.workout_templates set warmup_template_id = source.id, warmup_name = source_name,
    warmup_can_be_skipped = p_can_skip where id = p_template.id;
end;
$$;
revoke all on function workout_private.attach_session_warmup(public.workout_templates, uuid, boolean)
from public, anon, authenticated, service_role;

create or replace function public.create_personal_workout_template(p_payload jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  result uuid;
  template public.workout_templates;
  private_warmup boolean := p_payload->'is_private_warmup' = 'true'::jsonb;
  warmup_id uuid := (p_payload->>'warmup_template_id')::uuid;
begin
  if (p_payload ? 'is_private_warmup' and jsonb_typeof(p_payload->'is_private_warmup') <> 'boolean')
    or (p_payload ? 'warmup_can_be_skipped' and jsonb_typeof(p_payload->'warmup_can_be_skipped') <> 'boolean')
    or (private_warmup and warmup_id is not null) then raise invalid_parameter_value; end if;
  if p_payload->'blocks'->0->>'format' = 'running' then
    result := public.create_personal_running_workout_template(p_payload);
  else
    result := public.create_personal_strength_workout_template(p_payload);
  end if;
  if private_warmup or warmup_id is not null then
    select * into strict template from public.workout_templates where id = result;
  end if;
  if private_warmup then
    if template.origin <> 'coach' or exists (
      select 1 from public.workout_blocks b where b.template_id = result and b.format <> 'straight_sets'
    ) then raise invalid_parameter_value; end if;
    update public.workout_blocks set format = 'warm_up' where template_id = result;
    update public.workout_templates set is_private_warmup = true where id = result;
  elsif warmup_id is not null then
    perform workout_private.attach_session_warmup(template, warmup_id,
      coalesce((p_payload->>'warmup_can_be_skipped')::boolean, true));
  end if;
  return result;
end;
$$;

-- Ajusta los contratos vigentes sin reemplazar las reglas de papelera,
-- versiones, ejercicios privados ni guardado de un borrador.
do $migration$
declare
  routine regprocedure;
  definition text;
  anchor text;
begin
  foreach routine in array array[
    'trainer_private.list_trainer_workouts(timestamptz,uuid)'::regprocedure,
    'trainer_private.search_trainer_workouts(text,boolean,text,timestamptz,uuid)'::regprocedure
  ] loop
    definition := pg_get_functiondef(routine);
    anchor := 't.owner_user_id=auth.uid()';
    if strpos(definition, anchor) = 0 then raise exception 'Revisar el alcance de %', routine; end if;
    execute replace(definition, anchor, anchor || ' and not t.is_private_warmup');
  end loop;
  definition := pg_get_functiondef('trainer_private.save_trainer_workout(uuid,jsonb,uuid)'::regprocedure);
  anchor := 'result:=public.create_personal_workout_template(p_payload);';
  if strpos(definition, anchor) = 0 then raise exception 'Revisar el guardado profesional'; end if;
  execute replace(definition, anchor, anchor || E'\n  if p_previous_id is not null and old.is_private_warmup is distinct from\n'
    || E'    coalesce((p_payload->>''is_private_warmup'')::boolean, false) then raise invalid_parameter_value; end if;');

  definition := pg_get_functiondef('trainer_private.validate_session_work_state(jsonb)'::regprocedure);
  anchor := $anchor$array['schema','running','nameText','descriptionText','durationText','segments','blocks'],'{}'$anchor$;
  if strpos(definition, anchor) = 0 then raise exception 'Revisar el borrador de sesión'; end if;
  execute replace(definition, anchor,
    $fields$array['schema','running','nameText','descriptionText','durationText','segments','blocks'],
    array['warmupTemplateId','warmupName','warmupCanBeSkipped']$fields$);
end
$migration$;

create function workout_private.require_trainable_session()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.workout_templates t where t.id = new.template_id and t.is_private_warmup)
  then raise exception 'Añade el calentamiento desde el editor de la sesión.' using errcode = '22023'; end if;
  return new;
end;
$$;
revoke all on function workout_private.require_trainable_session() from public, anon, authenticated, service_role;
create trigger scheduled_workout_requires_session before insert or update of template_id
on public.scheduled_workouts for each row execute function workout_private.require_trainable_session();
create trigger trainer_program_requires_session before insert or update of template_id
on trainer_private.program_sessions for each row execute function workout_private.require_trainable_session();

create function workout_private.snapshot_warmup_skip_policy()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and new.block_format = 'warm_up' then
    select t.warmup_can_be_skipped into new.warmup_can_be_skipped
    from public.workout_executions e join public.workout_templates t on t.id = e.template_id
    where e.id = new.execution_id;
    new.warmup_can_be_skipped := coalesce(new.warmup_can_be_skipped, true);
  elsif tg_op = 'UPDATE' and old.block_format = 'warm_up'
    and not old.warmup_can_be_skipped and old.status = 'pending' and new.status = 'skipped' then
    raise exception 'Este calentamiento es obligatorio.' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function workout_private.snapshot_warmup_skip_policy() from public, anon, authenticated, service_role;
create trigger snapshot_warmup_skip_policy before insert or update of status
on public.workout_execution_sets for each row execute function workout_private.snapshot_warmup_skip_policy();

commit;
