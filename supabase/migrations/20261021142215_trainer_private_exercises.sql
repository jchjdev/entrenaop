begin;

-- Las recetas antiguas referencian la fila inmutable, nunca la última edición.
alter table public.exercises drop constraint exercises_origin_check;
alter table public.exercises drop constraint exercises_origin_owner_check;
alter table public.exercises add constraint exercises_origin_check check(origin in ('system','user','coach'));
alter table public.exercises add constraint exercises_origin_owner_check check(
 (origin='system' and created_by is null) or (origin in ('user','coach') and created_by is not null));
alter table public.exercises add constraint trainer_exercise_private check(origin<>'coach' or not is_public);

create table trainer_private.exercise_limits (
 trainer_id uuid primary key references public.profiles(id) on delete cascade,
 exercise_limit integer not null default 500 check(exercise_limit>=0),
 image_limit integer not null default 1000 check(image_limit>=0),
 exercise_used integer not null default 0 check(exercise_used>=0),
 image_used integer not null default 0 check(image_used>=0)
);
create table trainer_private.exercise_versions (
 exercise_id uuid primary key references public.exercises(id) on delete cascade,
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 family_id uuid not null,
 version integer not null check(version>0),
 previous_id uuid references public.exercises(id) on delete restrict,
 current boolean not null default true,
 operation_id uuid not null,
 payload jsonb not null,
 unique(trainer_id,operation_id), unique(family_id,version)
);
create unique index trainer_exercise_current on trainer_private.exercise_versions(family_id) where current;
create index trainer_exercise_owner on trainer_private.exercise_versions(trainer_id,exercise_id);
create index trainer_exercise_previous on trainer_private.exercise_versions(previous_id);
create table trainer_private.exercise_images (
 id uuid primary key,
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 path text not null unique,
 created_at timestamptz not null default now()
);
create index trainer_exercise_image_owner on trainer_private.exercise_images(trainer_id);
alter table trainer_private.exercise_limits enable row level security;
alter table trainer_private.exercise_versions enable row level security;
alter table trainer_private.exercise_images enable row level security;
revoke all on trainer_private.exercise_limits,trainer_private.exercise_versions,trainer_private.exercise_images from public,anon,authenticated;

create function trainer_private.can_read_exercise(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (
  exists(select 1 from public.exercises e where e.id=p_id and e.created_by=auth.uid() and trainer_private.has_trainer_mfa())
  or exists(select 1 from public.workout_items i join public.workout_blocks b on b.id=i.block_id
    join public.workout_templates t on t.id=b.template_id
    where i.exercise_id=p_id and t.origin='coach' and trainer_private.can_read_coach_template(t.id))
  or exists(select 1 from public.workout_execution_sets s join public.workout_executions e on e.id=s.execution_id
    where s.exercise_id=p_id and e.user_id=auth.uid())
 );
$$;
revoke all on function trainer_private.can_read_exercise(uuid) from public,anon,authenticated;
grant execute on function trainer_private.can_read_exercise(uuid) to authenticated;
create policy trainer_exercise_read on public.exercises for select to authenticated
 using(origin='coach' and trainer_private.can_read_exercise(id));
create policy trainer_exercise_read_boundary on public.exercises as restrictive for select to authenticated
 using(origin<>'coach' or trainer_private.can_read_exercise(id));
create policy trainer_exercise_insert_boundary on public.exercises as restrictive for insert to authenticated with check(origin<>'coach');
create policy trainer_exercise_update_boundary on public.exercises as restrictive for update to authenticated
 using(origin<>'coach') with check(origin<>'coach');
create policy trainer_exercise_delete_boundary on public.exercises as restrictive for delete to authenticated using(origin<>'coach');

create function trainer_private.guard_exercise_reference() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.exercises e where e.id=new.exercise_id and e.origin='coach'
  and not exists(select 1 from public.workout_blocks b join public.workout_templates t on t.id=b.template_id
   where b.id=new.block_id and t.origin='coach' and t.owner_user_id=e.created_by)) then
  raise exception 'Un ejercicio profesional solo puede formar parte de sesiones de su preparador.' using errcode='42501';
 end if;
 return new;
end $$;
revoke all on function trainer_private.guard_exercise_reference() from public,anon,authenticated;
create trigger trainer_exercise_reference before insert or update on public.workout_items
 for each row execute function trainer_private.guard_exercise_reference();

create function trainer_private.reserve_exercise_image(p_id uuid) returns text
language plpgsql security definer set search_path='' as $$
declare result text;
begin
 perform trainer_private.require_authoring_access();
 if p_id is null then raise invalid_parameter_value; end if;
 select path into result from trainer_private.exercise_images where id=p_id and trainer_id=auth.uid();
 if found then return result; end if;
 insert into trainer_private.exercise_limits(trainer_id) values(auth.uid()) on conflict do nothing;
 -- El contador condicionado es atómico también con aceptaciones simultáneas.
 update trainer_private.exercise_limits set image_used=image_used+1
  where trainer_id=auth.uid() and image_used<image_limit;
 if not found then raise exception 'Has alcanzado el límite de imágenes profesionales.' using errcode='22023'; end if;
 result:=auth.uid()::text||'/'||p_id::text||'.jpg';
 insert into trainer_private.exercise_images(id,trainer_id,path) values(p_id,auth.uid(),result);
 return result;
end $$;

create function trainer_private.can_upload_exercise_image(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select trainer_private.has_trainer_mfa() and exists(
  select 1 from trainer_private.exercise_images i join public.trainer_access a on a.trainer_id=i.trainer_id
  where i.path=p_path and i.trainer_id=auth.uid() and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()));
$$;
create function trainer_private.can_read_exercise_image(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select (trainer_private.has_trainer_mfa() and exists(select 1 from trainer_private.exercise_images
   where path=p_path and trainer_id=auth.uid()))
 or exists(select 1 from public.exercises e where e.origin='coach' and e.image_path=p_path and trainer_private.can_read_exercise(e.id));
$$;
revoke all on function trainer_private.can_upload_exercise_image(text),trainer_private.can_read_exercise_image(text) from public,anon,authenticated;
grant execute on function trainer_private.can_upload_exercise_image(text),trainer_private.can_read_exercise_image(text) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('trainer-exercise-images','trainer-exercise-images',false,512000,array['image/jpeg']);
create policy trainer_exercise_image_insert on storage.objects for insert to authenticated
 with check(bucket_id='trainer-exercise-images' and trainer_private.can_upload_exercise_image(name));
create policy trainer_exercise_image_read on storage.objects for select to authenticated
 using(bucket_id='trainer-exercise-images' and trainer_private.can_read_exercise_image(name));
-- Sin UPDATE/DELETE: una foto recibida no puede sustituirse bajo la misma ruta.

create function trainer_private.save_exercise(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare old trainer_private.exercise_versions; prior trainer_private.exercise_versions;
 normalized record; result uuid:=gen_random_uuid(); image_path text:=p_payload->>'image_path';
begin
 perform trainer_private.require_authoring_access();
 if p_operation_id is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise invalid_parameter_value; end if;
 select * into prior from trainer_private.exercise_versions where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from p_payload or prior.previous_id is distinct from p_previous_id then
   raise exception 'El reintento no coincide con el ejercicio original.' using errcode='22023'; end if;
  return prior.exercise_id;
 end if;
 if p_previous_id is not null then
  select * into old from trainer_private.exercise_versions where exercise_id=p_previous_id and trainer_id=auth.uid() and current for update;
  if not found then raise exception 'El ejercicio cambió. Recarga antes de revisarlo.' using errcode='40001'; end if;
 end if;
 select * into normalized from public.normalize_exercise_draft(p_payload->>'name',p_payload->>'description',p_payload->>'video_url',
  array(select jsonb_array_elements_text(p_payload->'muscle_groups')),
  array(select jsonb_array_elements_text(p_payload->'equipment')),p_payload->>'difficulty',p_payload->>'exercise_type');
 if image_path is not null and not exists(
  select 1 from trainer_private.exercise_images i join storage.objects o on o.name=i.path and o.bucket_id='trainer-exercise-images'
  where i.path=image_path and i.trainer_id=auth.uid()) then
  raise exception 'Sube primero una imagen profesional propia.' using errcode='22023'; end if;
 insert into trainer_private.exercise_limits(trainer_id) values(auth.uid()) on conflict do nothing;
 update trainer_private.exercise_limits set exercise_used=exercise_used+1 where trainer_id=auth.uid() and exercise_used<exercise_limit;
 if not found then raise exception 'Has alcanzado el límite de ejercicios y versiones profesionales.' using errcode='22023'; end if;
 insert into public.exercises(id,name,description,video_url,muscle_groups,equipment,difficulty,exercise_type,is_public,created_by,origin,image_path)
 values(result,normalized.normalized_name,normalized.normalized_description,normalized.normalized_video_url,
  normalized.normalized_muscle_groups,normalized.normalized_equipment,normalized.normalized_difficulty,
  normalized.normalized_exercise_type,false,auth.uid(),'coach',image_path);
 if p_previous_id is not null then update trainer_private.exercise_versions set current=false where exercise_id=p_previous_id; end if;
 insert into trainer_private.exercise_versions(exercise_id,trainer_id,family_id,version,previous_id,operation_id,payload)
 values(result,auth.uid(),coalesce(old.family_id,result),coalesce(old.version,0)+1,p_previous_id,p_operation_id,p_payload);
 return result;
end $$;

create function trainer_private.list_exercises() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 return (select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('version',v.version,'current',v.current) order by lower(e.name),e.id),'[]')
  from trainer_private.exercise_versions v join public.exercises e on e.id=v.exercise_id where v.trainer_id=auth.uid());
end $$;
create function trainer_private.exercise_usage() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 return coalesce((select to_jsonb(l)-'trainer_id' from trainer_private.exercise_limits l where trainer_id=auth.uid()),
  '{"exercise_limit":500,"image_limit":1000,"exercise_used":0,"image_used":0}'::jsonb);
end $$;

-- Cierra la copia del ejercicio privado a recetas personales u oficiales,
-- incluso si la misma identidad también dispone de ADMIN.
do $migration$
declare definition text; anchor text:=E'where exercise.id = v_exercise_id\n';
begin
 definition:=pg_get_functiondef('public.create_personal_strength_workout_template(jsonb)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar el constructor de fuerza antes de migrar.'; end if;
 definition:=replace(definition,anchor,anchor||E'          and (exercise.origin <> ''coach'' or (exercise.created_by = current_user_id\n            and current_setting(''entrenaop.creating_coach_template'',true) = ''true''))\n');
 execute definition;
 definition:=pg_get_functiondef('trainer_private.save_trainer_workout(uuid,jsonb,uuid)'::regprocedure);
 anchor:='where b.template_id=result and not e.is_public';
 if strpos(definition,anchor)=0 then raise exception 'Revisar el constructor profesional antes de migrar.'; end if;
 definition:=replace(definition,anchor,anchor||' and not (e.origin=''coach'' and e.created_by=auth.uid())');
 definition:=replace(definition,'Selecciona ejercicios del catálogo público.','Selecciona ejercicios públicos o de tu biblioteca profesional.');
 execute definition;
end $migration$;

create function public.reserve_trainer_exercise_image(p_id uuid) returns text language sql security invoker set search_path='' as $$select trainer_private.reserve_exercise_image(p_id)$$;
create function public.save_trainer_exercise(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null) returns uuid language sql security invoker set search_path='' as $$select trainer_private.save_exercise(p_operation_id,p_payload,p_previous_id)$$;
create function public.list_trainer_exercises() returns jsonb language sql security invoker set search_path='' as $$select trainer_private.list_exercises()$$;
create function public.get_trainer_exercise_usage() returns jsonb language sql security invoker set search_path='' as $$select trainer_private.exercise_usage()$$;
revoke all on function trainer_private.reserve_exercise_image(uuid),trainer_private.save_exercise(uuid,jsonb,uuid),trainer_private.list_exercises(),trainer_private.exercise_usage(),public.reserve_trainer_exercise_image(uuid),public.save_trainer_exercise(uuid,jsonb,uuid),public.list_trainer_exercises(),public.get_trainer_exercise_usage() from public,anon,authenticated;
grant execute on function trainer_private.reserve_exercise_image(uuid),trainer_private.save_exercise(uuid,jsonb,uuid),trainer_private.list_exercises(),trainer_private.exercise_usage(),public.reserve_trainer_exercise_image(uuid),public.save_trainer_exercise(uuid,jsonb,uuid),public.list_trainer_exercises(),public.get_trainer_exercise_usage() to authenticated;
commit;
