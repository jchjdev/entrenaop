-- Metadatos deportivos versionados; biblioteca y baremos conservan su identidad.
begin;

create function public.valid_strength_tag_list(p_value jsonb, p_required boolean, p_allowed text[] default null)
returns boolean language plpgsql immutable set search_path = ''
as $$
declare v_count integer; v_distinct integer;
begin
  if jsonb_typeof(p_value) is distinct from 'array' then return false; end if;
  if p_required and jsonb_array_length(p_value)=0 then return false; end if;
  if exists(select 1 from jsonb_array_elements(p_value) x
    where jsonb_typeof(x) <> 'string' or (x#>>'{}') !~ '^[a-z][a-z0-9_]{1,63}$'
      or (p_allowed is not null and not (x#>>'{}')=any(p_allowed))) then return false; end if;
  select count(*),count(distinct x) into v_count,v_distinct from jsonb_array_elements(p_value) x;
  return v_count=v_distinct;
end $$;

create function public.valid_strength_exercise_definition(p_definition jsonb)
returns boolean language plpgsql immutable set search_path = ''
as $$
declare v_key text; v_option jsonb; v_mode text; v_modes text[] := '{}';
begin
  if jsonb_typeof(p_definition) is distinct from 'object' then return false; end if;
  if exists(select 1 from jsonb_object_keys(p_definition) k where k <> all(array[
    'code','name','family','movement_patterns','movement_modes','body_regions',
    'laterality','technical_level','required_equipment','optional_equipment',
    'primary_muscles','secondary_muscles','measurement_options','progression_axes','notes'])) then return false; end if;
  foreach v_key in array array['code','name','family','laterality','technical_level','notes'] loop
    if jsonb_typeof(p_definition->v_key) is distinct from 'string'
      or length(btrim(p_definition->>v_key))=0
      or btrim(p_definition->>v_key) is distinct from p_definition->>v_key then return false; end if;
  end loop;
  if (p_definition->>'code') !~ '^[a-z][a-z0-9_]{1,63}$'
    or (p_definition->>'family') !~ '^[a-z][a-z0-9_]{1,63}$'
    or (p_definition->>'laterality') not in ('bilateral','unilateral','alternating')
    or (p_definition->>'technical_level') not in ('initial','intermediate','advanced') then return false; end if;
  if not public.valid_strength_tag_list(p_definition->'movement_patterns',true,array[
    'horizontal_push','diagonal_push','vertical_push','vertical_pull','horizontal_pull',
    'squat','hinge','hip_extension','unilateral_knee_dominant','carry','rope_climb',
    'grip_hold','knee_flexion','plantar_flexion','core_anti_extension','core_anti_rotation',
    'core_lateral','plyometric_vertical','plyometric_horizontal','plyometric_lateral',
    'change_of_direction','reactive_agility','ballistic_throw'])
    or not public.valid_strength_tag_list(p_definition->'movement_modes',true,
      array['dynamic','isometric','plyometric','locomotor'])
    or not public.valid_strength_tag_list(p_definition->'body_regions',true,
      array['upper_body','lower_body','trunk'])
    or not public.valid_strength_tag_list(p_definition->'progression_axes',true,array[
      'load','reps','sets','duration','assistance','distance','density','rest',
      'velocity','contact_time','box_height','complexity','rom','lever','specificity','technique']) then return false; end if;
  foreach v_key in array array['required_equipment','optional_equipment','primary_muscles','secondary_muscles'] loop
    if not public.valid_strength_tag_list(p_definition->v_key,v_key='primary_muscles') then return false; end if;
  end loop;
  if exists(select 1 from jsonb_array_elements_text(p_definition->'required_equipment') x
      where (p_definition->'optional_equipment') ? x)
    or exists(select 1 from jsonb_array_elements_text(p_definition->'primary_muscles') x
      where (p_definition->'secondary_muscles') ? x) then return false; end if;
  if jsonb_typeof(p_definition->'measurement_options') is distinct from 'array'
    or jsonb_array_length(p_definition->'measurement_options')=0 then return false; end if;
  for v_option in select value from jsonb_array_elements(p_definition->'measurement_options') loop
    if jsonb_typeof(v_option) <> 'object' or jsonb_typeof(v_option->'mode') is distinct from 'string'
      or exists(select 1 from jsonb_object_keys(v_option) k where k not in ('mode','load_modes')) then return false; end if;
    v_mode:=v_option->>'mode';
    if v_mode not in ('REPS','LOAD_REPS','DURATION','REPS_IN_TIME','MAX_LOAD',
      'TIME_FOR_DISTANCE','TIME_FOR_COURSE','DISTANCE','HEIGHT','PASS_FAIL','REACTIVE_METRICS')
      or v_mode=any(v_modes)
      or not public.valid_strength_tag_list(v_option->'load_modes',true,
        array['bodyweight','external_load','bodyweight_plus_external','assisted']) then return false; end if;
    if v_mode in ('LOAD_REPS','MAX_LOAD') and exists(
      select 1 from jsonb_array_elements_text(v_option->'load_modes') x
      where x not in ('external_load','bodyweight_plus_external')) then return false; end if;
    v_modes:=array_append(v_modes,v_mode);
  end loop;
  return true;
end $$;

create table public.exercise_training_profiles (
  code text not null,
  definition_version integer not null,
  catalog_version integer not null,
  definition jsonb not null,
  created_at timestamptz not null default now(),
  primary key (code,definition_version),
  constraint training_profile_version_check check (definition_version>0 and catalog_version>0),
  constraint training_profile_code_check check (code=definition->>'code'),
  constraint training_profile_definition_check check (public.valid_strength_exercise_definition(definition))
);

create function public.guard_immutable_training_profile()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'Los metadatos deportivos son inmutables; crea otra versión.'
    using errcode='22023';
end $$;

create trigger immutable_training_profile before update or delete on public.exercise_training_profiles
for each row execute function public.guard_immutable_training_profile();

alter table public.exercises
  add column training_profile_code text,
  add column training_profile_version integer,
  add constraint exercise_training_profile_fk foreign key(training_profile_code,training_profile_version)
    references public.exercise_training_profiles(code,definition_version) on delete restrict,
  add constraint exercise_training_profile_pair_check check (
    (training_profile_code is null and training_profile_version is null)
    or (training_profile_code is not null and training_profile_version is not null
      and origin='system' and created_by is null)
  );

create index exercises_training_profile_idx on public.exercises(training_profile_code,training_profile_version);

alter table public.exercise_training_profiles enable row level security;
revoke all on public.exercise_training_profiles from public,anon,authenticated;
grant select on public.exercise_training_profiles to authenticated;
create policy exercise_training_profiles_read on public.exercise_training_profiles
for select to authenticated using ((select public.is_admin()) or exists(
  select 1 from public.exercises e where e.training_profile_code=code
    and e.training_profile_version=definition_version and e.origin='system' and e.is_public
));

create function public.set_admin_exercise_training_profile(p_exercise_id uuid,p_code text,p_version integer)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede vincular metadatos.' using errcode='42501';
  end if;
  if (p_code is null) <> (p_version is null) then
    raise exception 'Indica código y versión juntos.' using errcode='22023';
  end if;
  if p_code is not null and not exists(select 1 from public.exercise_training_profiles
    where code=p_code and definition_version=p_version) then
    raise exception 'Perfil deportivo no disponible.' using errcode='22023';
  end if;
  update public.exercises set training_profile_code=p_code,training_profile_version=p_version
    where id=p_exercise_id and origin='system' and created_by is null;
  if not found then raise exception 'Ejercicio oficial no disponible.' using errcode='22023'; end if;
end $$;

create table public.program_test_training_bindings (
  test_id uuid primary key,
  program_id text not null,
  profile_code text not null,
  profile_version integer not null,
  measurement_mode text not null,
  review_note text not null,
  created_at timestamptz not null default now(),
  constraint training_binding_test_fk foreign key(test_id,program_id)
    references public.program_assessment_tests(id,program_id) on delete cascade,
  constraint training_binding_profile_fk foreign key(profile_code,profile_version)
    references public.exercise_training_profiles(code,definition_version) on delete restrict,
  constraint training_binding_review_check check (char_length(btrim(review_note)) between 10 and 2000)
);

create function public.validate_program_test_training_binding()
returns trigger language plpgsql set search_path = ''
as $$
declare v_test public.program_assessment_tests%rowtype; v_definition jsonb;
begin
  select * into v_test from public.program_assessment_tests where id=new.test_id;
  select definition into v_definition from public.exercise_training_profiles
    where code=new.profile_code and definition_version=new.profile_version;
  if v_definition is null or not exists(
    select 1 from jsonb_array_elements(v_definition->'measurement_options') o
    where o->>'mode'=new.measurement_mode) then
    raise exception 'La variante no admite esa medición.' using errcode='22023';
  end if;
  if not (
    (new.measurement_mode in ('REPS','REPS_IN_TIME') and v_test.unit='repetitions' and v_test.better_direction='higher')
    or (new.measurement_mode='DURATION' and v_test.unit='seconds' and v_test.better_direction='higher')
    or (new.measurement_mode in ('TIME_FOR_DISTANCE','TIME_FOR_COURSE') and v_test.unit='seconds' and v_test.better_direction='lower')
    or (new.measurement_mode in ('DISTANCE','HEIGHT') and v_test.unit='meters' and v_test.better_direction='higher')
  ) then raise exception 'Unidad o dirección incompatible con la medición.' using errcode='22023'; end if;
  return new;
end $$;

create trigger guard_published_training_binding before insert or update or delete
on public.program_test_training_bindings for each row
execute function public.guard_published_program_assessment_content();
create trigger validate_training_binding before insert or update
on public.program_test_training_bindings for each row
execute function public.validate_program_test_training_binding();

-- Un cambio del protocolo borrador retira el enlace para exigir nueva revisión.
create function public.invalidate_changed_training_binding()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if (old.unit,old.better_direction,old.protocol_notes,old.category,old.mark_step,
      old.definition_version,old.distance_meters,old.measurement_protocol)
    is distinct from
     (new.unit,new.better_direction,new.protocol_notes,new.category,new.mark_step,
      new.definition_version,new.distance_meters,new.measurement_protocol) then
    delete from public.program_test_training_bindings where test_id=old.id;
  end if;
  return new;
end $$;
create trigger invalidate_changed_training_binding before update on public.program_assessment_tests
for each row execute function public.invalidate_changed_training_binding();

alter table public.program_test_training_bindings enable row level security;
revoke all on public.program_test_training_bindings from public,anon,authenticated;
grant select on public.program_test_training_bindings to authenticated;
create policy program_test_training_bindings_read on public.program_test_training_bindings
for select to authenticated using ((select public.is_admin()) or exists(
  select 1 from public.preparation_programs p where p.id=program_id and p.enabled));

create function public.set_admin_program_test_training_binding(
  p_test_id uuid,p_code text,p_version integer,p_measurement text,p_review_note text
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_program text;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede vincular pruebas.' using errcode='42501';
  end if;
  select t.program_id into v_program from public.program_assessment_tests t
    join public.preparation_programs p on p.id=t.program_id
    where t.id=p_test_id and not p.enabled for update of t,p;
  if not found then raise exception 'Prueba borrador no disponible.' using errcode='22023'; end if;
  if p_code is null then delete from public.program_test_training_bindings where test_id=p_test_id; return; end if;
  if p_version is null or p_measurement is null or p_review_note is null then
    raise exception 'Indica versión, medición y revisión.' using errcode='22023';
  end if;
  insert into public.program_test_training_bindings(
    test_id,program_id,profile_code,profile_version,measurement_mode,review_note
  ) values(p_test_id,v_program,p_code,p_version,p_measurement,btrim(p_review_note))
  on conflict(test_id) do update set profile_code=excluded.profile_code,
    profile_version=excluded.profile_version,measurement_mode=excluded.measurement_mode,
    review_note=excluded.review_note;
end $$;

-- La copia conserva los enlaces del mismo protocolo, sin trasladar resultados.
create or replace function public.clone_admin_program_assessment_version_v2(
  p_source_program_id text,p_name text,p_scoring_version text
) returns text language plpgsql security definer set search_path = ''
as $$
declare v_new_program text;
begin
  v_new_program:=public.clone_admin_program_assessment_version(p_source_program_id,p_name,p_scoring_version);
  update public.program_assessment_tests n set distance_meters=o.distance_meters,
    measurement_protocol=o.measurement_protocol from public.program_assessment_tests o
    where o.program_id=p_source_program_id and n.program_id=v_new_program
      and n.code=o.code and n.category=o.category;
  insert into public.program_training_modules(test_id,program_id,module_key)
    select n.id,v_new_program,m.module_key from public.program_training_modules m
    join public.program_assessment_tests o on o.id=m.test_id
    join public.program_assessment_tests n on n.program_id=v_new_program and n.code=o.code and n.category=o.category
    where m.program_id=p_source_program_id;
  insert into public.program_test_training_bindings(
    test_id,program_id,profile_code,profile_version,measurement_mode,review_note)
    select n.id,v_new_program,b.profile_code,b.profile_version,b.measurement_mode,b.review_note
    from public.program_test_training_bindings b
    join public.program_assessment_tests o on o.id=b.test_id
    join public.program_assessment_tests n on n.program_id=v_new_program and n.code=o.code and n.category=o.category
    where b.program_id=p_source_program_id;
  return v_new_program;
end $$;

revoke all on function public.valid_strength_tag_list(jsonb,boolean,text[]) from public,anon;
revoke all on function public.valid_strength_exercise_definition(jsonb) from public,anon;
grant execute on function public.valid_strength_tag_list(jsonb,boolean,text[]) to authenticated;
grant execute on function public.valid_strength_exercise_definition(jsonb) to authenticated;
revoke all on function public.guard_immutable_training_profile() from public,anon,authenticated;
revoke all on function public.validate_program_test_training_binding() from public,anon,authenticated;
revoke all on function public.invalidate_changed_training_binding() from public,anon,authenticated;
revoke all on function public.set_admin_exercise_training_profile(uuid,text,integer) from public,anon;
grant execute on function public.set_admin_exercise_training_profile(uuid,text,integer) to authenticated;
revoke all on function public.set_admin_program_test_training_binding(uuid,text,integer,text,text) from public,anon;
grant execute on function public.set_admin_program_test_training_binding(uuid,text,integer,text,text) to authenticated;

commit;
