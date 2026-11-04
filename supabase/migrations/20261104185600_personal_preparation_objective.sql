begin;

create function public.preparation_has_official_objectives_v1(program_code text)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from public.performance_legacy_objectives where program_id=program_code)
     or exists(select 1 from public.program_assessment_tests where program_id=program_code)
     or exists(select 1 from public.program_training_modules where program_id=program_code)
$$;

create function public.place_personal_preparation_objective_v1(
 goal uuid,wk date,plan jsonb,moved uuid default null,new_date date default null
) returns jsonb language plpgsql stable set search_path='' as $$
declare
 candidates jsonb:=plan->'personal_candidates'; proposal jsonb; work jsonb; session jsonb; run jsonb;
 session_index int; day date; minutes int; recovery int; target date; reason text; label text;
begin
 plan:=plan-'personal_candidates';
 if coalesce(jsonb_array_length(candidates),0)=0 then return plan; end if;
 if (select count(distinct objective_key) from public.performance_training_references
     where preparation_goal_id=goal and user_id=auth.uid() and active and test_id is null
      and objective_key not like 'legacy:%')>1 then
  label:='Objetivo personal';
  reason:='Elige qué objetivo personal quieres mantener activo. Tu preparación oficial puede continuar.';
 else
  select value into proposal from jsonb_array_elements(public.performance_select_v4(candidates))
   order by (value->>'status'='ready') desc,value->>'reference_id' limit 1;
  label:=proposal->>'name';
  reason:=case when proposal->>'status'='ready' then 'Esta semana no hay un hueco para tu objetivo personal que respete el trabajo de las pruebas.'
   else proposal->>'reason' end;
  if plan->>'status'='ready' and proposal->>'status'='ready' then
   select target_date into target from public.preparation_goals where id=goal and user_id=auth.uid();
   proposal:=public.performance_frequency_candidate_v2(proposal,1)||
    '{"personal_extra":true,"optional":true,"required_for_objective":false}'::jsonb;
   work:=public.performance_exposure_v2(proposal,0);
   recovery:=(public.performance_frequency_strategy_v2(work)->>'recovery_days')::int;
   -- Una exposición opcional en una cita que ya tiene preparación de rendimiento.
   for session,session_index in select value,(ordinality-1)::int
    from jsonb_array_elements(plan->'sessions') with ordinality order by value->>'date' loop
    day:=(session->>'date')::date;
    if day<current_date or day>=target-1 then continue; end if;
    if exists(select 1 from jsonb_array_elements(plan#>'{control_schedule,scheduled}') c
     where abs((c->>'date')::date-day)<greatest(2,recovery)) then continue; end if;
    if public.adaptive_control_prior_load_conflict_v1(day,wk,moved,new_date) then continue; end if;
    if exists(select 1 from jsonb_array_elements(plan->'sessions') other,
     jsonb_array_elements(other->'work') item
     where exists(select 1 from jsonb_array_elements_text(work->'body_regions') region
      where item->'body_regions' ? region)
     and ((other->>'date')::date<>day and abs((other->>'date')::date-day)<
      greatest(recovery,(public.performance_frequency_strategy_v2(item)->>'recovery_days')::int)
      or (other->>'date')::date=day and exists(select 1 from jsonb_array_elements_text(work->'movement_patterns') pattern
       where item->'movement_patterns' ? pattern))) then continue; end if;
    if work->'body_regions' ? 'lower_body' and exists(
     select 1 from jsonb_array_elements(plan#>'{running,sessions}') r
     where r->>'family'<>'E' and abs((r->>'date')::date-day)<recovery
      and (r->>'date')::date<>day) then continue; end if;
    select value into run from jsonb_array_elements(plan#>'{running,sessions}') where value->>'date'=session->>'date';
    minutes:=(work->>'reservation_minutes')::int;
    if coalesce((session->>'shared_total_minutes')::int,(session->>'minutes')::int)+minutes
      >coalesce((plan->'availability'->>extract(isodow from day)::int::text)::int,0) then continue; end if;
    session:=session||jsonb_build_object('work',session->'work'||jsonb_build_array(work),
      'minutes',(session->>'minutes')::int+minutes,
      'standalone_minutes',coalesce((session->>'standalone_minutes')::int,(session->>'minutes')::int)+minutes);
    if run is not null then
     session:=session||jsonb_build_object('shared_total_minutes',public.preparation_shared_minutes_v2(session,run));
    end if;
    return jsonb_set(plan,array['sessions',session_index::text],session)
      ||jsonb_build_object('proposals',plan->'proposals'||jsonb_build_array(proposal));
   end loop;
  end if;
 end if;
 return plan||jsonb_build_object('pending',coalesce(plan->'pending','[]'::jsonb)||jsonb_build_array(
  jsonb_build_object('name',label,'status','personal_objective_deferred','role','support','reason',reason)));
end $$;

revoke all on function public.preparation_has_official_objectives_v1(text),
 public.place_personal_preparation_objective_v1(uuid,date,jsonb,uuid,date) from public,anon,authenticated;

do $migration$
declare change record; definition text;
begin
 for change in select * from (values
  ('public.save_performance_reference(uuid,jsonb,uuid)'::regprocedure,
   $old$observed date; min_reps int; max_reps int; legacy public.performance_legacy_objectives%rowtype;$old$,
   $new$observed date; min_reps int; max_reps int; legacy public.performance_legacy_objectives%rowtype; personal boolean;$new$),
  ('public.save_performance_reference(uuid,jsonb,uuid)'::regprocedure,
   $old$  update public.performance_training_references set active=false where preparation_goal_id=p_goal_id$old$,
   $new$  personal:=p_test_id is null and legacy.objective_key is null and public.preparation_has_official_objectives_v1(g.program_id);
  if personal then
    -- La fila de la preparación ya está bloqueada por el guardado de referencias.
    if p_reference->'replace_personal_objective'='true'::jsonb then
      update public.performance_training_references set active=false
       where preparation_goal_id=p_goal_id and active and test_id is null and objective_key not like 'legacy:%'
        and objective_key<>key;
    elsif exists(select 1 from public.performance_training_references
      where preparation_goal_id=p_goal_id and active and test_id is null and objective_key not like 'legacy:%'
       and objective_key<>key) then
      raise exception 'Ya tienes un objetivo personal activo. Usa Cambiar objetivo para elegir otro.' using errcode='22023';
    end if;
    r:=r||jsonb_build_object('equipment_confirmed',coalesce(p_reference->'equipment_confirmed','false'::jsonb));
  end if;
  update public.performance_training_references set active=false where preparation_goal_id=p_goal_id$new$),
  ('public.save_performance_reference(uuid,jsonb,uuid)'::regprocedure,
   $old$if p_reference->>'equipment_confirmed'='true' then$old$,
   $new$if not personal and p_reference->>'equipment_confirmed'='true' then$new$),
  ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date)'::regprocedure,
   $old$started_on date; include_support boolean;$old$,
   $new$started_on date; official boolean; is_personal boolean; personal_candidates jsonb:='[]'; include_support boolean;$new$),
  ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date)'::regprocedure,
   $old$ for ref in select r.*,ep.definition from public.performance_training_references r$old$,
   $new$ official:=public.preparation_has_official_objectives_v1(g.program_id);
 for ref in select r.*,ep.definition from public.performance_training_references r$new$),
  ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date)'::regprocedure,
   $old$   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) then$old$,
   $new$   is_personal:=official and ref.test_id is null and ref.objective_key not like 'legacy:%';
   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) and not (is_personal and coalesce(ref.reference->>'equipment_confirmed','false')='true') then$new$),
  ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date)'::regprocedure,
   $old$   proposals:=proposals||jsonb_build_array(proposal);
 end loop;

 if p_scope<>'running' then proposals:=public.performance_support_candidates_v2$old$,
   $new$   if is_personal then personal_candidates:=personal_candidates||jsonb_build_array(proposal);
   else proposals:=proposals||jsonb_build_array(proposal); end if;
 end loop;

 if p_scope<>'running' then proposals:=public.performance_support_candidates_v2$new$),
  ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date)'::regprocedure,
   $old$   'already_published',false);
end $old$,
   $new$   'already_published',false,'personal_candidates',personal_candidates);
end $new$),
  ('public.calculate_preparation_week_for_scope(uuid,date,boolean,text,uuid[])'::regprocedure,
   $old$ return public.apply_adaptive_protocol_controls_v1(p_goal_id,p_week_start,plan);$old$,
   $new$ plan:=public.apply_adaptive_protocol_controls_v1(p_goal_id,p_week_start,plan);
 return public.place_personal_preparation_objective_v1(p_goal_id,p_week_start,plan);$new$),
  ('public.get_preparation_training_setup(uuid)'::regprocedure,
   $old$ setup:=setup||jsonb_build_object('available_running',setup->'has_running',$old$,
   $new$ setup:=setup||jsonb_build_object('available_running',setup->'has_running',
  'personal_objective_limit',(select case when public.preparation_has_official_objectives_v1(g.program_id) then 1 end
   from public.preparation_goals g where g.id=p_goal_id and g.user_id=auth.uid()),$new$),
  ('public.preview_preparation_strength_move(uuid,date,text)'::regprocedure,
   $old$  alternative:=public.apply_adaptive_protocol_controls_v1(p_goal_id,p_week_start,alternative,moved.id,moved.new_date);$old$,
   $new$  alternative:=public.apply_adaptive_protocol_controls_v1(p_goal_id,p_week_start,alternative,moved.id,moved.new_date);
  alternative:=public.place_personal_preparation_objective_v1(p_goal_id,p_week_start,alternative,moved.id,moved.new_date);$new$),
  ('public.preview_preparation_strength_move(uuid,date,text)'::regprocedure,
   $old$select w->>'reference_id' from jsonb_array_elements(original->'sessions') s cross join jsonb_array_elements(s->'work') w$old$,
   $new$select w->>'reference_id' from jsonb_array_elements(original->'sessions') s cross join jsonb_array_elements(s->'work') w
    where w->>'personal_extra' is distinct from 'true'$new$),
  ('public.materialize_shared_preparation_day_v3(uuid,uuid,jsonb,jsonb)'::regprocedure,
   $old$ else array['run_warm','force_warm','force_work','run_work','run_cool','force_cool'] end;$old$,
   $new$ else array['run_warm','force_warm','force_work','run_work','force_extra','run_cool','force_cool'] end;$new$),
  ('public.materialize_shared_preparation_day_v3(uuid,uuid,jsonb,jsonb)'::regprocedure,
   $old$    case phase when 'force_warm' then format='warm_up' when 'force_cool' then format='cool_down' else format not in ('warm_up','cool_down') end order by order_index loop$old$,
   $new$    case phase when 'force_warm' then format='warm_up' when 'force_cool' then format='cool_down'
    else format not in ('warm_up','cool_down') and (run_first or
     ((force_session->'work'->(order_index-1)->>'personal_extra' is not distinct from 'true') = (phase='force_extra')))
    end order by order_index loop$new$),
  ('public.performance_warm_up_steps_v3(jsonb)'::regprocedure,
   $old$ for w in select value from jsonb_array_elements(coalesce(session->'work','[]')) loop$old$,
   $new$ for w in select value from jsonb_array_elements(coalesce(session->'work','[]'))
  where value->>'personal_extra' is distinct from 'true' loop$new$)
 ) as changes(signature,previous,replacement) loop
  definition:=replace(pg_get_functiondef(change.signature),E'\r\n',E'\n');
  if length(definition)-length(replace(definition,change.previous,''))<>length(change.previous) then
   raise exception 'Revisar el contrato de % antes de separar el objetivo personal.',change.signature;
  end if;
  execute replace(definition,change.previous,change.replacement);
 end loop;
end $migration$;

commit;
