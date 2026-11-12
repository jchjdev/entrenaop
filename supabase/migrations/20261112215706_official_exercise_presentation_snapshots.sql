begin;

alter table public.workout_execution_sets
  add column official_exercise_image jsonb;

-- Las ejecuciones anteriores ya guardaban el texto y el vídeo. La foto
-- seguía consultándose en el catálogo y se fija con su valor actual.
alter table public.workout_execution_sets disable trigger trainer_set_revision;
update public.workout_execution_sets s
set official_exercise_image = jsonb_build_object(
  'path', e.image_path, 'thumbnail_url', case when e.image_path is null then e.thumbnail_url end
)
from public.exercises e
where e.id = s.exercise_id and e.origin = 'system';
alter table public.workout_execution_sets enable trigger trainer_set_revision;

alter function trainer_private.freeze_coach_exercise_media() rename to freeze_exercise_media;
alter trigger a0_freeze_coach_exercise_media on public.workout_execution_sets
  rename to a0_freeze_exercise_media;

create or replace function trainer_private.freeze_exercise_media() returns trigger
language plpgsql security definer set search_path = '' as $$
declare exercise public.exercises;
begin
  select e.* into exercise from public.exercises e
    where e.id = new.exercise_id and e.origin in ('coach', 'system') for share;
  if found then
    if exercise.origin = 'system' then
      -- El objeto también representa la ausencia de foto. Los clientes
      -- anteriores siguen interpretando exercise_image_path como ruta privada.
      new.official_exercise_image := jsonb_build_object('path', exercise.image_path,
        'thumbnail_url', case when exercise.image_path is null then exercise.thumbnail_url end);
    else
      new.exercise_media_frozen := true;
      new.exercise_image_path := exercise.image_path;
    end if;
    new.exercise_description := exercise.description;
    new.exercise_video_url := exercise.video_url;
  end if;
  return new;
end $$;

do $migration$
declare
  routine regprocedure;
  definition text;
  anchor text;
  replacement text;
begin
  for routine, anchor, replacement in values
    ('trainer_private.get_scheduled_workout_preview(uuid,uuid)'::regprocedure,
      'e.origin = ''coach'' and scheduled.execution_id',
      'e.origin in (''coach'', ''system'') and scheduled.execution_id'),
    ('trainer_private.get_scheduled_workout_preview(uuid,uuid)'::regprocedure,
      'and s.exercise_media_frozen',
      'and (s.exercise_media_frozen or s.official_exercise_image is not null)'),
    ('trainer_private.start_reviewed_scheduled_workout(uuid,uuid,text)'::regprocedure,
      'where e.origin = ''coach'' and e.id in (',
      'where e.origin in (''coach'', ''system'') and e.id in (')
  loop
    definition := pg_get_functiondef(routine);
    if strpos(definition, anchor) = 0 then
      raise exception 'Revisar el contrato de la ficha en %', routine;
    end if;
    execute replace(definition, anchor, replacement);
  end loop;
end
$migration$;

commit;
