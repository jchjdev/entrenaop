-- Pausa reanudable y alcance por preparación. No modifica carrera v5 ni sus dosis.
begin;
alter table public.adaptive_program_states
 add column user_id uuid references public.profiles(id),
 add column training_scope text not null default 'full' check(training_scope in ('full','running','performance')),
 add column requested_scope text check(requested_scope in ('full','running','performance')),
 add column paused_at timestamptz;
update public.adaptive_program_states a set user_id=g.user_id from public.preparation_goals g where g.id=a.preparation_goal_id;
alter table public.adaptive_program_states alter column user_id set not null;
alter table public.adaptive_program_states drop constraint adaptive_program_states_status_check;
alter table public.adaptive_program_states add constraint adaptive_program_states_status_check check(status in ('draft','training','needs_review','complete','paused'));
alter table public.adaptive_program_states drop constraint adaptive_program_states_continuation_code_check;
alter table public.adaptive_program_states add constraint adaptive_program_states_continuation_code_check check(continuation_code in ('setup','waiting_results','waiting_date','week_ready','needs_review','complete','paused'));

create function public.guard_adaptive_program_owner() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
 select user_id into owner_id from public.preparation_goals where id=new.preparation_goal_id;
 if new.user_id is not null and new.user_id is distinct from owner_id then raise exception 'Propietario de programa incompatible.' using errcode='42501'; end if;
 new.user_id:=owner_id;
 return new;
end $$;
create trigger adaptive_program_owner before insert or update on public.adaptive_program_states
for each row execute function public.guard_adaptive_program_owner();
revoke all on function public.guard_adaptive_program_owner() from public,anon,authenticated;

-- Conserva un generador anterior, priorizando una ejecución en curso y luego
-- el programa actualizado más recientemente. Los resultados no se borran.
update public.adaptive_program_states a set auto_advance=false where status='complete'
 or not exists(select 1 from public.preparation_goals g where g.id=a.preparation_goal_id and g.status='active');
with ranked as (
 select a.preparation_goal_id,row_number() over(partition by a.user_id order by
 exists(select 1 from public.scheduled_workouts sw where sw.preparation_goal_id=a.preparation_goal_id and sw.status='in_progress') desc,
 a.updated_at desc,a.last_generated_week desc nulls last,a.preparation_goal_id) n
 from public.adaptive_program_states a where auto_advance
)
update public.adaptive_program_states a set auto_advance=false,status='paused',continuation_code='paused',paused_at=now(),
 message='Programa pausado. Conservamos tus resultados; revisa tu situación antes de retomarlo.',next_generation_on=null
from ranked r where r.preparation_goal_id=a.preparation_goal_id and r.n>1;
update public.scheduled_workouts sw set status='cancelled' where source='algorithm' and status='planned' and execution_id is null
 and (exists(select 1 from public.adaptive_program_states a where a.preparation_goal_id=sw.preparation_goal_id and a.status='paused')
  or exists(select 1 from public.preparation_goals g where g.id=sw.preparation_goal_id and g.status='archived'));
create unique index one_generating_program_per_user on public.adaptive_program_states(user_id) where auto_advance;
alter table public.adaptive_program_states add constraint generating_program_status check(not auto_advance or status in ('training','needs_review'));

alter function public.get_preparation_training_setup(uuid) rename to get_preparation_training_setup_base;
revoke all on function public.get_preparation_training_setup_base(uuid) from public,anon,authenticated;

create function public.check_program_training_scope(p_goal uuid,p_scope text) returns void
language plpgsql security definer set search_path='' as $$
declare setup jsonb;
begin
 if p_scope is null or p_scope not in ('full','running','performance') then raise exception 'Elige qué quieres entrenar.' using errcode='22023'; end if;
 setup:=public.get_preparation_training_setup_base(p_goal);
 if (p_scope='running' and not (setup->>'has_running')::boolean)
 or (p_scope='performance' and jsonb_array_length(setup->'objectives')=0 and jsonb_array_length(setup->'references')=0)
 or (p_scope='full' and not (setup->>'has_running')::boolean and jsonb_array_length(setup->'objectives')=0 and jsonb_array_length(setup->'references')=0) then
  raise exception 'Esta preparación todavía no tiene una estrategia para lo elegido.' using errcode='22023'; end if;
end $$;
revoke all on function public.check_program_training_scope(uuid,text) from public,anon,authenticated;

create or replace function public.get_preparation_training_setup(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare setup jsonb; a public.adaptive_program_states%rowtype; scope text; active_program jsonb;
begin
 setup:=public.get_preparation_training_setup_base(p_goal_id);
 select * into a from public.adaptive_program_states where preparation_goal_id=p_goal_id;
 scope:=coalesce(a.requested_scope,a.training_scope,'full');
 select jsonb_build_object('goal_id',g.id,'name',p.name) into active_program
 from public.adaptive_program_states current_state join public.preparation_goals g on g.id=current_state.preparation_goal_id
 join public.preparation_programs p on p.id=g.program_id
 where current_state.user_id=auth.uid() and current_state.auto_advance and g.status='active';
 setup:=setup||jsonb_build_object('available_running',setup->'has_running',
  'available_performance',jsonb_array_length(setup->'objectives')>0 or jsonb_array_length(setup->'references')>0,
  'training_scope',scope,'active_program',active_program,
  'program_name',(select p.name from public.preparation_goals g join public.preparation_programs p on p.id=g.program_id where g.id=p_goal_id),
  'has_running',(setup->>'has_running')::boolean and scope<>'performance');
 if scope='running' then setup:=setup||jsonb_build_object('objectives','[]'::jsonb,'references','[]'::jsonb); end if;
 if a.status='paused' then setup:=setup||jsonb_build_object('pending_sessions','[]'::jsonb,'update_options','{}'::jsonb); end if;
 return setup;
end $$;
revoke all on function public.get_preparation_training_setup(uuid) from public,anon;
grant execute on function public.get_preparation_training_setup(uuid) to authenticated;

create function public.program_switch_pending_sessions(p_goal uuid) returns setof uuid
language sql stable security definer set search_path='' as $$
 select sw.id from public.scheduled_workouts sw
 where sw.user_id=auth.uid() and sw.source='algorithm' and sw.status='planned' and sw.execution_id is null
 and exists(select 1 from public.preparation_goals g where g.id=sw.preparation_goal_id and g.user_id=auth.uid() and g.status='active')
$$;
revoke all on function public.program_switch_pending_sessions(uuid) from public,anon,authenticated;

create function public.pause_adaptive_program(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.adaptive_program_states%rowtype;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 perform 1 from public.scheduled_workouts where preparation_goal_id=p_goal_id order by id for update;
 if exists(select 1 from public.scheduled_workouts where preparation_goal_id=p_goal_id and status='in_progress') then
  raise exception 'Finaliza o abandona la sesión en curso antes de pausar el programa.' using errcode='22023'; end if;
 if not exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id and status<>'draft')
 and not exists(select 1 from public.scheduled_workouts where preparation_goal_id=p_goal_id and source='algorithm') then
  raise exception 'Este programa todavía no se ha iniciado.' using errcode='22023'; end if;
 -- Las primeras publicaciones de carrera podían carecer del estado común.
 -- Pausarlas incorpora ese estado sin perder ni reconstruir su historial.
 insert into public.adaptive_program_states(preparation_goal_id,auto_advance,status,continuation_code,paused_at,message)
 values(p_goal_id,false,'paused','paused',now(),'Programa pausado. Tu progreso está guardado. Revisa tu situación actual para retomarlo.')
 on conflict(preparation_goal_id) do update set auto_advance=false,status='paused',continuation_code='paused',paused_at=now(),
  next_generation_on=null,message=excluded.message,updated_at=now() returning * into a;
 update public.scheduled_workouts set status='cancelled' where preparation_goal_id=p_goal_id and source='algorithm'
  and status='planned' and execution_id is null;
 return to_jsonb(a);
end $$;
revoke all on function public.pause_adaptive_program(uuid) from public,anon;
grant execute on function public.pause_adaptive_program(uuid) to authenticated;

-- Archivar una preparación personal tampoco puede dejar un generador oculto.
create function public.stop_archived_adaptive_program() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status='archived' and old.status='active' then
  if exists(select 1 from public.scheduled_workouts where preparation_goal_id=old.id and status='in_progress') then
   raise exception 'Resuelve la sesión en curso antes de dejar de seguir esta preparación.' using errcode='22023'; end if;
  update public.adaptive_program_states set auto_advance=false,status=case when status='draft' then status else 'paused' end,
   continuation_code=case when status='draft' then continuation_code else 'paused' end,paused_at=now(),next_generation_on=null where preparation_goal_id=old.id;
  update public.scheduled_workouts set status='cancelled' where preparation_goal_id=old.id and source='algorithm' and status='planned' and execution_id is null;
 end if;
 return new;
end $$;
create trigger stop_archived_adaptive_program before update of status on public.preparation_goals
for each row execute function public.stop_archived_adaptive_program();
revoke all on function public.stop_archived_adaptive_program() from public,anon,authenticated;


create or replace function public.save_adaptive_program_preferences(p_goal_id uuid,p_target_date date,p_targets jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare setup jsonb; obj jsonb; item record; n numeric;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if auth.uid() is null or not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then
  raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 if p_target_date is null or p_target_date<current_date then
  raise exception 'Elige una fecha de prueba actual o futura.' using errcode='22023'; end if;
 if p_targets is null or jsonb_typeof(p_targets)<>'object' then raise exception 'Objetivos no válidos.'; end if;
 setup:=public.get_preparation_training_setup_base(p_goal_id);
 for item in select * from jsonb_each(p_targets) loop
  select value into obj from jsonb_array_elements(setup->'objectives') where value->>'objective_key'=item.key;
  n:=(item.value->>'value')::numeric;
  if obj is null or item.value->>'measurement' is distinct from obj->>'measurement' or n is null or n not between 0.01 and 100000
    or (obj->>'measurement' in ('REPS','REPS_IN_TIME') and n<>trunc(n)) then raise exception 'Revisa la marca objetivo y su unidad.' using errcode='22023'; end if;
 end loop;
 update public.preparation_goals set target_date=p_target_date where id=p_goal_id;
 insert into public.adaptive_program_states(preparation_goal_id,objective_targets) values(p_goal_id,p_targets)
 on conflict(preparation_goal_id) do update set objective_targets=excluded.objective_targets,updated_at=now();
end $$;

create or replace function public.calculate_running_week_constrained(
 p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean,p_constraints jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 ctx public.running_intake_contexts%rowtype; ref record; age integer;
 revise boolean:=coalesce((p_constraints->>'revise_week')::boolean,false);
 excluded uuid[]:=array(select value::uuid from jsonb_array_elements_text(coalesce(p_constraints->'excluded_session_ids','[]')));
 last_sunday date:=current_date-extract(isodow from current_date)::integer;
 prev public.running_week_decisions%rowtype; existing public.running_week_decisions%rowtype;
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<last_sunday-6 or p_week_start>current_date+28 then
   raise exception 'Choose a current or upcoming complete week'; end if;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 if not p_replay_initial then
   select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
   if found and not revise then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
   select * into prev from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null order by week_start desc limit 1;
 end if;
 if prev.id is not null and current_date<p_week_start-1 and not p_preview_future then
   raise exception 'Close the previous week before adapting'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=p_goal_id;
 if not found or ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
   or (prev.id is null and ctx.recent_weeks_end_on<>last_sunday) then
   raise exception 'Update the current running context'; end if;
 if ctx.reports_pain or ctx.requires_professional_review then raise exception 'Health flag pauses the automatic proposal'; end if;
 select * into ref from jsonb_to_record(public.resolve_program_running_reference(p_goal_id))
   as x(reference_source text,reference_record_id text,continuity_confirmed_at timestamptz,completed_at timestamptz,value numeric,standard jsonb,controls jsonb);
 standard:=ref.standard; controls:=ref.controls;
 age:=current_date-ref.completed_at::date;
 if age<0 or ref.completed_at>now() then raise exception 'The selected 2 km mark is outside the reuse window'; end if;
 if age>30 and age<=45 and (ref.continuity_confirmed_at is null
   or ctx.recent_weeks_end_on<>last_sunday or 0=any(ctx.running_days_last_four_weeks)) then
   raise exception 'Confirm uninterrupted running before reuse'; end if;
 -- Fuera de ventana no se derivan ritmos. La semana fácil de mantenimiento
 -- solicita un control nuevo; no inventa una mejora ni perpetúa un ancla vieja.
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(excluded)
   and (not revise or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)))
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',sw.status,'rpe',case when exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id)
   then (select max(r.actual_rpe) from public.workout_execution_sets r where r.execution_id=e.id and r.block_format='running') else e.final_rpe end,'abandonment_reason',e.abandonment_reason,
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by sw.scheduled_date),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id and es.block_format='running') sets on true
 where sw.user_id=u and sw.status not in ('cancelled') and wd.policy_version in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') and wd.week_start>=p_week_start-56
   and wd.week_start<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(sw.scheduled_date-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(excluded)
   and (not revise or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and exists(select 1 from public.workout_blocks b
     where b.template_id=sw.template_id and b.format not in ('running','warm_up','cool_down')
       and exists(select 1 from public.workout_items wi join public.exercises ex on ex.id=wi.exercise_id
         left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
         where wi.block_id=b.id and (ep.code is null or ep.definition->'body_regions' ? 'lower_body')));
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') then
   previous:=previous||jsonb_build_object('normal_budget',
     (select sum(planned_minutes) from public.running_week_sessions where decision_id=prev.id),
     'load_weeks',0,'rotation',0);
 end if;
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,'capacity_minutes',ctx.comfortable_continuous_minutes,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 -- El coordinador puede solicitar otra propuesta con el tiempo restante.
 -- La política deportiva v5 y su historial permanecen intactos.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 result:=public.running_plan_v5(input);
 return result||jsonb_build_object('goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

create or replace function public.calculate_preparation_week_for_scope(p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype; ctx public.performance_training_contexts%rowtype;
  existing public.preparation_week_decisions%rowtype; previous public.preparation_week_decisions%rowtype;
  ref record; history jsonb; prior jsonb; proposal jsonb; proposals jsonb:='[]'; pending jsonb:='[]';
  occupied jsonb; loads jsonb; candidate jsonb; best jsonb; running jsonb; best_running jsonb;
  frequency_limit int; candidates jsonb; expected_running jsonb; minimum_runs int:=1; expected_runs int:=0; actual_runs int:=0;
  rotation int; score int; best_score int:=-2147483647; d int; session jsonb; blocked boolean; has_running boolean;
  running_error text; best_error text; coordinated jsonb; sessions jsonb:='[]'; required_missing boolean; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u and status='active';
 if not found then raise exception 'Preparación activa no disponible.' using errcode='42501'; end if;
 select * into existing from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 if found and not p_revision then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<current_date-extract(isodow from current_date)::int+1
   or p_week_start>current_date+28 then raise exception 'Elige una semana actual o próxima.' using errcode='22023'; end if;
 select * into previous from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null order by week_start desc limit 1;
 select * into ctx from public.performance_training_contexts where user_id=u;
 if not found or ctx.observed_at<now()-interval '30 days' or not ctx.capacity_confirmed or ctx.reports_pain then
   return jsonb_build_object('status','needs_context','reason','Actualiza disponibilidad, material y capacidad actual antes de planificar.','sessions','[]'::jsonb); end if;
 if exists(select 1 from public.workout_executions e left join public.workout_execution_sets es on es.execution_id=e.id
   where e.user_id=u and coalesce(es.completed_at,e.completed_at,e.started_at)>ctx.observed_at
     and (e.abandonment_reason='discomfort' or es.performance_result->>'stop_reason'='discomfort' or es.performance_result->>'tolerated'='false')) then
   return jsonb_build_object('status','needs_context','reason','Has registrado molestias después de confirmar el contexto. Revisa tu situación actual antes de planificar.','sessions','[]'::jsonb); end if;
 if g.target_date<current_date then return jsonb_build_object('status','blocked','reason','Actualiza la fecha objetivo.','sessions','[]'::jsonb); end if;
 for ref in select r.*,ep.definition from public.performance_training_references r
   join public.exercise_training_profiles ep on ep.code=r.reference->'task'->>'exercise_code'
     and ep.definition_version=(r.reference->'task'->>'exercise_version')::int
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
   select coalesce(jsonb_agg(jsonb_build_object('execution_id',e.id,'completed_on',e.completed_at::date,
     'status',e.status,'abandonment_reason',e.abandonment_reason,'dose',pw.dose,'sets',sets.items) order by e.completed_at),'[]') into history
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   join public.workout_executions e on e.id=sw.execution_id
   join lateral(select jsonb_agg(jsonb_build_object('status',es.status,'prescription',es.performance_prescription,
     'result',es.performance_result) order by es.set_order) items from public.workout_execution_sets es
     where es.execution_id=e.id and es.block_order=pw.block_order) sets on true
   where pw.reference_id=ref.id and e.completed_at::date<p_week_start and e.completed_at::date>=p_week_start-56;
   select value into prior from jsonb_array_elements(coalesce(previous.decision->'proposals','[]'))
     where value->>'reference_id'=ref.id::text or value->'covered_reference_ids' ? ref.id::text limit 1;
   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) then
     proposal:=jsonb_build_object('status','needs_equipment','reason','Falta material para esta variante; usa una alternativa calibrada compatible.');
   else proposal:=public.performance_task_v2_1(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end); end if;
   -- Cualquier molestia posterior al contexto pausa, aunque haya resultados buenos después.
   if exists(select 1 from jsonb_array_elements(history) h
     where (h->>'completed_on')::date>=ctx.observed_at::date and
       (h->>'abandonment_reason'='discomfort' or exists(select 1 from jsonb_array_elements(h->'sets') rs
         where rs->'result'->>'stop_reason'='discomfort' or rs->'result'->>'tolerated'='false'))) then
     proposal:=jsonb_build_object('status','blocked','reason','Actualiza el contexto después de las molestias registradas.'); end if;
   proposal:=proposal||jsonb_build_object('reference_id',ref.id,'objective_key',ref.objective_key,
     'name',coalesce(proposal->>'name',ref.definition->>'name'),'role',ref.reference->>'role','exercise_code',coalesce(proposal->'dose'->'task'->>'exercise_code',ref.definition->>'code'));
   proposals:=proposals||jsonb_build_array(proposal);
 end loop;

 -- Seleccionar específico accesible; la regresión conserva visible la práctica
 -- específica pendiente. No pautar dos regresiones para el mismo objetivo.
 select coalesce(jsonb_agg(p),'[]') into proposals from jsonb_array_elements(proposals) p
 where p->>'role'<>'regression' or not exists(select 1 from jsonb_array_elements(proposals) q
   where q->>'objective_key'=p->>'objective_key' and q->>'status'='ready'
     and (q->>'role'='specific' or (q->>'role'='regression' and q->>'reference_id'<p->>'reference_id')));
 select coalesce(jsonb_agg(case when exists(select 1 from jsonb_array_elements(proposals) q
   where q->>'objective_key'=p->>'objective_key' and q->>'status'='ready' and q->>'role' in ('specific','regression'))
   then p||'{"role":"support"}'::jsonb else p end),'[]') into pending
   from jsonb_array_elements(proposals) p where p->>'status'<>'ready';
 -- Una misma tarea calibrada sirve a varios objetivos sin duplicar su volumen.
 select coalesce(jsonb_agg(x.proposal),'[]') into proposals from (
   select (jsonb_agg(p order by case when p->>'role'='specific' then 0 when p->>'role'='regression' then 1 else 2 end,p->>'reference_id')->0)
     ||jsonb_build_object('covered_reference_ids',jsonb_agg(p->'reference_id'),'frequency',max((p->>'frequency')::int)) proposal
   from jsonb_array_elements(proposals) p where p->>'status'='ready' group by p->'dose'
   union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) x;
 if p_scope<>'running' then
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=p_goal_id order by a.assessed_on desc,a.created_at desc limit 1;
 if selected_category is null and exists(select 1 from public.program_assessment_tests where program_id=g.program_id and (category<>'both' or min_age<>0 or max_age<>120)) then
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_assessment','name','Categoría de las pruebas',
     'reason','Completa la evaluación de esta preparación para identificar las pruebas que te corresponden.')); end if;
 for ref in select b.test_id,t.name from public.program_test_training_bindings b
   join public.program_assessment_tests t on t.id=b.test_id
   where b.program_id=g.program_id and public.performance_test_applies(g.id,t.id) and (t.category='both' or t.category=selected_category)
     and not exists(select 1 from public.performance_training_references r where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and r.test_id=b.test_id) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_calibration','objective_key',ref.test_id,
     'name',ref.name,'reason','Esta prueba del programa aún no tiene referencia de trabajo.'));
 end loop;
 for ref in select o.* from public.performance_legacy_objectives o where o.program_id=g.program_id
   and (o.max_age_exclusive is null or coalesce((select extract(year from age(coalesce(g.target_date,current_date),fecha_nacimiento)) from public.profiles where id=u),0)<o.max_age_exclusive)
   and not exists(select 1 from public.performance_training_references r where r.preparation_goal_id=g.id and r.active and r.objective_key=o.objective_key) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_calibration','name',ref.name,'objective_key',ref.objective_key,'reason','Falta la referencia de trabajo de esta prueba del programa.'));
 end loop;
 for ref in select t.name from public.program_assessment_tests t where t.program_id=g.program_id and public.performance_test_applies(g.id,t.id)
   and t.category in ('both',selected_category)
   and not exists(select 1 from public.program_test_training_bindings b where b.test_id=t.id)
   and not exists(select 1 from public.program_training_modules m where m.test_id=t.id) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_strategy','name',ref.name,'reason','ADMIN debe configurar una estrategia compatible para esta prueba.'));
 end loop;
 end if;
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::int),'[]') into occupied
   from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6 and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(p_excluded)
   and (not p_revision or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)));
 select coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
     and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=p_scope<>'performance' and (exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry'));
 -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and q->>'objective_key'=p->>'objective_key'
   and (case q->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
        q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,p->>'reference_id')))),'[]') into proposals
 from jsonb_array_elements(proposals) p;
 if has_running then
  begin
   expected_running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
    jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),'availability',ctx.availability,'strength_days','[]'::jsonb,'leg_load_days','[]'::jsonb));
   expected_runs:=jsonb_array_length(coalesce(expected_running->'sessions','[]')); minimum_runs:=least(2,greatest(1,expected_runs));
  exception when others then expected_running:=null; end;
 end if;
 for frequency_limit in reverse 2..0 loop
 select coalesce(jsonb_agg((case when frequency_limit=0 then public.performance_compact_proposal_v2(p) else p end)||jsonb_build_object('requested_frequency',p->'frequency','frequency',least(greatest(1,frequency_limit),(p->>'frequency')::int))),'[]') into candidates from jsonb_array_elements(proposals) p;
 for rotation in 0..6 loop
   candidate:=public.performance_place_v2_1(candidates,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
   running:=null; running_error:=null;
   if has_running then
     begin
       running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
         jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),'availability',candidate->'remaining','strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days'));
     if jsonb_array_length(coalesce(running->'sessions','[]'))=0 then
         running_error:='No cabe una sesión de carrera compatible. Revisa disponibilidad y referencias.'; running:=null;
       elsif exists(select 1 from jsonb_array_elements(running->'sessions') rs where
         (rs->>'minutes')::int>coalesce((candidate->'remaining'->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)) then
         running_error:='La carrera ya publicada supera la disponibilidad actual. Revisa la agenda antes de añadir fuerza.'; running:=null;
       end if;
     exception when others then
       running_error:=case
         when sqlerrm like '%current running context%' then 'Actualiza el cuestionario de carrera y sus cuatro semanas recientes.'
         when sqlerrm like '%Health flag%' then 'Has indicado molestias en carrera. Actualiza tu situación antes de planificar.'
         when sqlerrm like '%compatible 2 km mark%' or sqlerrm like '%reuse window%' then 'Elige una marca vigente de 2 km para esta preparación.'
         when sqlerrm like '%Confirm uninterrupted%' then 'Confirma la continuidad de carrera para reutilizar esta marca.'
         when sqlerrm like '%standard or margin%' then 'Falta un mínimo oficial aplicable; elige una meta concreta o mejorar sin cifra.'
         else 'No se ha podido proponer carrera. Revisa la referencia, el cuestionario y los días disponibles.' end;
     end;
   end if;
   score:=(candidate->>'score')::int;
   -- Cobertura antes que minutos: evita premiar accesorios por desplazar carrera.
   score:=score - 10000*(select count(*) from jsonb_array_elements(candidate->'missing') q where q->>'required_for_objective'='true' and (q->>'scheduled')::int=0);
   if running is not null then score:=score+1000+300*jsonb_array_length(running->'sessions')
     +100*(select count(*) from jsonb_array_elements(running->'sessions') q where q->>'kind'<>'easy'); end if;
   if frequency_limit=0 then score:=score-50; end if;
   if has_running and jsonb_array_length(coalesce(running->'sessions','[]'))<minimum_runs then score:=score-10000; end if;
   if score>best_score then best:=candidate; best_running:=running; best_score:=score; best_error:=running_error; end if;
 end loop;
 end loop;
 -- El trabajo descartado no consume el permiso de progresar de lo publicado.
 select coalesce(jsonb_agg(w),'[]') into coordinated from (select distinct w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w) chosen;
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
 select coordinated||coalesce(jsonb_agg(p),'[]') into coordinated from jsonb_array_elements(proposals) p
 where not exists(select 1 from jsonb_array_elements(coordinated) c where c->>'reference_id'=p->>'reference_id');
 -- Mantener una dosis solo reduce el coste ya reservado; nunca rellena ese margen.
 for d in 1..7 loop
   select coalesce(jsonb_agg(c order by w.ordinality),'[]') into session from jsonb_array_elements(best->'days'->d::text->'work') with ordinality w(value,ordinality)
     join lateral(select value c from jsonb_array_elements(coordinated) c where c->>'reference_id'=w.value->>'reference_id') q on true;
   best:=jsonb_set(best,array['days',d::text,'work'],session);
 end loop;
 proposals:=coordinated;
 pending:=pending||coalesce(best->'missing','[]');
 if best_error is not null then pending:=pending||jsonb_build_array(jsonb_build_object('status','running_pending','name','Carrera','reason',best_error)); end if;
 for d in 1..7 loop
   session:=best->'days'->d::text;
   if (session->>'minutes')::int>0 then sessions:=sessions||jsonb_build_array(session||jsonb_build_object(
     'date',p_week_start+d-1,'kind','performance','name','Fuerza y rendimiento','session_order',case when exists(select 1 from jsonb_array_elements(session->'work') w where w->>'model' in ('power','course','reactive_agility','rope')) then 'performance_first' else 'running_first' end,'warm_up_seconds',420,'cool_down_seconds',180,'warm_up_instructions',public.performance_warm_up_instructions_v1(session),'warm_up_protocol_version','warm_up_v1_1')); end if;
 end loop;
 -- Una misma sesión física comparte preparación general y vuelta a la calma.
 select coalesce(jsonb_agg(case when r.item is null then f else f||jsonb_build_object(
   'combined',true,'standalone_minutes',f->'minutes',
   'minutes',public.preparation_shared_minutes_v2(f,r.item)-(r.item->>'minutes')::int,
   'shared_total_minutes',public.preparation_shared_minutes_v2(f,r.item),
   'warm_up_instructions',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup')
    then 'La activación general se comparte con carrera. Después: 1:00 de movilidad de las articulaciones que usarás y 2:00 de ensayo fácil de los movimientos pautados. Sin máximos.' else f->>'warm_up_instructions' end,
   'warm_up_seconds',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup') then 180 else 420 end
 ) end),'[]') into sessions from jsonb_array_elements(sessions) f
 left join lateral(select value item from jsonb_array_elements(coalesce(best_running->'sessions','[]')) q where q->>'date'=f->>'date') r on true;
 -- Un apoyo puede ser la única entrada de un objetivo; no debe desaparecer sin aviso.
 select coalesce(jsonb_agg(case when p->>'objective_key' is not null and exists(
   select 1 from jsonb_array_elements(sessions) ses,jsonb_array_elements(ses->'work') w
   where w->>'objective_key'=p->>'objective_key' or exists(select 1 from public.performance_training_references r
     where w->'covered_reference_ids' ? r.id::text and r.objective_key=p->>'objective_key'))
   then p||'{"role":"support"}'::jsonb else p||'{"role":"specific"}'::jsonb end),'[]') into pending from jsonb_array_elements(pending) p;
 actual_runs:=jsonb_array_length(coalesce(best_running->'sessions','[]'));
 if actual_runs>0 and actual_runs<expected_runs then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','reduced_running_coverage','name','Frecuencia de carrera',
   'role','support','scheduled',actual_runs,'requested',expected_runs,
   'reason','La semana conjunta conserva '||actual_runs||' de las '||expected_runs||' salidas que cabrían dedicando esos días solo a carrera. Para conservar ambas frecuencias, añade otro día o más tiempo.'));
 end if;
 if has_running and actual_runs<minimum_runs then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_running_frequency','name','Cobertura de carrera','role','specific',
   'reason','La distribución deja menos de '||minimum_runs||' salidas de carrera. Añade tiempo u otro día para cubrir la preparación conjunta.'));
 end if;
 if has_running and actual_runs=0 and not exists(select 1 from jsonb_each(ctx.availability) a where (a.value::text)::int>=25) then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_running_time','name','Tiempo para carrera','role','specific',
   'reason','Carrera v5 necesita al menos 25 minutos para una sesión completa. Ninguno de tus días alcanza ese tiempo. Aumenta al menos un día y vuelve a revisar la semana.'));
 end if;
 required_missing:=(has_running and actual_runs<minimum_runs) or (jsonb_array_length(sessions)=0 and best_running is null) or exists(select 1 from jsonb_array_elements(pending) p
   where coalesce(p->>'role','specific')<>'support' and coalesce((p->>'scheduled')::int,0)=0);
 return jsonb_build_object('status',case when required_missing then 'needs_attention' else 'ready' end,
   'policy_version','preparation_coordinator_v2_2','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

create or replace function public.materialize_preparation_week_scoped(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb,p_activation boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); plan jsonb; saved public.preparation_week_decisions%rowtype;
  d_id uuid; t_id uuid; b_id uuid; i_id uuid; sw_id uuid; ex_id uuid; s jsonb; w jsonb; v jsonb;
  run_session jsonb; run_schedule uuid; p jsonb; idx int; block_idx int; refs jsonb; goal_lock uuid; running_result jsonb;
begin
 if u is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
 -- Un único candado por deportista evita publicaciones simultáneas de dos
 -- preparaciones que consuman el mismo tiempo libre.
 perform 1 from public.profiles where id=u for update;
 select id into goal_lock from public.preparation_goals where id=p_goal_id and user_id=u and status='active' for update;
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into saved from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 if found then return saved.decision||jsonb_build_object('decision_id',saved.id,'already_published',true); end if;
 if not p_activation and exists(select 1 from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null)
   and current_date<p_week_start-1 and not public.preparation_can_advance(p_goal_id,p_week_start) then raise exception 'Cierra la semana anterior antes de adaptar y publicar.' using errcode='22023'; end if;
 if not p_activation and exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id and auto_advance)
  and exists(select 1 from public.preparation_week_decisions d where d.preparation_goal_id=p_goal_id and d.week_start<p_week_start and d.superseded_at is null
    and not public.preparation_week_closed(p_goal_id,d.week_start)) then
  raise exception 'Resuelve las sesiones pendientes antes de continuar el programa.' using errcode='22023'; end if;
 plan:=public.calculate_preparation_week(p_goal_id,p_week_start);
 if plan->>'status'<>'ready' then raise exception 'Resuelve los datos o conflictos pendientes antes de publicar.' using errcode='22023'; end if;
 if p_expected_proposal is null or plan is distinct from p_expected_proposal then
   raise exception 'Los datos o la agenda han cambiado. Revisa la propuesta actualizada.' using errcode='22023'; end if;
 insert into public.preparation_week_decisions(user_id,preparation_goal_id,week_start,policy_version,decision,input_snapshot)
 values(u,p_goal_id,p_week_start,plan->>'policy_version',plan,jsonb_build_object(
   'program',(select to_jsonb(a) from public.adaptive_program_states a where a.preparation_goal_id=p_goal_id),
   'target_date',(select target_date from public.preparation_goals where id=p_goal_id),
   'context',(select to_jsonb(c) from public.performance_training_contexts c where c.user_id=u),
   'references',(select jsonb_agg(to_jsonb(r)) from public.performance_training_references r where r.preparation_goal_id=p_goal_id and r.active)))
 returning id into d_id;
 if plan->'running' is not null and plan->'running'<>'null'::jsonb then
   running_result:=public.materialize_running_week_plan(p_goal_id,p_week_start,plan->'running');
   plan:=jsonb_set(plan,'{running}',running_result);
 end if;
 for s in select value from jsonb_array_elements(plan->'sessions') loop
   insert into public.workout_templates(name,description,origin,owner_user_id,visibility,status,estimated_duration_minutes,version)
   values('Fuerza y rendimiento','Semana coordinada. Calentamiento, práctica específica y registro real. Detén la práctica si aparecen molestias.',
     'algorithm',u,'private','published',(s->>'minutes')::int,1) returning id into t_id;
   insert into public.workout_blocks(template_id,order_index,name,format)
     values(t_id,0,'Calentamiento','warm_up') returning id into b_id;
   insert into public.workout_items(block_id,exercise_id,order_index,notes)
     values(b_id,'21000000-0000-4000-8000-000000000001',0,
       coalesce(s->>'warm_up_instructions',public.performance_warm_up_instructions_v1(s))) returning id into i_id;
   insert into public.workout_sets(item_id,order_index,target_duration_seconds,rest_after_seconds)
     values(i_id,0,420,0);
   block_idx:=1;
   insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,estimated_duration_minutes,
     preparation_goal_id,scheduled_date,source,status,order_index)
   values(u,t_id,'Fuerza y rendimiento',1,(s->>'minutes')::int,p_goal_id,(s->>'date')::date,'algorithm','planned',case when s->>'session_order'='performance_first' then 0 else 1 end) returning id into sw_id;
   if s->>'session_order'='performance_first' then
     update public.scheduled_workouts sw set order_index=1 from public.running_week_sessions rs
       where rs.scheduled_workout_id=sw.id and sw.preparation_goal_id=p_goal_id and sw.scheduled_date=(s->>'date')::date
         and sw.status='planned';
   end if;
   for w in select value from jsonb_array_elements(s->'work') loop
     p:=w->'dose'->'task';
     select id into ex_id from public.exercises where training_profile_code=p->>'exercise_code'
       and training_profile_version=(p->>'exercise_version')::int and is_public order by id limit 1;
     if ex_id is null then raise exception 'Un ejercicio de la propuesta ya no está disponible.'; end if;
     insert into public.workout_blocks(template_id,order_index,name,format)
       values(t_id,block_idx,w->>'name','straight_sets') returning id into b_id;
     insert into public.workout_items(block_id,exercise_id,order_index,notes)
       values(b_id,ex_id,0,w->>'reason') returning id into i_id;
     idx:=0;
     for v in select value from jsonb_array_elements(w->'dose'->'targets') loop
       insert into public.workout_sets(item_id,order_index,performance_prescription,rest_after_seconds)
       values(i_id,idx,jsonb_set(p,'{target_value}',v),case when idx=jsonb_array_length(w->'dose'->'targets')-1
         then 60 else (w->'dose'->>'rest_seconds')::int end);
       idx:=idx+1;
     end loop;
     insert into public.performance_week_work(decision_id,scheduled_workout_id,reference_id,block_order,dose)
       select d_id,sw_id,r::uuid,block_idx,w->'dose' from jsonb_array_elements_text(coalesce(w->'covered_reference_ids',jsonb_build_array(w->>'reference_id'))) r;
     block_idx:=block_idx+1;
   end loop;
   insert into public.workout_blocks(template_id,order_index,name,format)
     values(t_id,block_idx,'Vuelta a la calma','cool_down') returning id into b_id;
   insert into public.workout_items(block_id,exercise_id,order_index)
     values(b_id,'21000000-0000-4000-8000-000000000002',0) returning id into i_id;
   insert into public.workout_sets(item_id,order_index,target_duration_seconds,rest_after_seconds)
     values(i_id,0,180,0);
   if s->>'combined'='true' then
     select value into run_session from jsonb_array_elements(plan->'running'->'sessions') r where r->>'date'=s->>'date';
     select rs.scheduled_workout_id into run_schedule from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
       where rs.decision_id=(running_result->>'decision_id')::uuid and sw.scheduled_date=(s->>'date')::date and sw.status='planned';
     perform public.materialize_shared_preparation_day_v2(sw_id,run_schedule,s,run_session);
   end if;
 end loop;
 update public.preparation_week_decisions set decision=plan where id=d_id;
 return plan||jsonb_build_object('decision_id',d_id,'already_published',false);
end $$;

create or replace function public.advance_adaptive_program(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.adaptive_program_states%rowtype; g public.preparation_goals%rowtype; previous_week date; next_week date;
 plan jsonb; reason text; total int; completed int;
begin
 -- Mismo orden de candados que la publicación y la revisión de semanas.
 perform 1 from public.profiles where id=auth.uid() for update;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into a from public.adaptive_program_states where preparation_goal_id=p_goal_id for update;
 if not found or not a.auto_advance then return coalesce(to_jsonb(a),'{}'); end if;
 select max(week_start) into previous_week from (
      select week_start from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
      union select week_start from public.running_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
    ) weeks;
 if previous_week is null then return to_jsonb(a); end if;
 if not public.preparation_week_closed(p_goal_id,previous_week) then
  update public.adaptive_program_states set status='training',continuation_code='waiting_results',next_generation_on=null,message='La siguiente semana se preparará al resolver las sesiones de esta semana.',last_error_code=null where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 next_week:=greatest(previous_week+7,current_date-extract(isodow from current_date)::int+1);
 if next_week>=g.target_date then
  update public.adaptive_program_states set auto_advance=false,status='complete',continuation_code='complete',next_generation_on=null,message='Has llegado al final de la preparación. Revisa tus resultados.',updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 select count(*),count(*) filter(where status='completed') into total,completed from public.scheduled_workouts
 where preparation_goal_id=p_goal_id and scheduled_date between previous_week and previous_week+6;
 if completed=0 then reason:='No hay entrenamientos completados esta semana. Revisa tu situación y disponibilidad antes de continuar.';
 else
  -- Solo una semana por delante. Un registro adelantado no encadena meses ficticios.
  if next_week>current_date-extract(isodow from current_date)::int+8 then
    update public.adaptive_program_states set status='training',continuation_code='waiting_date',
      next_generation_on=next_week-7,last_error_code=null,
      message='Esta semana está cerrada por adelantado. La siguiente se preparará automáticamente a partir del '||to_char(next_week-7,'DD/MM')||', con los resultados disponibles.',updated_at=now()
      where preparation_goal_id=p_goal_id returning * into a;
    return to_jsonb(a);
   end if;
  begin
   plan:=public.calculate_preparation_week(p_goal_id,next_week);
   if plan->>'status'='ready' then
    plan:=public.publish_preparation_week(p_goal_id,next_week,plan);
    update public.adaptive_program_states set status='training',continuation_code='week_ready',next_generation_on=null,message='Tu próxima semana está preparada con los resultados registrados.',last_generated_week=next_week,last_error_code=null,updated_at=now()
     where preparation_goal_id=p_goal_id returning * into a;
    return to_jsonb(a);
   end if;
   reason:=coalesce(plan->>'reason','Revisa los datos pendientes antes de continuar.');
   if jsonb_array_length(coalesce(plan->'pending','[]'))>0 then reason:=coalesce(plan->'pending'->0->>'reason',reason); end if;
  exception when others then
   update public.adaptive_program_states set last_error_code=sqlstate where preparation_goal_id=p_goal_id;
   reason:='Tus resultados están guardados. Revisa los datos del programa para preparar la siguiente semana.';
  end;
 end if;
 update public.adaptive_program_states set status='needs_review',continuation_code='needs_review',review_items=coalesce(plan->'pending',jsonb_build_array(jsonb_build_object('status',coalesce(plan->>'status','needs_context'),'reason',reason))),next_generation_on=null,message=reason,updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
 return to_jsonb(a);
end $$;

create or replace function public.calculate_preparation_week_core(p_goal_id uuid,p_week_start date,p_revision boolean) returns jsonb
language sql security definer set search_path='' as $$
 select public.calculate_preparation_week_for_scope(p_goal_id,p_week_start,p_revision,
 coalesce((select case when p_revision then coalesce(requested_scope,training_scope) else training_scope end
 from public.adaptive_program_states where preparation_goal_id=p_goal_id),'full'),'{}'::uuid[])
$$;
revoke all on function public.calculate_preparation_week_for_scope(uuid,date,boolean,text,uuid[]),
 public.materialize_preparation_week_scoped(uuid,date,jsonb,boolean) from public,anon,authenticated;

create function public.save_adaptive_program_preferences(p_goal_id uuid,p_target_date date,p_targets jsonb,p_training_scope text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 perform public.check_program_training_scope(p_goal_id,p_training_scope);
 perform public.save_adaptive_program_preferences(p_goal_id,p_target_date,p_targets);
 update public.adaptive_program_states set requested_scope=p_training_scope,
 training_scope=case when status='draft' then p_training_scope else training_scope end where preparation_goal_id=p_goal_id;
end $$;
revoke all on function public.save_adaptive_program_preferences(uuid,date,jsonb,text) from public,anon;
grant execute on function public.save_adaptive_program_preferences(uuid,date,jsonb,text) to authenticated;

create function public.preview_adaptive_program_activation(p_goal_id uuid,p_week_start date) returns jsonb
language plpgsql security definer set search_path='' as $$
declare scope text; plan jsonb; excluded uuid[]; pauses jsonb;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 select coalesce(requested_scope,training_scope) into scope from public.adaptive_program_states where preparation_goal_id=p_goal_id;
 scope:=coalesce(scope,'full');
 perform public.check_program_training_scope(p_goal_id,scope);
 if exists(select 1 from public.scheduled_workouts where user_id=auth.uid() and status='in_progress') then
  return jsonb_build_object('status','needs_attention','sessions','[]'::jsonb,'pending',jsonb_build_array(jsonb_build_object(
   'status','session_in_progress','name','Entrenamiento en curso','reason','Finaliza o abandona la sesión en curso antes de cambiar el programa.'))); end if;
 if p_week_start>=(select target_date from public.preparation_goals where id=p_goal_id) then
  return jsonb_build_object('status','needs_attention','sessions','[]'::jsonb,'pending',jsonb_build_array(jsonb_build_object(
   'status','needs_target_date','name','Fecha de la prueba','reason','Actualiza la fecha: esta semana empieza después de tu prueba.'))); end if;
 select coalesce(array_agg(id order by id),'{}'::uuid[]) into excluded from public.program_switch_pending_sessions(p_goal_id) id;
 select coalesce(jsonb_agg(jsonb_build_object('goal_id',g.id,'name',p.name) order by g.id),'[]') into pauses
 from public.preparation_goals g join public.preparation_programs p on p.id=g.program_id
 where g.user_id=auth.uid() and g.status='active' and g.id<>p_goal_id and (
  exists(select 1 from public.adaptive_program_states a where a.preparation_goal_id=g.id and a.auto_advance)
  or exists(select 1 from public.scheduled_workouts sw where sw.preparation_goal_id=g.id and sw.source='algorithm' and sw.status='planned' and sw.execution_id is null));
 plan:=public.calculate_preparation_week_for_scope(p_goal_id,p_week_start,true,scope,excluded);
 return plan||jsonb_build_object('activation',jsonb_build_object('scope',scope,'week_start',p_week_start,'pauses',pauses,'cancel_ids',to_jsonb(excluded)));
end $$;
revoke all on function public.preview_adaptive_program_activation(uuid,date) from public,anon;
grant execute on function public.preview_adaptive_program_activation(uuid,date) to authenticated;

create or replace function public.activate_adaptive_program(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare plan jsonb; fresh jsonb; existing jsonb; a public.adaptive_program_states%rowtype; other record; scope text;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into a from public.adaptive_program_states where preparation_goal_id=p_goal_id for update;
 if not found then raise exception 'Guarda antes los datos de tu programa.' using errcode='22023'; end if;
 -- Un reintento de la misma aceptación conserva la decisión y sus sesiones.
 select d.decision||jsonb_build_object('decision_id',d.id,'already_published',true) into existing
 from public.preparation_week_decisions d where d.preparation_goal_id=p_goal_id and d.week_start=p_week_start and d.superseded_at is null;
 if a.auto_advance and existing->'activation'=p_expected_proposal->'activation' and p_expected_proposal ? 'activation' then return existing; end if;
 if not p_expected_proposal ? 'activation' then
  -- Compatibilidad con altas antiguas; no permite cambiar de programa sin revisar.
  if a.status='paused' or exists(select 1 from public.adaptive_program_states where user_id=auth.uid() and auto_advance and preparation_goal_id<>p_goal_id) then
   raise exception 'Revisa la propuesta para activar o retomar este programa.' using errcode='22023'; end if;
  return public.publish_preparation_week(p_goal_id,p_week_start,p_expected_proposal);
 end if;
 perform 1 from public.scheduled_workouts where user_id=auth.uid() and source='algorithm' order by id for update;
 fresh:=public.preview_adaptive_program_activation(p_goal_id,p_week_start);
 if fresh->>'status'<>'ready' or fresh is distinct from p_expected_proposal then
  raise exception 'Los datos o la agenda han cambiado. Revisa la propuesta actual antes de activar.' using errcode='22023'; end if;
 scope:=fresh->'activation'->>'scope';
 for other in select (value->>'goal_id')::uuid id from jsonb_array_elements(fresh->'activation'->'pauses') loop
  perform public.pause_adaptive_program(other.id);
 end loop;
 update public.adaptive_program_states set auto_advance=false where preparation_goal_id=p_goal_id;
 update public.scheduled_workouts set status='cancelled' where preparation_goal_id=p_goal_id and source='algorithm' and status='planned' and execution_id is null;
 -- El historial realizado sigue asociado a sus decisiones. La nueva revisión
 -- ocupa únicamente el calendario actual y futuro; no revive semanas antiguas.
 update public.preparation_week_decisions set superseded_at=now() where preparation_goal_id=p_goal_id and week_start>=p_week_start and superseded_at is null;
 update public.running_week_decisions set superseded_at=now() where preparation_goal_id=p_goal_id and week_start>=p_week_start and superseded_at is null;
 update public.adaptive_program_states set training_scope=scope,requested_scope=null,auto_advance=true,status='training',
  continuation_code='waiting_results',review_items='[]',next_generation_on=null,
  started_week=coalesce(started_week,p_week_start),last_generated_week=p_week_start,
  message='Al terminar tus sesiones, adaptaremos las siguientes con tus resultados.',updated_at=now() where preparation_goal_id=p_goal_id;
 plan:=public.materialize_preparation_week_scoped(p_goal_id,p_week_start,fresh-'activation',true);
 plan:=plan||jsonb_build_object('activation',fresh->'activation');
 update public.preparation_week_decisions set decision=plan-'decision_id'-'already_published' where id=(plan->>'decision_id')::uuid;
 return plan;
end $$;

create or replace function public.publish_preparation_week(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare plan jsonb;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id and status='paused')
 or exists(select 1 from public.adaptive_program_states where user_id=auth.uid() and auto_advance and preparation_goal_id<>p_goal_id) then
  raise exception 'Revisa y acepta el cambio de programa antes de publicar sesiones.' using errcode='22023'; end if;
 plan:=public.materialize_preparation_week_scoped(p_goal_id,p_week_start,p_expected_proposal,false);
 insert into public.adaptive_program_states(preparation_goal_id,auto_advance,status,continuation_code,last_generated_week,started_week)
 values(p_goal_id,true,'training','waiting_results',p_week_start,p_week_start)
 on conflict(preparation_goal_id) do update set auto_advance=true,status='training',continuation_code='waiting_results',
  started_week=coalesce(adaptive_program_states.started_week,p_week_start),last_generated_week=p_week_start;
 return plan;
end $$;

-- La revisión ordinaria conserva sus guardas. Un cambio de alcance en una
-- semana ya iniciada se acepta mediante el recorrido de activación, no por aquí.
alter function public.publish_preparation_week_revision(uuid,date,jsonb) rename to publish_preparation_week_revision_base;
revoke all on function public.publish_preparation_week_revision_base(uuid,date,jsonb) from public,anon,authenticated;
create function public.publish_preparation_week_revision(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 update public.adaptive_program_states set training_scope=coalesce(requested_scope,training_scope),requested_scope=null
 where preparation_goal_id=p_goal_id and user_id=auth.uid() and status<>'paused';
 return public.publish_preparation_week_revision_base(p_goal_id,p_week_start,p_expected_proposal);
end $$;
revoke all on function public.publish_preparation_week_revision(uuid,date,jsonb) from public,anon;
grant execute on function public.publish_preparation_week_revision(uuid,date,jsonb) to authenticated;

alter function public.publish_running_week(uuid,date) rename to publish_running_week_base;
revoke all on function public.publish_running_week_base(uuid,date) from public,anon,authenticated;
create function public.publish_running_week(p_goal_id uuid,p_week_start date) returns jsonb
language plpgsql security definer set search_path='' as $$
declare plan jsonb;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id and (status='paused' or training_scope='performance'))
 or exists(select 1 from public.adaptive_program_states where user_id=auth.uid() and auto_advance and preparation_goal_id<>p_goal_id) then
  raise exception 'Activa este programa desde su recorrido común antes de publicar carrera.' using errcode='22023'; end if;
 plan:=public.publish_running_week_base(p_goal_id,p_week_start);
 insert into public.adaptive_program_states(preparation_goal_id,auto_advance,status,continuation_code,last_generated_week,started_week)
 values(p_goal_id,true,'training','waiting_results',p_week_start,p_week_start)
 on conflict(preparation_goal_id) do update set auto_advance=true,status='training',last_generated_week=p_week_start;
 return plan;
end $$;
revoke all on function public.publish_running_week(uuid,date) from public,anon;
grant execute on function public.publish_running_week(uuid,date) to authenticated;
commit;
