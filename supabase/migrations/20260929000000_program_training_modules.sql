-- Una medición deportiva puede alimentar un módulo de entrenamiento sin
-- convertir su baremo en una regla de prescripción. La asociación se publica
-- junto al programa y permanece inmutable tras publicar.
begin;

alter table public.program_assessment_tests
  add column distance_meters integer,
  add column measurement_protocol text,
  add constraint program_test_distance_check check (
    distance_meters is null or (
      distance_meters between 1 and 100000
      and unit = 'seconds' and better_direction = 'lower'
    )
  ),
  add constraint program_test_id_program_unique unique (id, program_id),
  add constraint program_test_measurement_protocol_check check (
    measurement_protocol is null or (
      measurement_protocol = 'run_2000m_v1'
      and distance_meters = 2000
      and unit = 'seconds' and better_direction = 'lower'
    )
  );

create table public.program_training_modules (
  test_id uuid primary key,
  program_id text not null,
  module_key text not null,
  created_at timestamptz not null default now(),
  constraint program_training_module_program_fk
    foreign key (program_id)
    references public.preparation_programs (id)
    on delete cascade,
  constraint program_training_module_test_fk
    foreign key (test_id, program_id)
    references public.program_assessment_tests (id, program_id)
    on delete cascade,
  constraint program_training_module_key_check
    check (module_key = 'running_2000m_v1')
);

create index program_training_modules_program_idx
on public.program_training_modules (program_id);

alter table public.program_training_modules enable row level security;
revoke all on public.program_training_modules from public, anon, authenticated;
grant select on public.program_training_modules to authenticated;
create policy program_training_modules_read
on public.program_training_modules for select to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.preparation_programs p
  where p.id = program_id and p.enabled
));

create trigger guard_published_training_module
before insert or update or delete on public.program_training_modules
for each row execute function public.guard_published_program_assessment_content();

create function public.create_admin_program_assessment_test_v5(
  p_program_id text, p_code text, p_name text, p_unit text,
  p_better_direction text, p_protocol_notes text, p_category text,
  p_group_code text, p_display_order integer, p_mark_step numeric,
  p_min_age integer, p_max_age integer, p_max_attempts integer,
  p_retry_policy text, p_distance_meters integer,
  p_measurement_protocol text
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  v_id := public.create_admin_program_assessment_test_v4(
    p_program_id,p_code,p_name,p_unit,p_better_direction,p_protocol_notes,
    p_category,p_group_code,p_display_order,p_mark_step,p_min_age,p_max_age,
    p_max_attempts,p_retry_policy);
  update public.program_assessment_tests
  set distance_meters = p_distance_meters,
      measurement_protocol = p_measurement_protocol where id = v_id;
  return v_id;
end;
$$;

create function public.update_admin_program_assessment_test_v5(
  p_test_id uuid, p_name text, p_unit text, p_better_direction text,
  p_protocol_notes text, p_category text, p_display_order integer,
  p_mark_step numeric, p_min_age integer, p_max_age integer,
  p_reset_bands boolean, p_max_attempts integer, p_retry_policy text,
  p_distance_meters integer, p_measurement_protocol text
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_test public.program_assessment_tests%rowtype;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede editar pruebas.'
      using errcode = '42501';
  end if;
  select t.* into v_test from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = p_test_id and not p.enabled for update of t;
  if not found then
    raise exception 'La prueba debe pertenecer a un borrador.'
      using errcode = '22023';
  end if;
  if exists (select 1 from public.program_training_modules
      where test_id = p_test_id) and
     (v_test.unit,v_test.better_direction,v_test.distance_meters,
      v_test.measurement_protocol)
       is distinct from (p_unit,p_better_direction,p_distance_meters,
                         p_measurement_protocol) then
    raise exception 'Desvincula el módulo antes de cambiar su medición.'
      using errcode = '22023';
  end if;
  -- La función v4 cambia la unidad antes de que podamos fijar la distancia.
  -- Limpiar temporalmente el dato evita una violación intermedia del CHECK.
  if p_unit <> 'seconds' or p_better_direction <> 'lower' then
    update public.program_assessment_tests
    set distance_meters = null, measurement_protocol = null
    where id = p_test_id;
  elsif v_test.measurement_protocol is not null and
        (v_test.distance_meters is distinct from p_distance_meters or
         v_test.measurement_protocol is distinct from p_measurement_protocol) then
    update public.program_assessment_tests
    set measurement_protocol = null where id = p_test_id;
  end if;
  perform public.update_admin_program_assessment_test_v4(
    p_test_id,p_name,p_unit,p_better_direction,p_protocol_notes,p_category,
    p_display_order,p_mark_step,p_min_age,p_max_age,p_reset_bands,
    p_max_attempts,p_retry_policy);
  update public.program_assessment_tests
  set distance_meters = p_distance_meters,
      measurement_protocol = p_measurement_protocol where id = p_test_id;
end;
$$;

create function public.set_admin_program_training_module(
  p_test_id uuid, p_module_key text
) returns void language plpgsql security definer set search_path = ''
as $$
declare v_test public.program_assessment_tests%rowtype;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede asignar módulos.'
      using errcode = '42501';
  end if;
  select t.* into v_test from public.program_assessment_tests t
  join public.preparation_programs p on p.id = t.program_id
  where t.id = p_test_id and not p.enabled for update of t;
  if not found then
    raise exception 'La prueba debe pertenecer a un borrador.'
      using errcode = '22023';
  end if;
  if p_module_key is null then
    delete from public.program_training_modules where test_id = p_test_id;
    return;
  end if;
  if p_module_key <> 'running_2000m_v1' or
     v_test.unit <> 'seconds' or
     v_test.better_direction <> 'lower' or
     v_test.distance_meters is distinct from 2000 or
     v_test.measurement_protocol is distinct from 'run_2000m_v1' then
    raise exception 'El módulo de 2 km exige una prueba cronometrada de 2.000 m.'
      using errcode = '22023';
  end if;
  insert into public.program_training_modules (test_id, program_id, module_key)
  values (v_test.id, v_test.program_id, p_module_key)
  on conflict (test_id) do update set module_key = excluded.module_key;
end;
$$;

create function public.clone_admin_program_assessment_version_v2(
  p_source_program_id text, p_name text, p_scoring_version text
) returns text language plpgsql security definer set search_path = ''
as $$
declare v_new_program text;
begin
  v_new_program := public.clone_admin_program_assessment_version(
    p_source_program_id,p_name,p_scoring_version);
  update public.program_assessment_tests as new_test
  set distance_meters = old_test.distance_meters,
      measurement_protocol = old_test.measurement_protocol
  from public.program_assessment_tests as old_test
  where old_test.program_id = p_source_program_id
    and new_test.program_id = v_new_program
    and new_test.code = old_test.code
    and new_test.category = old_test.category;
  insert into public.program_training_modules (test_id,program_id,module_key)
  select new_test.id,v_new_program,old_module.module_key
  from public.program_training_modules old_module
  join public.program_assessment_tests old_test
    on old_test.id = old_module.test_id
  join public.program_assessment_tests new_test
    on new_test.program_id = v_new_program
   and new_test.code = old_test.code
   and new_test.category = old_test.category
  where old_module.program_id = p_source_program_id;
  return v_new_program;
end;
$$;

revoke all on function public.create_admin_program_assessment_test_v5(
  text,text,text,text,text,text,text,text,integer,numeric,integer,integer,
  integer,text,integer,text) from public,anon;
grant execute on function public.create_admin_program_assessment_test_v5(
  text,text,text,text,text,text,text,text,integer,numeric,integer,integer,
  integer,text,integer,text) to authenticated;
revoke all on function public.update_admin_program_assessment_test_v5(
  uuid,text,text,text,text,text,integer,numeric,integer,integer,boolean,
  integer,text,integer,text) from public,anon;
grant execute on function public.update_admin_program_assessment_test_v5(
  uuid,text,text,text,text,text,integer,numeric,integer,integer,boolean,
  integer,text,integer,text) to authenticated;
revoke all on function public.set_admin_program_training_module(uuid,text)
  from public,anon;
grant execute on function public.set_admin_program_training_module(uuid,text)
  to authenticated;
revoke all on function public.clone_admin_program_assessment_version_v2(
  text,text,text) from public,anon;
grant execute on function public.clone_admin_program_assessment_version_v2(
  text,text,text) to authenticated;

commit;
