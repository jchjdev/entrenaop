begin;
alter table public.program_test_training_bindings add column training_parameters jsonb not null default '{}';

create function public.set_admin_performance_strategy(p_test_id uuid,p_code text,p_version int,
 p_measurement text,p_review_note text,p_parameters jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Solo administración puede configurar estrategias.' using errcode='42501'; end if;
 if p_parameters is null or jsonb_typeof(p_parameters)<>'object' or exists(select 1 from jsonb_object_keys(p_parameters) k
   where k not in ('fixed_duration_seconds','fixed_distance_meters')) then raise exception 'Condiciones de protocolo no válidas.' using errcode='22023'; end if;
 if exists(select 1 from jsonb_each(p_parameters) x where jsonb_typeof(x.value)<>'number') then raise exception 'Las condiciones deben ser numéricas.' using errcode='22023'; end if;
 if p_measurement='REPS_IN_TIME' and coalesce((p_parameters->>'fixed_duration_seconds')::numeric,0) not between 1 and 3600 then
   raise exception 'Indica la ventana oficial en segundos.' using errcode='22023'; end if;
 if p_measurement='TIME_FOR_DISTANCE' and coalesce((p_parameters->>'fixed_distance_meters')::numeric,0) not between 0.1 and 10000 then
   raise exception 'Indica la distancia o altura de la prueba.' using errcode='22023'; end if;
 perform public.set_admin_program_test_training_binding(p_test_id,p_code,p_version,p_measurement,p_review_note);
 update public.program_test_training_bindings set training_parameters=p_parameters where test_id=p_test_id;
end $$;

create function public.get_preparation_training_setup(p_goal_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare g public.preparation_goals%rowtype; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=g.id order by a.assessed_on desc,a.created_at desc limit 1;
 return jsonb_build_object('goal_id',g.id,'target_date',g.target_date,'category',selected_category,
   'context',(select to_jsonb(c)-'user_id' from public.performance_training_contexts c where c.user_id=auth.uid()),
   'running_context',(select to_jsonb(c)-'preparation_goal_id' from public.running_intake_contexts c where c.preparation_goal_id=g.id),
   'catalog',coalesce((select jsonb_agg(jsonb_build_object('definition',ep.definition,'version',ep.definition_version) order by ep.definition->>'name')
     from public.exercise_training_profiles ep where exists(select 1 from public.exercises ex
       where ex.training_profile_code=ep.code and ex.training_profile_version=ep.definition_version and ex.is_public)),'[]'::jsonb),
   'references',coalesce((select jsonb_agg(to_jsonb(r)-'user_id' order by r.created_at) from public.performance_training_references r where r.preparation_goal_id=g.id and r.active),'[]'::jsonb),
   'objectives',coalesce((select jsonb_agg(jsonb_build_object('objective_key',t.id::text,'test_id',t.id,'name',t.name,'category',t.category,
       'profile_code',b.profile_code,'profile_version',b.profile_version,'measurement',b.measurement_mode,
       'protocol_key','program_test_'||t.id::text,'protocol_version',t.definition_version,'instructions',t.protocol_notes,
       'parameters',b.training_parameters) order by t.display_order)
     from public.program_test_training_bindings b join public.program_assessment_tests t on t.id=b.test_id
     where b.program_id=g.program_id and (selected_category is null or t.category in ('both',selected_category))),'[]'::jsonb) || coalesce((select jsonb_agg(to_jsonb(o)||jsonb_build_object('program_objective_key',o.objective_key))
       from public.performance_legacy_objectives o where o.program_id=g.program_id and
       (o.max_age_exclusive is null or coalesce((select extract(year from age(coalesce(g.target_date,current_date),fecha_nacimiento)) from public.profiles where id=auth.uid()),0)<o.max_age_exclusive)),'[]'::jsonb),
   'relations',(select jsonb_agg(to_jsonb(r)) from public.performance_exercise_relations r where policy_version='performance_v1'),
   'published_weeks',coalesce((select jsonb_agg(week_start order by week_start desc) from public.preparation_week_decisions where preparation_goal_id=g.id),'[]'::jsonb));
end $$;

-- La tarea específica conserva el protocolo del programa. La calibración del
-- apoyo tiene su propio montaje; no puede atribuirse como marca del examen.
create function public.guard_performance_reference_protocol() returns trigger
language plpgsql set search_path = '' as $$
declare binding public.program_test_training_bindings%rowtype; t public.program_assessment_tests%rowtype;
begin
 if new.test_id is null then return new; end if;
 select * into binding from public.program_test_training_bindings where test_id=new.test_id;
 select * into t from public.program_assessment_tests where id=new.test_id;
 if new.reference->>'role'='specific' then
   if new.reference->'task'->>'protocol_key' is distinct from 'program_test_'||t.id::text
     or new.reference->'task'->>'protocol_version' is distinct from t.definition_version::text then
     raise exception 'La referencia específica debe conservar el protocolo del programa.' using errcode='22023'; end if;
   if binding.measurement_mode='REPS_IN_TIME' and (binding.training_parameters->>'fixed_duration_seconds' is null
      or new.reference->'task'->'fixed_duration_seconds' is distinct from binding.training_parameters->'fixed_duration_seconds') then
     raise exception 'La ventana de trabajo debe coincidir con la prueba.' using errcode='22023'; end if;
   if binding.measurement_mode='TIME_FOR_DISTANCE' and (binding.training_parameters->>'fixed_distance_meters' is null
      or new.reference->'task'->'fixed_distance_meters' is distinct from binding.training_parameters->'fixed_distance_meters') then
     raise exception 'El trayecto debe coincidir con la prueba.' using errcode='22023'; end if;
 end if;
 return new;
end $$;
create trigger guard_performance_reference_protocol before insert on public.performance_training_references
 for each row execute function public.guard_performance_reference_protocol();

revoke all on function public.set_admin_performance_strategy(uuid,text,int,text,text,jsonb),
 public.get_preparation_training_setup(uuid) from public,anon;
grant execute on function public.set_admin_performance_strategy(uuid,text,int,text,text,jsonb),
 public.get_preparation_training_setup(uuid) to authenticated;
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
    test_id,program_id,profile_code,profile_version,measurement_mode,review_note,training_parameters)
    select n.id,v_new_program,b.profile_code,b.profile_version,b.measurement_mode,b.review_note,b.training_parameters
    from public.program_test_training_bindings b
    join public.program_assessment_tests o on o.id=b.test_id
    join public.program_assessment_tests n on n.program_id=v_new_program and n.code=o.code and n.category=o.category
    where b.program_id=p_source_program_id;
  return v_new_program;
end $$;
commit;

