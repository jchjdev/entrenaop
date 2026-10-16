begin;

-- Frecuencia observada: repartir trabajo conocido no acredita duplicar volumen.
create function public.performance_task_v4(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
 previous jsonb default '{}'::jsonb,started_on date default null) returns jsonb
language plpgsql immutable set search_path='' as $$
declare p jsonb; baseline jsonb; targets jsonb; e jsonb; dates date[]:='{}'; day date;
 freq int:=least(2,greatest(1,coalesce((previous->>'frequency')::int,(reference->>'frequency')::int,1)));
 n int; total int; per_set int; remainder int; seconds int; minimum int;
begin
 -- La frecuencia publicada continúa; la referencia del alta no la reinicia.
 p:=public.performance_task_v3(reference||jsonb_build_object('frequency',freq),profile,history,wk,target_date,previous,started_on);
 p:=p||jsonb_build_object('frequency_policy_version','performance_frequency_v1');
 if p->>'status'<>'ready' then return p; end if;
 if p->>'phase'='taper' then return p||'{"frequency_reason":"taper"}'::jsonb; end if;
 if freq=2 then return p||'{"frequency_reason":"continue_published"}'::jsonb; end if;
 -- Apoyos, práctica nueva y respuestas incompletas no habilitan otra exposición.
 if reference->>'role'='support' or target_date-wk<=14
   or p->>'outcome'='reduce' or previous->'dose' is null
   or previous->'dose'->'task'->>'stimulus_code' is distinct from p->'dose'->'task'->>'stimulus_code'
   then return p||'{"frequency_reason":"maintain"}'::jsonb; end if;
 baseline:=p->'comparison_dose';
 for e in select value from jsonb_array_elements(coalesce(history,'[]'))
   where (value->>'completed_on')::date between greatest((reference->>'observed_on')::date,wk-21) and wk-1
   order by value->>'completed_on' desc loop
   day:=(e->>'completed_on')::date;
   if day=any(dates) then continue; end if;
   if public.performance_exposure_signal_v2(e,baseline)='different_dose' then continue; end if;
   -- Deben ser las dos últimas respuestas comparables, no elegir solo éxitos.
   if public.performance_exposure_signal_v2(e,baseline)<>'tolerated' then return p||'{"frequency_reason":"insufficient_response"}'::jsonb; end if;
   dates:=array_append(dates,day); exit when cardinality(dates)=2;
 end loop;
 if cardinality(dates)<2 or dates[1]-dates[2]<7 or dates[1]<wk-7 then
   return p||'{"frequency_reason":"insufficient_response"}'::jsonb; end if;
 n:=jsonb_array_length(baseline->'targets');
 if p->>'model' in ('repetitions','load_repetitions','isometric','timed_repetitions') then
   -- Unidades semanales iguales o menores tras redondear; carga y esfuerzo intactos.
   select floor(sum(value::numeric)/2)::int into total from jsonb_array_elements_text(baseline->'targets');
   n:=ceil(n/2.0)::int; per_set:=total/n; remainder:=total%n;
   minimum:=case when p->>'model'='isometric' then 3
     when p->>'model'='load_repetitions' then coalesce((reference->>'rep_min')::int,4) else 1 end;
   if per_set<minimum then return p||'{"frequency_reason":"dose_not_divisible"}'::jsonb; end if;
   select jsonb_agg(per_set+case when i<=remainder then 1 else 0 end order by i) into targets from generate_series(1,n) i;
 elsif p->>'model'='course' and n>=2 and n%2=0 then
   -- Dividir intentos, NUNCA dividir el tiempo objetivo de un circuito.
   select jsonb_agg(value order by ordinality) into targets from jsonb_array_elements(baseline->'targets') with ordinality where ordinality<=n/2;
   -- Dos exposiciones iguales no deben aumentar intentos ni exigir otra velocidad.
   if exists(select 1 from jsonb_array_elements(baseline->'targets') v where v is distinct from baseline->'targets'->0) then
     return p||'{"frequency_reason":"dose_not_divisible"}'::jsonb; end if;
 else return p||'{"frequency_reason":"strategy_frequency_unchanged"}'::jsonb; end if;
 p:=p||jsonb_build_object('frequency',2,'outcome','redistribute','frequency_reason','two_tolerated_weekly_exposures',
   'frequency_fallback_dose',baseline,'reason','Repartimos el trabajo semanal tolerado en dos exposiciones separadas, sin subir también carga, repeticiones ni segundos. Si no caben, conservamos una exposición completa.');
 p:=jsonb_set(p,'{dose}',baseline||jsonb_build_object('targets',targets,'task',(baseline->'task')||jsonb_build_object('target_value',targets->0)));
 seconds:=public.performance_work_seconds_v2(p->'dose');
 return p||jsonb_build_object('work_seconds',seconds,'work_minutes',ceil(seconds/60.0));
end $$;
revoke all on function public.performance_task_v4(jsonb,jsonb,jsonb,date,date,jsonb,date) from public,anon,authenticated;

create function public.performance_frequency_candidate_v1(p jsonb,frequency_limit int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare seconds int;
begin
 if frequency_limit<2 and p ? 'frequency_fallback_dose' then
   p:=p||jsonb_build_object('dose',p->'frequency_fallback_dose','outcome','maintain','frequency_reason','keep_complete_exposure',
     'reason','Conservamos una exposición con la dosis tolerada: esta distribución no permite dos con tiempo y recuperación suficientes.');
 end if;
 if frequency_limit=0 then p:=public.performance_compact_proposal_v2(p); end if;
 seconds:=public.performance_work_seconds_v2(p->'dose');
 return p||jsonb_build_object('requested_frequency',p->'frequency','frequency',least(greatest(1,frequency_limit),(p->>'frequency')::int),
   'work_seconds',seconds,'work_minutes',ceil(seconds/60.0));
end $$;
revoke all on function public.performance_frequency_candidate_v1(jsonb,int) from public,anon,authenticated;


-- Proyección de carga: no escribe declaraciones ni renueva la confirmación de salud.
create function public.running_context_observed_v1(goal uuid,as_of date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare ctx public.running_intake_contexts%rowtype; u uuid; last_sunday date:=as_of-extract(isodow from as_of)::int;
 ending date; declared_index int; n int; days int; minutes int; declared_days int; declared_minutes int;
 day_values jsonb:='[]'; minute_values jsonb:='[]'; sources jsonb:='[]'; source text;
begin
 select user_id into u from public.preparation_goals where id=goal and user_id=auth.uid();
 if u is null then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=goal;
 if not found then return null; end if;
 for n in 0..3 loop
   ending:=last_sunday-n*7;
   declared_index:=case when ctx.recent_weeks_end_on>=ending and (ctx.recent_weeks_end_on-ending)%7=0 then (ctx.recent_weeks_end_on-ending)/7+1 end;
   declared_days:=ctx.running_days_last_four_weeks[declared_index]; declared_minutes:=ctx.running_minutes_last_four_weeks[declared_index];
   -- Un cierre parcial conserva los segundos observados. Recuperaciones no son carrera.
   -- Son datos de carga del deportista; no convierten marcas entre preparaciones.
   select count(distinct public.workout_performed_on_v1(e))::int,coalesce(ceil(sum(s.actual_duration_seconds)/60.0),0)::int into days,minutes
   from public.workout_executions e join public.workout_execution_sets s on s.execution_id=e.id
   where e.user_id=u and e.status in ('completed','abandoned') and s.block_format='running'
     and s.status='completed' and s.actual_duration_seconds>0
     and public.workout_performed_on_v1(e) between ending-6 and ending;
   -- Una declaración de esa misma semana puede incluir trabajo fuera de la app.
   -- max evita sumar dos veces las mismas sesiones; la edición permite completar lo externo.
   source:=case when days>0 and declared_days is not null then 'observed_and_declared'
     when days>0 then 'observed' when declared_days is not null then 'declared' else 'unknown' end;
   day_values:=day_values||to_jsonb(greatest(days,coalesce(declared_days,0)));
   minute_values:=minute_values||to_jsonb(greatest(minutes,coalesce(declared_minutes,0)));
   sources:=sources||to_jsonb(source);
 end loop;
 return to_jsonb(ctx)||jsonb_build_object('running_days_last_four_weeks',day_values,'running_minutes_last_four_weeks',minute_values,
   'recent_weeks_end_on',last_sunday,'recent_load_sources',sources,'observed_load_policy_version','running_observed_context_v1');
end $$;
revoke all on function public.running_context_observed_v1(uuid,date) from public,anon,authenticated;

create function public.get_running_intake_context_observed(p_goal_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select public.running_context_observed_v1(p_goal_id,current_date)
$$;
revoke all on function public.get_running_intake_context_observed(uuid) from public,anon;
grant execute on function public.get_running_intake_context_observed(uuid) to authenticated;


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
 if not found then raise exception 'Update the current running context'; end if;
 -- Solo cambia la proyección de carga; conserva las fechas de salud y el motor v5.
 ctx:=jsonb_populate_record(ctx,public.running_context_observed_v1(p_goal_id,current_date));
 if ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
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
 select coalesce(jsonb_agg(extract(isodow from public.workout_load_on_v1(scheduled_workouts))::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(excluded)
   and (not revise or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)))
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),'scheduled_date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',coalesce(public.workout_block_outcome_v1(e.id)->>'status',sw.status),'rpe',case when exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id)
   then (select max(r.actual_rpe) from public.workout_execution_sets r where r.execution_id=e.id and r.block_format='running') else e.final_rpe end,'abandonment_reason',public.workout_block_outcome_v1(e.id)->>'abandonment_reason',
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),e.id),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id and es.block_format='running') sets on true
 where sw.user_id=u and sw.status not in ('cancelled') and wd.policy_version in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56
   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(public.workout_load_on_v1(sw)-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
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
 -- La selección deportiva sigue en v5; la evidencia usa la realización real.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 result:=public.running_plan_v5(input);
 return result||jsonb_build_object('evidence_policy_version','adaptive_evidence_v1','goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

create or replace function public.calculate_preparation_week_for_scope(p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype; ctx public.performance_training_contexts%rowtype;
  existing public.preparation_week_decisions%rowtype; previous public.preparation_week_decisions%rowtype;
  ref record; history jsonb; prior jsonb; proposal jsonb; proposals jsonb:='[]'; pending jsonb:='[]';
  occupied jsonb; loads jsonb; candidate jsonb; best jsonb; running jsonb; best_running jsonb;
  started_on date; include_support boolean; frequency_limit int; candidates jsonb; expected_running jsonb; minimum_runs int:=1; expected_runs int:=0; actual_runs int:=0;
  shared_credit int; rotation int; score int; best_score int:=-2147483647; d int; session jsonb; blocked boolean; has_running boolean;
  running_cache jsonb:='{}'; running_constraints jsonb; cache_key text; running_error text; best_error text; coordinated jsonb; sessions jsonb:='[]'; required_missing boolean; selected_category text;
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
 select coalesce(min(week_start),p_week_start) into started_on from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;
 for ref in select r.*,ep.definition from public.performance_training_references r
   join public.exercise_training_profiles ep on ep.code=r.reference->'task'->>'exercise_code'
     and ep.definition_version=(r.reference->'task'->>'exercise_version')::int
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
   select coalesce(jsonb_agg(jsonb_build_object('execution_id',e.id,'completed_on',public.workout_performed_on_v1(e),'scheduled_date',sw.scheduled_date,
     'status',public.workout_block_outcome_v1(e.id,pw.block_order)->>'status',
     'abandonment_reason',public.workout_block_outcome_v1(e.id,pw.block_order)->>'abandonment_reason','dose',pw.dose,'sets',sets.items) order by coalesce(e.performed_at,e.completed_at),e.id),'[]') into history
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   join public.workout_executions e on e.id=sw.execution_id
   join lateral(select jsonb_agg(jsonb_build_object('status',es.status,'prescription',es.performance_prescription,
     'result',es.performance_result) order by es.set_order) items from public.workout_execution_sets es
     where es.execution_id=e.id and es.block_order=pw.block_order) sets on true
   where pw.reference_id=ref.id and public.workout_performed_on_v1(e)<p_week_start and public.workout_performed_on_v1(e)>=p_week_start-56;
   select value into prior from jsonb_array_elements(coalesce(previous.decision->'proposals','[]'))
     where value->>'reference_id'=ref.id::text or value->'covered_reference_ids' ? ref.id::text limit 1;
   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) then
     proposal:=jsonb_build_object('status','needs_equipment','reason','Falta material para esta variante; usa una alternativa calibrada compatible.');
   else proposal:=public.performance_task_v4(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end,started_on); end if;
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

 proposals:=public.performance_select_v3(proposals);
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
 select coalesce(jsonb_agg(extract(isodow from public.workout_load_on_v1(scheduled_workouts))::int),'[]') into occupied
   from public.scheduled_workouts where user_id=u and public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6 and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(p_excluded)
   and (not p_revision or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)));
 select coalesce(jsonb_agg(jsonb_build_object('day',public.workout_load_on_v1(sw)-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
     and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',public.workout_load_on_v1(sw)-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=p_scope<>'performance' and (exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry'));
 -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and q->>'objective_key'=p->>'objective_key'
   and (case q->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
        coalesce((q->>'selection_rank')::int,1),q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,coalesce((p->>'selection_rank')::int,1),p->>'reference_id')))),'[]') into proposals
 from jsonb_array_elements(proposals) p;
 if has_running then
  begin
   expected_running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
    jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),'availability',ctx.availability,'strength_days','[]'::jsonb,'leg_load_days','[]'::jsonb));
   expected_runs:=jsonb_array_length(coalesce(expected_running->'sessions','[]')); minimum_runs:=least(2,greatest(1,expected_runs));
  exception when others then expected_running:=null; end;
 end if;
 for include_support in select unnest(array[true,false]) loop
 for frequency_limit in reverse 2..0 loop
 select coalesce(jsonb_agg(public.performance_frequency_candidate_v1(p,frequency_limit)),'[]') into candidates from jsonb_array_elements(proposals) p where include_support or p->>'optional' is distinct from 'true';
 for rotation in 0..6 loop
   candidate:=public.performance_place_v3(candidates,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
   -- Ensayar reservas sin ahorro, con activación compartida y con cierre.
   -- Cada alternativa pasa el coste exacto antes de puntuar.
   for shared_credit in select unnest(array[0,4,7]) loop
   running:=null; running_error:=null;
   if has_running then
     begin
       running_constraints:=jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),
         'availability',public.preparation_running_budget_v1(candidate,ctx.availability,shared_credit),'strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days');
       cache_key:=running_constraints::text;
       -- Las alternativas repetidas no vuelven a leer y evaluar el historial.
       -- Caché local a esta llamada; el coste conjunto se valida siempre abajo.
       if running_cache ? cache_key then running:=running_cache->cache_key;
       else
        running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,running_constraints);
        running_cache:=running_cache||jsonb_build_object(cache_key,running);
       end if;
     if jsonb_array_length(coalesce(running->'sessions','[]'))=0 then
         running_error:='No cabe una sesión de carrera compatible. Revisa disponibilidad y referencias.'; running:=null;
       elsif exists(select 1 from jsonb_array_elements(running->'sessions') rs where
         (case when coalesce((candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text->>'minutes')::int,0)>0
           then public.preparation_shared_minutes_v2(candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text,rs)
           else (rs->>'minutes')::int end)>coalesce((ctx.availability->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)) then
         running_error:='La carrera ya publicada supera la disponibilidad actual. Revisa la agenda antes de añadir fuerza.'; running:=null;
       end if;
     exception when others then
       running_error:=case
         when sqlerrm like '%current running context%' then 'Confirma tu contexto actual de carrera; recuperamos los entrenamientos que ya has registrado.'
         when sqlerrm like '%Health flag%' then 'Has indicado molestias en carrera. Actualiza tu situación antes de planificar.'
         when sqlerrm like '%compatible 2 km mark%' or sqlerrm like '%reuse window%' then 'Elige una marca vigente de 2 km para esta preparación.'
         when sqlerrm like '%Confirm uninterrupted%' then 'Confirma la continuidad de carrera para reutilizar esta marca.'
         when sqlerrm like '%standard or margin%' then 'Falta un mínimo oficial aplicable; elige una meta concreta o mejorar sin cifra.'
         else 'No se ha podido proponer carrera. Revisa la referencia, el cuestionario y los días disponibles.' end;
     end;
   end if;
   -- Una redistribución a medias no es una pauta: comparar la alternativa completa.
   if exists(select 1 from jsonb_array_elements(candidate->'missing') m
      join jsonb_array_elements(candidates) c on c->>'reference_id'=m->>'reference_id'
      where c->>'outcome'='redistribute') then continue; end if;
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
 end loop;
 end loop;
 -- El trabajo descartado no consume el permiso de progresar de lo publicado.
 select coalesce(jsonb_agg(w),'[]') into coordinated from (select distinct w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w) chosen;
 -- Persistir exposiciones entregadas, no una frecuencia deseada que no cupo.
 select coalesce(jsonb_agg(p||jsonb_build_object('frequency',
   (select count(*) from jsonb_each(best->'days') d,jsonb_array_elements(d.value->'work') w
    where w->>'reference_id'=p->>'reference_id'))),'[]') into coordinated
 from jsonb_array_elements(coordinated) p;
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
 select coordinated||coalesce(jsonb_agg(p||jsonb_build_object('allocation_status','not_scheduled','allocation_reason','Se conserva la referencia, pero esta semana tiene prioridad la cobertura específica, carrera y recuperación.')),'[]') into coordinated from jsonb_array_elements(proposals) p
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
 sessions:=public.performance_controls_v3(sessions,coalesce(previous.decision,'{}'));
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
   'policy_version','preparation_coordinator_v3','evidence_policy_version','adaptive_evidence_v1','frequency_policy_version','performance_frequency_v1','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

commit;
