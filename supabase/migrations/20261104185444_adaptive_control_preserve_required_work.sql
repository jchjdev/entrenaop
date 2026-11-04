begin;

do $migration$
declare
 change record;
 definition text;
begin
 for change in select * from (values
  ('public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb,uuid,date)'::regprocedure,
   $old$recovery_removed jsonb:='[]'; record jsonb;$old$,
   $new$recovery_removed jsonb:='[]'; record jsonb; affected_references text[]:='{}';$new$),
  ('public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb,uuid,date)'::regprocedure,
   $old$and other->>'family'<>'E' and abs((other->>'date')::date-day)<3) then continue; end if;
    if public.adaptive_control_prior_load_conflict_v1(day,wk,p_moved,p_new_date) then continue; end if;
    chosen:=day; exit;$old$,
   $new$and other->>'family'<>'E' and abs((other->>'date')::date-day)<3) then continue; end if;
    if public.adaptive_control_prior_load_conflict_v1(day,wk,p_moved,p_new_date) then continue; end if;
    -- El control de 2 km retira todo el trabajo de rendimiento de ese día y los adyacentes.
    -- Probar el siguiente hueco si así desaparece la cobertura de un objetivo obligatorio.
    if exists(
     with assigned as (
      select (session->>'date')::date as practice_date, objectives.objective_key
      from jsonb_array_elements(plan->'sessions') session,jsonb_array_elements(session->'work') item
      cross join lateral (
       select item->>'objective_key' as objective_key
       union select jsonb_array_elements_text(item->'covered_objective_keys')
      ) objectives
      where item->>'optional' is distinct from 'true'
     ), required as (
      select objectives.objective_key
      from jsonb_array_elements(plan->'proposals') proposal
      cross join lateral (
       select proposal->>'objective_key' as objective_key
       union select jsonb_array_elements_text(proposal->'covered_objective_keys')
      ) objectives
      where proposal->>'required_for_objective'='true'
     )
     select 1 from required
     where exists(select 1 from assigned where assigned.objective_key=required.objective_key)
       and not exists(select 1 from assigned where assigned.objective_key=required.objective_key
        and abs(assigned.practice_date-day)>=2)
    ) then continue; end if;
    chosen:=day; exit;$new$),
  ('public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb,uuid,date)'::regprocedure,
   $old$recovery_removed:=recovery_removed||jsonb_build_array(jsonb_build_object('name',w->>'name','date',s->>'date','reason','recovery_around_protocol_control'));$old$,
   $new$recovery_removed:=recovery_removed||jsonb_build_array(jsonb_build_object('name',w->>'name','date',s->>'date','reason','recovery_around_protocol_control'));
     if c->>'profile'='running_2000m_v1' then
      affected_references:=array_append(affected_references,w->>'reference_id');
     end if;$new$),
  ('public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb,uuid,date)'::regprocedure,
   $old$plan:=jsonb_set(plan,'{sessions}',out_sessions);$old$,
   $new$plan:=jsonb_set(plan,'{sessions}',out_sessions);
  if cardinality(affected_references)>0 then
   -- La siguiente semana lee la frecuencia y las dosis de esta decisión.
   select coalesce(jsonb_agg(case when proposal->>'reference_id'=any(affected_references) then
     proposal||jsonb_build_object('frequency',delivered.frequency,'exposure_doses',delivered.doses)
      ||case when delivered.frequency=0 then jsonb_build_object('allocation_status','not_scheduled',
         'allocation_reason','Se aplaza este trabajo para dejar recuperación alrededor del control de 2 km.')
       else jsonb_build_object('allocation_status','reduced',
         'allocation_reason','Se reduce este trabajo para dejar recuperación alrededor del control de 2 km.',
         'dose',delivered.doses->0,
         'work_seconds',public.performance_work_seconds_v2(delivered.doses->0),
         'work_minutes',ceil(public.performance_work_seconds_v2(delivered.doses->0)/60.0)) end
     else proposal end order by pos),'[]') into updated
   from jsonb_array_elements(plan->'proposals') with ordinality p(proposal,pos)
   left join lateral (
    select count(*) as frequency,coalesce(jsonb_agg(item->'dose' order by
     (item->>'exposure_index')::int,session->>'date',item_pos),'[]') as doses
    from jsonb_array_elements(out_sessions) session,
     jsonb_array_elements(session->'work') with ordinality items(item,item_pos)
    where item->>'reference_id'=proposal->>'reference_id'
   ) delivered on proposal->>'reference_id'=any(affected_references);
   plan:=jsonb_set(plan,'{proposals}',updated);
   if plan ? 'pending' then
    select coalesce(jsonb_agg(case when proposal is null then warning else warning||jsonb_build_object(
      'scheduled',proposal->'frequency','reason',proposal->'allocation_reason') end order by pos),'[]') into updated
    from jsonb_array_elements(plan->'pending') with ordinality p(warning,pos)
    left join lateral (
     select value proposal from jsonb_array_elements(plan->'proposals')
     where value->>'reference_id'=warning->>'reference_id'
    ) changed on warning->>'reference_id'=any(affected_references);
    plan:=jsonb_set(plan,'{pending}',updated);
   end if;
  end if;$new$),
  ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date)'::regprocedure,
   $old$if has_running and actual_runs<minimum_runs then
  pending:=$old$,
   $new$-- Cuando falta el contexto o la marca no sabemos cuántas salidas cabrían.
 if has_running and actual_runs<minimum_runs and expected_running is not null then
  pending:=$new$),
  ('public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[],uuid,date)'::regprocedure,
   $old$Carrera v5 necesita al menos 25 minutos para una sesión completa.$old$,
   $new$Reserva al menos 25 minutos para una sesión de carrera.$new$)
 ) as changes(signature,old_sql,new_sql) loop
  definition:=replace(pg_get_functiondef(change.signature),E'\r\n',E'\n');
  change.old_sql:=replace(change.old_sql,E'\r\n',E'\n');
  if length(definition)-length(replace(definition,change.old_sql,''))<>length(change.old_sql) then
   raise exception 'Revisar el contrato de % antes de proteger la cobertura del plan.',change.signature;
  end if;
  execute replace(definition,change.old_sql,change.new_sql);
 end loop;
end;
$migration$;

commit;
