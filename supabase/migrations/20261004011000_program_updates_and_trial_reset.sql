-- Cambiar entradas no reescribe resultados. El reinicio es una herramienta de
-- ensayos para administradores y requiere confirmación explícita en servidor.
begin;

create function public.preparation_program_update_options(p_goal_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare wk date; reason text;
begin
 if not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then
  raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select max(week_start) into wk from (
  select week_start from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
  union select week_start from public.running_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
 ) weeks;
 if wk is null then return jsonb_build_object('can_replace_pending',false,'reason','Revisa tus primeros entrenamientos antes de activar el programa.'); end if;
 begin
  perform public.check_preparation_week_revision(p_goal_id,wk);
  return jsonb_build_object('can_replace_pending',true,'week_start',wk,
   'reason','Esta semana aún no ha empezado. Puedes revisar una propuesta con tus datos actuales antes de sustituir las sesiones pendientes.');
 exception when invalid_parameter_value then
  get stacked diagnostics reason=message_text;
  return jsonb_build_object('can_replace_pending',false,'week_start',wk,'reason',reason);
 end;
end $$;
revoke all on function public.preparation_program_update_options(uuid) from public,anon,authenticated;

create function public.reset_adaptive_program_trial(p_goal_id uuid,p_confirmation text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); schedules uuid[]; templates uuid[]; executions uuid[];
 common_count int; running_count int;
begin
 if u is null or not exists(select 1 from public.admin_permissions where user_id=u) then
  raise exception 'El reinicio de ensayos requiere permisos de administrador.' using errcode='42501'; end if;
 if p_confirmation is distinct from 'REINICIAR' then
  raise exception 'Escribe REINICIAR para confirmar el borrado de los entrenamientos de ensayo.' using errcode='22023'; end if;
 perform 1 from public.profiles where id=u for update;
 perform 1 from public.preparation_goals where id=p_goal_id and user_id=u and status='active' for update;
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 -- Incluye las sesiones canceladas al combinar carrera y fuerza y las revisiones
 -- anteriores; todas deben pertenecer a esta preparación y al algoritmo.
 perform 1 from public.scheduled_workouts where preparation_goal_id=p_goal_id and user_id=u and source='algorithm' order by id for update;
 select coalesce(array_agg(id),'{}'::uuid[]),coalesce(array_agg(distinct template_id),'{}'::uuid[])
 into schedules,templates from public.scheduled_workouts where preparation_goal_id=p_goal_id and user_id=u and source='algorithm';
 perform 1 from public.workout_templates where id=any(templates) order by id for update;
 perform 1 from public.workout_executions where template_id=any(templates) order by id for update;
 if exists(select 1 from public.scheduled_workouts where id=any(schedules) and status='in_progress')
  or exists(select 1 from public.workout_executions where template_id=any(templates) and status='in_progress') then
  raise exception 'Termina o abandona la sesión en curso antes de reiniciar los ensayos.' using errcode='22023'; end if;
 -- Una plantilla reutilizada fuera del programa no se puede destruir con él.
 if exists(select 1 from public.workout_templates where id=any(templates) and (owner_user_id is distinct from u or origin<>'algorithm'))
  or exists(select 1 from public.scheduled_workouts where template_id=any(templates) and not(id=any(schedules)))
  or exists(select 1 from public.workout_executions where template_id=any(templates) and user_id is distinct from u)
  or exists(select 1 from public.performance_week_work pw join public.preparation_week_decisions d on d.id=pw.decision_id
    where pw.scheduled_workout_id=any(schedules) and (d.user_id is distinct from u or d.preparation_goal_id is distinct from p_goal_id))
  or exists(select 1 from public.running_week_sessions rs join public.running_week_decisions d on d.id=rs.decision_id
    where rs.scheduled_workout_id=any(schedules) and (d.user_id is distinct from u or d.preparation_goal_id is distinct from p_goal_id))
  or exists(select 1 from public.performance_week_work pw join public.preparation_week_decisions d on d.id=pw.decision_id
    where d.preparation_goal_id=p_goal_id and not(pw.scheduled_workout_id=any(schedules)))
  or exists(select 1 from public.running_week_sessions rs join public.running_week_decisions d on d.id=rs.decision_id
    where d.preparation_goal_id=p_goal_id and not(rs.scheduled_workout_id=any(schedules))) then
  raise exception 'Hay recursos compartidos fuera de estos ensayos. No se ha borrado nada.' using errcode='22023'; end if;
 select coalesce(array_agg(id),'{}'::uuid[]) into executions from public.workout_executions where template_id=any(templates) and user_id=u;
 select count(*) into common_count from public.preparation_week_decisions where preparation_goal_id=p_goal_id and user_id=u;
 select count(*) into running_count from public.running_week_decisions where preparation_goal_id=p_goal_id and user_id=u;
 -- Desactivar antes de borrar impide que la continuidad genere otra semana.
 update public.adaptive_program_states set auto_advance=false,status='draft',continuation_code='setup',
  started_week=null,last_generated_week=null,next_generation_on=null,last_error_code=null,review_items='[]',
  message='Ensayos reiniciados. Revisa los primeros entrenamientos con tus datos actuales.',updated_at=now()
 where preparation_goal_id=p_goal_id;
 delete from public.workout_mutation_receipts where user_id=u and
  (resource_id=any(executions) or resource_id=any(schedules) or resource_id=any(templates)
   or resource_id in (select id from public.workout_execution_sets where execution_id=any(executions)));
 delete from public.performance_week_work where scheduled_workout_id=any(schedules);
 delete from public.running_week_sessions where scheduled_workout_id=any(schedules);
 delete from public.scheduled_workouts where id=any(schedules) and user_id=u;
 delete from public.workout_executions where id=any(executions) and user_id=u;
 delete from public.preparation_week_decisions where preparation_goal_id=p_goal_id and user_id=u;
 delete from public.running_week_decisions where preparation_goal_id=p_goal_id and user_id=u;
 delete from public.workout_templates where id=any(templates) and owner_user_id=u and origin='algorithm';
 return jsonb_build_object('sessions',cardinality(schedules),'executions',cardinality(executions),
  'preparation_decisions',common_count,'running_decisions',running_count);
end $$;
revoke all on function public.reset_adaptive_program_trial(uuid,text) from public,anon,authenticated;
grant execute on function public.reset_adaptive_program_trial(uuid,text) to authenticated;


create or replace function public.get_preparation_training_setup(p_goal_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare g public.preparation_goals%rowtype; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=g.id order by a.assessed_on desc,a.created_at desc limit 1;
 return jsonb_build_object('can_reset_trial',exists(select 1 from public.admin_permissions where user_id=auth.uid()),'update_options',public.preparation_program_update_options(g.id),'has_running',g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry')
   or exists(select 1 from public.program_training_modules where program_id=g.program_id and module_key='running_2000m_v1')
   or exists(select 1 from public.running_intake_contexts where preparation_goal_id=g.id),'program_state',coalesce((select to_jsonb(a)-'last_error_code' from public.adaptive_program_states a where a.preparation_goal_id=g.id),'{}'::jsonb),'pending_sessions',coalesce((select jsonb_agg(jsonb_build_object('id',sw.id,'date',sw.scheduled_date,'name',sw.template_name,'status',sw.status) order by sw.scheduled_date) from public.scheduled_workouts sw where sw.preparation_goal_id=g.id and sw.status in ('planned','in_progress') and sw.scheduled_date<=current_date),'[]'::jsonb),'goal_id',g.id,'target_date',g.target_date,'category',selected_category,
   'context',(select to_jsonb(c)-'user_id' from public.performance_training_contexts c where c.user_id=auth.uid()),
   'running_context',(select to_jsonb(c)-'preparation_goal_id' from public.running_intake_contexts c where c.preparation_goal_id=g.id),
   'catalog',coalesce((select jsonb_agg(jsonb_build_object('definition',ep.definition,'version',ep.definition_version) order by ep.definition->>'name')
     from public.exercise_training_profiles ep where exists(select 1 from public.exercises ex
       where ex.training_profile_code=ep.code and ex.training_profile_version=ep.definition_version and ex.is_public)),'[]'::jsonb),
   'references',coalesce((select jsonb_agg(to_jsonb(r)-'user_id' order by r.created_at) from public.performance_training_references r where r.preparation_goal_id=g.id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key)),'[]'::jsonb),
   'objectives',coalesce((select jsonb_agg(jsonb_build_object('objective_key',t.id::text,'test_id',t.id,'name',t.name,'category',t.category,
       'profile_code',b.profile_code,'profile_version',b.profile_version,'measurement',b.measurement_mode,
       'protocol_key','program_test_'||t.id::text,'protocol_version',t.definition_version,'instructions',t.protocol_notes,
       'parameters',b.training_parameters) order by t.display_order)
     from public.program_test_training_bindings b join public.program_assessment_tests t on t.id=b.test_id
     where b.program_id=g.program_id and public.performance_test_applies(g.id,t.id) and (selected_category is null or t.category in ('both',selected_category))),'[]'::jsonb) || coalesce((select jsonb_agg(to_jsonb(o)||jsonb_build_object('program_objective_key',o.objective_key))
       from public.performance_legacy_objectives o where o.program_id=g.program_id and
       (o.max_age_exclusive is null or coalesce((select extract(year from age(coalesce(g.target_date,current_date),fecha_nacimiento)) from public.profiles where id=auth.uid()),0)<o.max_age_exclusive)),'[]'::jsonb),
   'relations',(select jsonb_agg(to_jsonb(r)) from public.performance_exercise_relations r where policy_version='performance_v1'),
   'published_weeks',coalesce((select jsonb_agg(week_start order by week_start desc) from (select week_start from public.preparation_week_decisions where preparation_goal_id=g.id and superseded_at is null
       union select week_start from public.running_week_decisions where preparation_goal_id=g.id and superseded_at is null) active_weeks),'[]'::jsonb));
end $$;

commit;
