-- Controles por necesidad de información. Los umbrales son guardas operativas
-- versionadas: no una frecuencia de tests ni una promesa de recuperación.
create function public.running_continuity_observed_v1(goal uuid,as_of date) returns boolean
language sql stable security definer set search_path='' as $$
 select count(distinct date_trunc('week',public.workout_performed_on_v1(e)))=4
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 join public.workout_executions e on e.id=sw.execution_id
 where sw.preparation_goal_id=goal and sw.user_id=auth.uid() and e.user_id=auth.uid()
  and e.status in ('completed','abandoned') and public.workout_block_outcome_v1(e.id)->>'status'='completed'
  and public.workout_performed_on_v1(e) between
   as_of-extract(isodow from as_of)::int+1-28 and least(as_of-extract(isodow from as_of)::int,current_date)
  and exists(select 1 from public.workout_execution_sets es where es.execution_id=e.id
   and es.block_format='running' and es.status='completed' and es.actual_duration_seconds>0 and es.actual_distance_meters>0)
$$;

create function public.adaptive_control_decision_v1(f jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare question text;
begin
 if not coalesce((f->>'supported')::boolean,false) then return '{"action":"none","reason":"unsupported_protocol"}'; end if;
 if (f->>'days_left')::int<=14 or f->>'phase'='taper' then return '{"action":"none","reason":"protect_exam_recovery"}'; end if;
 if coalesce((f->>'target_met')::boolean,false) then return '{"action":"none","reason":"target_already_observed"}'; end if;
 if not coalesce((f->>'healthy')::boolean,false) or coalesce((f->>'adverse')::boolean,true) then
  return '{"action":"defer","reason":"recovery_or_context"}'; end if;
 if coalesce((f->>'tolerated_days')::int,0)<4 or coalesce((f->>'recent_days')::int,0)<2 or f->>'phase' in ('base','reentry') then
  return '{"action":"none","reason":"observe_ordinary_work_first"}'; end if;
 -- La fecha no basta. Hace falta práctica nueva, transferencia por comprobar,
 -- o información caducada que ya limita una decisión del motor.
 if coalesce((f->>'new_days')::int,0)<4 then return '{"action":"none","reason":"no_new_evidence"}'; end if;
 if f->>'phase'='specific' and f->>'attempt_phase' is distinct from 'specific' then question:='phase_transfer';
 elsif coalesce((f->>'growth')::numeric,1)>=1.20 then question:='work_changed_transfer_unknown';
 elsif coalesce((f->>'anchor_blocks_quality')::boolean,false) then question:='reference_limits_training';
 elsif coalesce((f->>'plateau')::boolean,false) and not coalesce((f->>'signature_tried')::boolean,false) then question:='repeated_work_transfer_unknown';
 elsif not coalesce((f->>'has_mark')::boolean,false) and f->>'attempt_phase' is null then question:='missing_protocol_mark';
 end if;
 if question is null then return '{"action":"none","reason":"ordinary_results_are_sufficient"}'; end if;
 return jsonb_build_object('action','control','reason',question,'question',case question
  when 'phase_transfer' then 'Comprobar cómo se traslada el trabajo al formato de la prueba antes de la puesta a punto.'
  when 'work_changed_transfer_unknown' then 'El trabajo tolerado ha cambiado; medir el protocolo permite revisar la referencia y la prioridad.'
  when 'reference_limits_training' then 'La referencia anterior ya limita decisiones de carrera; comprobarla permite recalibrar sin inventar ritmos.'
  when 'repeated_work_transfer_unknown' then 'Se repite trabajo comparable sin una nueva comprobación de transferencia; distinguir capacidad y límites del reparto.'
  else 'Obtener una primera marca del protocolo tras consolidar práctica tolerada.' end);
end $$;

-- Solo acepta el resultado de una prueba realmente pautada por este módulo.
-- Un trabajo normal, un intento nulo o una ventana temporal parcial no son marca.
create function public.adaptive_control_result_valid_v1(p jsonb,r jsonb) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(p->>'policy_version'='adaptive_protocol_control_v1' and p->>'intent'='control'
  and r->>'technique_valid'='true' and r->>'conditions_confirmed'='true' and r->>'tolerated'='true'
  and r->>'stop_reason'='none' and (r->>'value')::numeric>=0
  and (p->>'measurement'<>'REPS_IN_TIME' or (r->>'actual_duration_seconds')::numeric=(p->>'fixed_duration_seconds')::numeric)
  and (p->>'measurement' not in ('TIME_FOR_COURSE','TIME_FOR_DISTANCE','DURATION') or (r->>'value')::numeric>0),false)
$$;

create function public.adaptive_protocol_observations_v1(goal uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(x order by observed_on desc),'[]') from (
  select distinct es.id,public.workout_performed_on_v1(e) observed_on,pw.dose->'control'->>'objective_key' objective_key,
   es.performance_prescription->>'measurement' measurement,(es.performance_result->>'value')::numeric value,
   es.performance_prescription->>'protocol_key' protocol_key,
   es.performance_prescription->>'measurement'='DURATION' and
    (es.performance_result->>'value')::numeric>=(es.performance_prescription->>'target_value')::numeric lower_bound
  from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
  join public.workout_executions e on e.id=sw.execution_id
  join public.workout_execution_sets es on es.execution_id=e.id and es.block_order=pw.block_order
  where sw.preparation_goal_id=goal and sw.user_id=auth.uid() and e.user_id=auth.uid()
   and e.status in ('completed','abandoned') and es.status='completed'
   and public.workout_block_outcome_v1(e.id,es.block_order)->>'status'='completed'
   and public.workout_performed_on_v1(e)<=current_date
   and public.adaptive_control_result_valid_v1(es.performance_prescription,es.performance_result)
 ) x
$$;

-- Separar un rodaje fácil conocido de una calidad o un test evita tratar toda
-- actividad como si hubiera sido un máximo. Son guardas de fechas, no horas
-- fisiológicas garantizadas. Lo no realizado/desconocido no acredita descanso.
create function public.adaptive_control_prior_load_conflict_v1(test_day date,wk date) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.scheduled_workouts sw
  where sw.user_id=auth.uid() and public.workout_load_on_v1(sw)<wk
   and abs(public.workout_load_on_v1(sw)-test_day)<3 and sw.status not in ('cancelled','skipped')
   and (abs(public.workout_load_on_v1(sw)-test_day)<2 or sw.execution_id is null
    or exists(select 1 from public.running_week_sessions rs where rs.scheduled_workout_id=sw.id and rs.prescription->>'family'<>'E')
    or exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id and pw.dose ? 'control')
    or exists(select 1 from public.workout_execution_sets es where es.execution_id=sw.execution_id and es.status='completed'
     and (es.actual_rpe>=8 or (es.performance_result->>'rpe')::numeric>=8 or (es.performance_result->>'rir')::numeric<2))))
$$;

create function public.adaptive_control_candidates_v1(goal uuid,wk date,plan jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare out jsonb:='[]'; p jsonb; attempt jsonb; facts jsonb; choice jsonb; review jsonb;
 ref public.performance_training_references%rowtype; target date; n int; recent int; fresh int; signatures int;
 bad boolean; work numeric; baseline numeric; since_on date; seen boolean; healthy boolean;
begin
 select target_date into target from public.preparation_goals where id=goal and user_id=auth.uid();
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select observed_at>=now()-interval '30 days' and capacity_confirmed and not reports_pain into healthy
 from public.performance_training_contexts where user_id=auth.uid();
 for p in select value from jsonb_array_elements(plan->'proposals') where value->>'status'='ready'
   and value->>'optional' is distinct from 'true' and value->>'required_for_objective'='true' loop
  select * into ref from public.performance_training_references where id=(p->>'reference_id')::uuid and user_id=auth.uid();
  if ref.target_profile_code not in ('push_up_standard','front_plank_forearms','slalom_ball_course_16m')
   or p->>'exercise_code'<>ref.target_profile_code then continue; end if;
  select pw.dose->'control'||jsonb_build_object('date',sw.scheduled_date) into attempt
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   where sw.preparation_goal_id=goal and sw.user_id=auth.uid() and sw.scheduled_date<wk and sw.status<>'cancelled'
    and pw.dose->'control'->>'objective_key'=p->>'objective_key' order by sw.scheduled_date desc limit 1;
  select value into review from jsonb_array_elements(coalesce(plan->'goal_reviews','[]')) where value->>'objective_key'=p->>'objective_key';
  since_on:=coalesce((attempt->>'date')::date,(review->>'observed_on')::date,(ref.reference->>'observed_on')::date);
  select sum(v::numeric) into work from jsonb_array_elements_text(p->'dose'->'targets') v;
  select sum(v::numeric) into baseline from jsonb_array_elements_text(ref.reference->'targets') v;
  baseline:=coalesce((attempt->>'baseline_work')::numeric,baseline);
  with days as (
   select public.workout_performed_on_v1(e) as observed_on,pw.dose->'targets' signature,
    coalesce(bool_and(es.status='completed' and es.performance_result->>'technique_valid'='true'
     and es.performance_result->>'conditions_confirmed'='true' and es.performance_result->>'tolerated'='true'
     and es.performance_result->>'stop_reason'='none'
     and case es.performance_prescription->>'effort_mode' when 'rir' then (es.performance_result->>'rir')::numeric>=2
       when 'rpe' then (es.performance_result->>'rpe')::numeric between 1 and 7 else true end),false) ok
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   join public.performance_training_references rr on rr.id=pw.reference_id
   join public.workout_executions e on e.id=sw.execution_id
   join public.workout_execution_sets es on es.execution_id=e.id and es.block_order=pw.block_order
   where sw.preparation_goal_id=goal and sw.user_id=auth.uid() and rr.objective_key=ref.objective_key
    and (es.performance_prescription->>'exercise_code'=ref.target_profile_code or
      (ref.target_profile_code='slalom_ball_course_16m' and es.performance_prescription->>'exercise_code' in ('cod_braking_10m','slalom_ball_course_sector')))
    and es.performance_prescription->>'intent' in ('work','practice') and not pw.dose ? 'control'
    and e.status in ('completed','abandoned') and public.workout_block_outcome_v1(e.id,es.block_order)->>'status'='completed'
    and public.workout_performed_on_v1(e) between wk-42 and least(wk-1,current_date)
   group by e.id,pw.scheduled_workout_id,pw.reference_id,pw.block_order,pw.dose
  ) select count(distinct observed_on) filter(where ok),count(distinct observed_on) filter(where ok and observed_on>=wk-14),
   count(distinct observed_on) filter(where ok and observed_on>since_on),count(distinct signature) filter(where ok and observed_on>since_on),
   coalesce(bool_or(not ok) filter(where observed_on>=wk-14),false) into n,recent,fresh,signatures,bad from days;
  facts:=jsonb_build_object('supported',ref.target_measurement in ('REPS','REPS_IN_TIME','DURATION','TIME_FOR_COURSE')
     and (ref.target_measurement<>'REPS_IN_TIME' or ref.reference->'task'->>'measurement'='REPS_IN_TIME'
       or ref.objective_key='legacy:upper_body_push_ups_2_min'),
   'phase',p->>'phase','days_left',target-wk,'healthy',healthy,'adverse',bad or p->>'outcome'='reduce',
   'tolerated_days',n,'recent_days',recent,'new_days',fresh,'growth',round(work/nullif(baseline,0),4),
   'plateau',fresh>=6 and signatures=1,'signature_tried',attempt->'signature'=p->'dose'->'targets',
   'has_mark',review->>'last_protocol_mark' is not null,'target_met',review->>'last_mark_meets_target'='true' and review->>'recent_protocol_mark'='true',
   'attempt_phase',attempt->>'phase');
  choice:=public.adaptive_control_decision_v1(facts);
  out:=out||jsonb_build_array(jsonb_build_object('objective_key',p->>'objective_key','name',p->>'name',
   'reference_id',p->>'reference_id','profile',ref.target_profile_code,'measurement',ref.target_measurement,
   'body_regions',p->'body_regions',
   'task',ref.reference->'task','goal_value',review->'target','baseline_work',work,'signature',p->'dose'->'targets',
   'phase',p->>'phase','facts',facts,'decision',choice));
 end loop;
 -- Carrera usa la misma decisión de información, sin cambiar su catálogo,
 -- rotación, dosis o progresión ordinaria. El control sustituye una salida.
 if plan->'running' is not null and plan->'running'<>'null'::jsonb then
  p:=plan->'running';
  select rs.prescription->'control'||jsonb_build_object('date',sw.scheduled_date) into attempt
   from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
   where sw.preparation_goal_id=goal and sw.user_id=auth.uid() and sw.scheduled_date<wk and sw.status<>'cancelled'
    and rs.prescription ? 'control' order by sw.scheduled_date desc limit 1;
  since_on:=greatest(coalesce((attempt->>'date')::date,'1900-01-01'),(p->>'reference_completed_at')::timestamptz::date);
  select count(*) filter(where o->'signal'->>'status'='tolerated'),count(*) filter(where o->'signal'->>'status'='tolerated' and (o->>'date')::date>=wk-14),count(*) filter(where o->'signal'->>'status'='tolerated' and (o->>'date')::date>since_on),
   coalesce(bool_or(o->'signal'->>'status'<>'tolerated') filter(where (o->>'date')::date>=wk-14),false)
  into n,recent,fresh,bad from jsonb_array_elements(p->'evidence'->'observations') o
   where (o->>'date')::date between wk-42 and wk-1 and o->'signal'->>'status' in ('tolerated','struggle','pain','unknown','off_intent');
  select ctx.health_observed_at>=now()-interval '30 days' and not ctx.reports_pain and not ctx.requires_professional_review
   and ctx.comfortable_continuous_minutes>=30 into healthy from public.running_intake_contexts ctx where preparation_goal_id=goal;
  facts:=jsonb_build_object('supported',true,'phase',p->>'phase','days_left',target-wk,'healthy',healthy,
   'adverse',bad or p->>'mode' in ('global_deload','intensity_deload','reentry','taper') or p->>'outcome'='reduce',
   'tolerated_days',n,'recent_days',recent,'new_days',fresh,'has_mark',true,'attempt_phase',attempt->>'phase',
   'target_met',(p->>'anchor_seconds')::numeric<=(p->'goal'->>'seconds')::numeric,
   'growth',round((p->>'normal_budget')::numeric/nullif(coalesce((attempt->>'baseline_work')::numeric,(p->>'normal_budget')::numeric),0),4),
   'anchor_blocks_quality',(coalesce((p->>'control_due')::boolean,false)
      or wk+6-(p->>'reference_completed_at')::timestamptz::date>30) and p->>'mode'='normal',
   'plateau',false);
  out:=out||jsonb_build_array(jsonb_build_object('objective_key','running_2000m_v1','name','Control de 2 km',
   'profile','running_2000m_v1','measurement','TIME_FOR_DISTANCE','phase',p->>'phase',
   'baseline_work',p->'normal_budget','facts',facts,'decision',public.adaptive_control_decision_v1(facts)));
 end if;
 return out;
end $$;

create function public.apply_adaptive_protocol_controls_v1(goal uuid,wk date,plan jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare candidates jsonb; c jsonb; s jsonb; r jsonb; w jsonb; source_work jsonb; local_work jsonb; task jsonb; dose jsonb; meta jsonb; out_sessions jsonb;
 items jsonb; updated jsonb; chosen date; day date; m text; cap numeric; oldcost int; newcost int; delta int; total int;
 reserved int; exam_date date; share_undo int; standalone int; used boolean:=false; recovery_removed jsonb:='[]'; record jsonb;
begin
 if plan->>'status'<>'ready' or plan->>'already_published'='true' then return plan; end if;
 candidates:=public.adaptive_control_candidates_v1(goal,wk,plan);
 select target_date into exam_date from public.preparation_goals where id=goal and user_id=auth.uid();
 for c in select value from jsonb_array_elements(candidates) where value->'decision'->>'action'='control'
  order by case when value->>'profile'='running_2000m_v1' and value->'decision'->>'reason'='reference_limits_training' then 0 else 1 end,
   value->>'objective_key' loop
  chosen:=null; m:=c->>'measurement';
  if c->>'profile'='running_2000m_v1' then
   for r in select value from jsonb_array_elements(plan->'running'->'sessions')
    order by case when value->>'kind'='controlled_quality' then 0 else 1 end,value->>'date' loop
    day:=(r->>'date')::date;
    if day<current_date or exam_date-day<=14 then continue; end if;
    reserved:=greatest(600,ceil((plan->'running'->>'anchor_seconds')::numeric*1.25)::int);
    if (r->>'minutes')::int*60<600+reserved+360 then continue; end if;
    if exists(select 1 from jsonb_array_elements(plan->'running'->'sessions') other where other->>'date'<>r->>'date'
     and other->>'family'<>'E' and abs((other->>'date')::date-day)<3) then continue; end if;
    if public.adaptive_control_prior_load_conflict_v1(day,wk) then continue; end if;
    chosen:=day; exit;
   end loop;
  else
   select item into source_work from jsonb_array_elements(plan->'sessions') session,
    jsonb_array_elements(session->'work') item where item->>'objective_key'=c->>'objective_key'
     and item->>'optional' is distinct from 'true' order by session->>'date' limit 1;
   if source_work is null then continue; end if;
   for s in select value from jsonb_array_elements(plan->'sessions') order by value->>'date' loop
    select value into local_work from jsonb_array_elements(s->'work') where value->>'objective_key'=c->>'objective_key' and value->>'optional' is distinct from 'true' limit 1;
    w:=coalesce(local_work,source_work);
    day:=(s->>'date')::date;
    if day<current_date or exam_date-day<=14 then continue; end if;
    if exists(select 1 from jsonb_array_elements(coalesce(plan->'running'->'sessions','[]')) run
     where run->>'family'<>'E' and abs((run->>'date')::date-day)<3) then continue; end if;
    if public.adaptive_control_prior_load_conflict_v1(day,wk) then continue; end if;
    cap:=case when m='DURATION' then least(600,greatest(60,coalesce((c->>'goal_value')::numeric,240)))
      when m='TIME_FOR_COURSE' then greatest(30,(w->'dose'->'targets'->>0)::numeric)
      when m='REPS_IN_TIME' then 1 else greatest(1,coalesce((c->>'goal_value')::numeric,100)) end;
    task:=(c->'task')-array['target_rir','target_rpe','fixed_duration_seconds','stimulus_code','records_stimulus_responses'];
    task:=task||jsonb_build_object('schema_version',1,'policy_version','adaptive_protocol_control_v1','intent','control',
     'exercise_code',c->>'profile','measurement',m,'target_value',cap,'effort_mode','rpe','target_rpe',10);
    if m='REPS_IN_TIME' then task:=task||jsonb_build_object('fixed_duration_seconds',case when c->>'objective_key'='legacy:upper_body_push_ups_2_min' then 120 else (c->'task'->>'fixed_duration_seconds')::numeric end,
      'protocol_key',case when c->>'objective_key'='legacy:upper_body_push_ups_2_min' then 'def_15_2026_push_ups_2min' else c->'task'->>'protocol_key' end); end if;
    task:=task||jsonb_build_object('instructions',case m
     when 'REPS_IN_TIME' then 'Control de flexiones en la ventana indicada. Cuenta solo repeticiones válidas del protocolo. No hay un número que debas alcanzar. Para si pierdes la técnica o aparecen molestias. Solo completar la ventana permite comparar la marca; un intento parcial queda como práctica, sin estimar un máximo.'
     when 'DURATION' then 'Control de plancha con los mismos apoyos y postura del protocolo. Mantén mientras la postura sea válida; termina al perderla o al alcanzar el techo de tiempo. No fuerces segundos con mala técnica. Alcanzar el techo acredita al menos ese tiempo, no tu máximo exacto.'
     when 'TIME_FOR_COURSE' then 'Un intento del recorrido completo ya practicado, con el montaje y reglas del protocolo. Prepara y ensaya la salida sin fatiga. Registra el tiempo bruto real; si alteras el recorrido, desplazas obstáculos o pierdes la pelota, marca el intento como no válido. No repitas para perseguir un récord.'
     else 'Control de repeticiones válidas del protocolo, sin una cifra que debas conseguir. Detente antes de perder la técnica o si aparecen molestias. No conviertas repeticiones inválidas en marca.' end);
    dose:=jsonb_build_object('task',task,'targets',jsonb_build_array(cap),'rest_seconds',0);
    oldcost:=case when local_work is null then 0 else ceil(public.performance_work_seconds_v2(w->'dose')/60.0)::int end;
    newcost:=ceil(public.performance_work_seconds_v2(dose)/60.0)::int;
    total:=coalesce((s->>'minutes')::int,0)+coalesce((select (run->>'minutes')::int from jsonb_array_elements(coalesce(plan->'running'->'sessions','[]')) run where run->>'date'=s->>'date'),0);
    -- Un control va antes del rodaje fácil. Si este no tiene calentamiento
    -- propio, no se puede conservar el ahorro de prepararse corriendo primero.
    share_undo:=case when s->>'combined'='true' and s->>'session_order'='running_first'
      and not exists(select 1 from jsonb_array_elements(coalesce(plan->'running'->'sessions','[]')) run,
        jsonb_array_elements(run->'segments') seg where run->>'date'=s->>'date' and seg->>'role'='warmup') then 4 else 0 end;
    if total+greatest(0,newcost-oldcost)+share_undo>coalesce((plan->'availability'->>extract(isodow from day)::int::text)::int,0) then continue; end if;
    chosen:=day; exit;
   end loop;
  end if;
  if chosen is null then continue; end if;
  meta:=(c-'facts'-'task'-'decision')||jsonb_build_object('version','adaptive_protocol_control_v1','kind','protocol_test',
    'question',c->'decision'->>'question','reason',c->'decision'->>'reason','replaces','ordinary_work',
    'date',chosen,'updates','training_protocol_mark','official_assessment',false);
  out_sessions:='[]';
  for s in select value from jsonb_array_elements(plan->'sessions') loop
   items:='[]'; delta:=0;
   if c->>'profile'<>'running_2000m_v1' and (s->>'date')::date=chosen then
    dose:=dose||jsonb_build_object('control',meta);
    items:=jsonb_build_array(source_work||jsonb_build_object('name','Control · '||(c->>'name'),'control',meta,'dose',dose,'outcome','control'));
    delta:=ceil(public.performance_work_seconds_v2(dose)/60.0)::int; used:=true;
   end if;
   for w in select value from jsonb_array_elements(s->'work') loop
    oldcost:=ceil(public.performance_work_seconds_v2(w->'dose')/60.0)::int;
    if c->>'profile'<>'running_2000m_v1' and w->>'objective_key'=c->>'objective_key' then
     delta:=delta-oldcost;
    elsif abs((s->>'date')::date-chosen)<2 and (c->>'profile'='running_2000m_v1' or
      exists(select 1 from jsonb_array_elements_text(w->'body_regions') reg where c->'body_regions' ? reg)) then
     delta:=delta-oldcost;
     recovery_removed:=recovery_removed||jsonb_build_array(jsonb_build_object('name',w->>'name','date',s->>'date','reason','recovery_around_protocol_control'));
    else items:=items||jsonb_build_array(w); end if;
   end loop;
   if jsonb_array_length(items)>0 then
    standalone:=greatest(1,coalesce((s->>'standalone_minutes')::int,(s->>'minutes')::int)+delta);
    updated:=s||jsonb_build_object('work',items,'minutes',standalone,'standalone_minutes',standalone);
    if (s->>'date')::date=chosen then updated:=updated||jsonb_build_object('session_order','performance_first'); end if;
    select value into r from jsonb_array_elements(coalesce(plan->'running'->'sessions','[]')) run where run->>'date'=s->>'date';
    if r is not null then
     total:=public.preparation_shared_minutes_v2(updated,r);
     updated:=updated||jsonb_build_object('minutes',total-(r->>'minutes')::int,'shared_total_minutes',total,
      'warm_up_seconds',case when updated->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r->'segments') seg where seg->>'role'='warmup') then 180 else 420 end);
    end if;
    out_sessions:=out_sessions||jsonb_build_array(updated);
   end if;
  end loop;
  plan:=jsonb_set(plan,'{sessions}',out_sessions);
  if c->>'profile'='running_2000m_v1' then
   task:=jsonb_build_object('schema_version',1,'exercise_code','running_2000m_v1','exercise_version',1,
    'protocol_key','run_2000m_v1','protocol_version',1,'setup_key','standard:measured_2000m',
    'measurement','TIME_FOR_DISTANCE','load_mode','bodyweight','policy_version','adaptive_protocol_control_v1',
    'target_value',(plan->'running'->>'anchor_seconds')::numeric,'fixed_distance_meters',2000,'intent','control','effort_mode','rpe','target_rpe',10,
    'instructions','Control de 2 km en una distancia medida y condiciones repetibles. Calienta y termina suavemente. Corre de forma regular: no hay un tiempo que debas alcanzar hoy. Si no estás recuperado, omite el control; detente ante molestias. Registra el tiempo real de los 2 km y tu esfuerzo, sin estimar una marca desde una distancia parcial.');
   select coalesce(jsonb_agg(case when (run->>'date')::date=chosen then run||jsonb_build_object(
    'name','Control de 2 km','family','C','kind','controlled_quality','variant_code','CONTROL_2000_v1','control',meta,
    'rpe_ceiling',10,'work_seconds',reserved,'description',task->>'instructions','segments',jsonb_build_array(
     jsonb_build_object('role','warmup','seconds',600),jsonb_build_object('role','work','meters',2000,'performance_prescription',task),
     jsonb_build_object('role','cooldown','seconds',(run->>'minutes')::int*60-600-reserved))) else run end order by run->>'date'),'[]')
    into updated from jsonb_array_elements(plan->'running'->'sessions') run;
   plan:=jsonb_set(plan,'{running,sessions}',updated); used:=true;
  end if;
  exit; -- Techo de carga de evaluación, no cadencia: como máximo una por semana.
 end loop;
 return plan||jsonb_build_object('control_policy_version','adaptive_protocol_control_v1','control_schedule',
  jsonb_build_object('scheduled',case when used then jsonb_build_array(meta) else '[]'::jsonb end,
    'reviewed',candidates,'recovery_adjustments',recovery_removed));
end $$;

-- Un vínculo interno a la serie conserva procedencia y permite corrección
-- idempotente. No se crean evaluaciones oficiales ni se cambia el baremo.
alter table public.preparation_running_tests add column source_execution_set_id uuid unique
 references public.workout_execution_sets(id) on delete cascade;

create function public.sync_automatic_running_controls_v1(goal uuid) returns void
language plpgsql security definer set search_path='' as $$
declare x record; rid uuid; latest timestamptz; chosen timestamptz;
begin
 if not exists(select 1 from public.preparation_goals where id=goal and user_id=auth.uid()) then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 for x in select es.id,es.performance_result r,e.id execution_id,coalesce(e.performed_at,e.completed_at) completed_at,
   es.performance_prescription p from public.workout_execution_sets es join public.workout_executions e on e.id=es.execution_id
  join public.scheduled_workouts sw on sw.execution_id=e.id join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  where sw.preparation_goal_id=goal and sw.user_id=auth.uid() and es.status='completed'
   and e.status in ('completed','abandoned') and public.workout_block_outcome_v1(e.id,es.block_order)->>'status'='completed'
   and rs.prescription ? 'control' and es.performance_prescription->>'protocol_key'='run_2000m_v1'
   and public.adaptive_control_result_valid_v1(es.performance_prescription,es.performance_result)
   and (es.performance_result->>'value')::numeric between 240 and 1800
   and (es.performance_result->>'rpe')::numeric between 1 and 10 and coalesce(e.performed_at,e.completed_at)<=now()
  order by coalesce(e.performed_at,e.completed_at) loop
  insert into public.preparation_running_tests(user_id,preparation_goal_id,completed_at,duration_seconds,rpe,notes,source_execution_set_id)
   values(auth.uid(),goal,x.completed_at,ceil((x.r->>'value')::numeric)::int,(x.r->>'rpe')::numeric::int,
     'Control pautado automáticamente; resultado de entrenamiento, no evaluación oficial.',x.id)
   on conflict(source_execution_set_id) do update set duration_seconds=excluded.duration_seconds,rpe=excluded.rpe
   returning id into rid;
  begin chosen:=(public.resolve_program_running_reference(goal)->>'completed_at')::timestamptz;
   exception when others then chosen:=null; end;
  if chosen is null or x.completed_at>chosen then
   update public.running_reference_selections set reference_source='trainingControl',reference_record_id=rid::text,continuity_confirmed_at=null where preparation_goal_id=goal;
  end if;
 end loop;
end $$;

create function public.protect_automatic_running_control_source_v1() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.source_execution_set_id is not null and not exists(
  select 1 from public.workout_execution_sets es join public.workout_executions e on e.id=es.execution_id
   join public.scheduled_workouts sw on sw.execution_id=e.id join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  where es.id=new.source_execution_set_id and e.user_id=new.user_id and new.user_id=auth.uid() and sw.preparation_goal_id=new.preparation_goal_id
   and e.status in ('completed','abandoned') and es.status='completed' and rs.prescription ? 'control'
   and es.performance_prescription->>'protocol_key'='run_2000m_v1'
   and public.adaptive_control_result_valid_v1(es.performance_prescription,es.performance_result)
   and ceil((es.performance_result->>'value')::numeric)::int=new.duration_seconds
   and (es.performance_result->>'rpe')::numeric=new.rpe and coalesce(e.performed_at,e.completed_at)=new.completed_at) then
  raise exception 'El origen del control no acredita esta marca.' using errcode='23514'; end if;
 return new;
end $$;
create trigger protect_automatic_running_control_source before insert or update on public.preparation_running_tests
 for each row execute function public.protect_automatic_running_control_source_v1();

revoke all on function public.running_continuity_observed_v1(uuid,date),public.adaptive_control_decision_v1(jsonb),public.adaptive_control_result_valid_v1(jsonb,jsonb),
 public.adaptive_protocol_observations_v1(uuid),public.adaptive_control_candidates_v1(uuid,date,jsonb),
 public.adaptive_control_prior_load_conflict_v1(date,date),
 public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb),public.sync_automatic_running_controls_v1(uuid),
 public.protect_automatic_running_control_source_v1() from public,anon,authenticated;
