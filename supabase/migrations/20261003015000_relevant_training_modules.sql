begin;
create or replace function public.get_preparation_training_setup(p_goal_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare g public.preparation_goals%rowtype; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=g.id order by a.assessed_on desc,a.created_at desc limit 1;
 return jsonb_build_object('has_running',g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry')
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or exists(select 1 from public.running_intake_contexts where preparation_goal_id=g.id),'goal_id',g.id,'target_date',g.target_date,'category',selected_category,
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

commit;
