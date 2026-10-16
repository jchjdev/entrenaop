begin;

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


create or replace function public.calculate_preparation_week_training_v4(p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[])
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
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and not (r.target_profile_code='front_plank_forearms' and r.reference->'task'->>'exercise_code'='dead_bug')
    and coalesce(r.reference->>'reference_kind','')<>'guided_pending'
    and (not r.reference ? 'automatic_support' or public.performance_support_source_valid_v2(r.reference)) and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
   select coalesce(jsonb_agg(jsonb_build_object('execution_id',e.id,'completed_on',public.workout_performed_on_v1(e),'scheduled_date',sw.scheduled_date,
     'status',public.workout_block_outcome_v1(e.id,pw.block_order)->>'status',
     'abandonment_reason',public.workout_block_outcome_v1(e.id,pw.block_order)->>'abandonment_reason','dose',pw.dose,'sets',sets.items) order by coalesce(e.performed_at,e.completed_at),e.id),'[]') into history
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   join public.workout_executions e on e.id=sw.execution_id
   join lateral(select jsonb_agg(jsonb_build_object('status',es.status,'prescription',es.performance_prescription,
     'result',es.performance_result) order by es.set_order) items from public.workout_execution_sets es
     where es.execution_id=e.id and es.block_order=pw.block_order) sets on true
   where pw.reference_id=ref.id and not pw.dose ? 'control' and public.workout_performed_on_v1(e)<p_week_start and public.workout_performed_on_v1(e)>=p_week_start-56;
   select value into prior from jsonb_array_elements(coalesce(previous.decision->'proposals','[]'))
     where value->>'reference_id'=ref.id::text or value->'covered_reference_ids' ? ref.id::text limit 1;
   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) then
     proposal:=jsonb_build_object('status','needs_equipment','reason','Falta material para esta variante; usa una alternativa calibrada compatible.');
   else proposal:=public.performance_task_v5(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end,started_on); end if;
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

 if p_scope<>'running' then proposals:=public.performance_support_candidates_v2(p_goal_id,p_week_start,proposals); end if;

 select coalesce(jsonb_agg(p||jsonb_build_object('goal_review',review,'goal_priority',coalesce((review->>'priority')::int,1))),'[]')
  into proposals from jsonb_array_elements(proposals) p left join lateral(
   select value review from jsonb_array_elements(public.performance_goal_reviews_v1(p_goal_id,p_week_start))
    where value->>'objective_key'=p->>'objective_key') r on true;
 proposals:=public.performance_select_v4(proposals);
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
     ||jsonb_build_object('automatic_references',coalesce(jsonb_agg(p->'automatic_reference') filter(where p ? 'automatic_reference'),'[]'),
     'goal_priority',min(coalesce((p->>'goal_priority')::int,1)),
     'covered_reference_ids',jsonb_agg(p->'reference_id'),'covered_objective_keys',jsonb_agg(p->'objective_key'),'frequency',max((p->>'frequency')::int)) proposal
   from jsonb_array_elements(proposals) p where p->>'status'='ready' group by p->'dose',p->'exposure_doses',p->'frequency'
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
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'),
   'recovery_days',coalesce((select max((public.performance_frequency_strategy_v2(jsonb_build_object('dose',pw.dose))->>'recovery_days')::int)
     from public.performance_week_work pw where pw.scheduled_workout_id=sw.id),2))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-7 and p_week_start+13
     and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',public.workout_load_on_v1(sw)-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-7 and p_week_start+13
   and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=p_scope<>'performance' and (exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry'));
 -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and (q->>'objective_key'=p->>'objective_key' or q->'covered_objective_keys' ? (p->>'objective_key') or p->'covered_objective_keys' ? (q->>'objective_key'))
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
 for frequency_limit in reverse coalesce((select max((p->>'frequency')::int) from jsonb_array_elements(proposals) p where p->>'status'='ready'),1)..0 loop
 select coalesce(jsonb_agg(public.performance_frequency_candidate_v2(p,frequency_limit)),'[]') into candidates from jsonb_array_elements(proposals) p where include_support or p->>'optional' is distinct from 'true';
 for rotation in 0..6 loop
   candidate:=public.performance_place_v4(candidates,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
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
 select coalesce(jsonb_agg(w),'[]') into coordinated from (select distinct on (w->>'reference_id') w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w order by w->>'reference_id',(w->>'exposure_index')::int) chosen;
 -- Persistir exposiciones entregadas, no una frecuencia deseada que no cupo.
 select coalesce(jsonb_agg(p||jsonb_build_object('frequency',
   (select count(*) from jsonb_each(best->'days') d,jsonb_array_elements(d.value->'work') w
    where w->>'reference_id'=p->>'reference_id'),
   'exposure_doses',(select jsonb_agg(w->'dose' order by (w->>'exposure_index')::int) from jsonb_each(best->'days') d,
     jsonb_array_elements(d.value->'work') w where w->>'reference_id'=p->>'reference_id'))),'[]') into coordinated
 from jsonb_array_elements(coordinated) p;
 coordinated:=public.performance_coordinate_progression_v3(coordinated,best_running,p_week_start);
 select coalesce(jsonb_agg(public.performance_reconcile_exposures_v2(p)),'[]') into coordinated from jsonb_array_elements(coordinated) p;
 select coordinated||coalesce(jsonb_agg(p||jsonb_build_object('allocation_status','not_scheduled','allocation_reason','Se conserva la referencia, pero esta semana tiene prioridad la cobertura específica, carrera y recuperación.')),'[]') into coordinated from jsonb_array_elements(proposals) p
 where not exists(select 1 from jsonb_array_elements(coordinated) c where c->>'reference_id'=p->>'reference_id');
 -- Mantener una dosis solo reduce el coste ya reservado; nunca rellena ese margen.
 for d in 1..7 loop
   select coalesce(jsonb_agg(c order by w.ordinality),'[]') into session from jsonb_array_elements(best->'days'->d::text->'work') with ordinality w(value,ordinality)
     join lateral(select public.performance_exposure_v2(value,coalesce((w.value->>'exposure_index')::int,0)) c from jsonb_array_elements(coordinated) c where c->>'reference_id'=w.value->>'reference_id') q on true;
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
   'policy_version','preparation_coordinator_v4','evidence_policy_version','adaptive_evidence_v1','frequency_policy_version','performance_frequency_v2','support_policy_version','support_v2','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'goal_reviews',case when p_scope='running' then '[]'::jsonb else public.performance_goal_reviews_v1(p_goal_id,p_week_start) end,'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

create or replace function public.calculate_preparation_week_for_scope(
 p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare plan jsonb;
begin
 plan:=public.calculate_preparation_week_training_v4(p_goal_id,p_week_start,p_revision,p_scope,p_excluded);
 return public.apply_adaptive_protocol_controls_v1(p_goal_id,p_week_start,plan);
end $$;

create or replace function public.materialize_running_week_plan(p_goal_id uuid,p_week_start date,p_plan jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); gid uuid; existing public.running_week_decisions%rowtype;
 plan jsonb; s jsonb; segment jsonb; decision_id uuid; template_id uuid;
 block_id uuid; item_id uuid; schedule_id uuid; idx integer;
begin
 if u is null then raise exception 'Authentication required'; end if;
 select id into gid from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active' for update;
 if not found then raise exception 'Active running preparation not found'; end if;
 select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 if found then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
 plan:=p_plan;
 insert into public.running_week_decisions(user_id,preparation_goal_id,week_start,policy_version,basis,
   outcome,reference_source,reference_record_id,input_snapshot,decision)
 values(u,p_goal_id,p_week_start,plan->>'policy_version',plan->>'basis',plan->>'outcome',
   plan->>'reference_source',plan->>'reference_record_id',plan-'sessions',plan) returning id into decision_id;
 for s in select value from jsonb_array_elements(plan->'sessions') loop
   insert into public.workout_templates(name,description,origin,owner_user_id,visibility,status,estimated_duration_minutes,version)
   values(s->>'name',s->>'description','algorithm',u,'private','published',(s->>'minutes')::integer,1) returning id into template_id;
   insert into public.workout_blocks(template_id,order_index,name,format)
   values(template_id,0,s->>'name','running') returning id into block_id;
   insert into public.workout_items(block_id,exercise_id,order_index,notes)
   values(block_id,'20000000-0000-4000-8000-000000000004',0,
     (s->>'description')||' Esfuerzo orientativo máximo: '||(s->>'rpe_ceiling')||'/10.') returning id into item_id;
   idx:=0;
   for segment in select value from jsonb_array_elements(s->'segments') loop
     insert into public.workout_sets(item_id,order_index,target_duration_seconds,target_distance_meters,
       target_pace_min_seconds_per_km,target_pace_max_seconds_per_km,recovery_type,recovery_duration_seconds,performance_prescription)
     values(item_id,idx,(segment->>'seconds')::integer,(segment->>'meters')::numeric,
       (segment->>'pace_min')::integer,(segment->>'pace_max')::integer,
       case when segment ? 'recovery_seconds' then coalesce(segment->>'recovery_type','jogging') end,(segment->>'recovery_seconds')::integer,segment->'performance_prescription');
     idx:=idx+1;
   end loop;
   insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,
     estimated_duration_minutes,preparation_goal_id,scheduled_date,source,status)
   values(u,template_id,s->>'name',1,(s->>'minutes')::integer,p_goal_id,(s->>'date')::date,'algorithm','planned') returning id into schedule_id;
   insert into public.running_week_sessions(decision_id,scheduled_workout_id,kind,planned_minutes,variant_code,prescription)
   values(decision_id,schedule_id,s->>'kind',(s->>'minutes')::integer,s->>'variant_code',s);
 end loop;
 return plan||jsonb_build_object('decision_id',decision_id,'already_published',false);
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
 perform public.sync_automatic_running_controls_v1(p_goal_id);
 select * into a from public.adaptive_program_states where preparation_goal_id=p_goal_id for update;
 if not found or not a.auto_advance then return coalesce(to_jsonb(a),'{}'); end if;
 -- Caducar Pro conserva el estado y las sesiones, pero detiene la generación.
 if not public.has_pro_access(auth.uid()) then return to_jsonb(a); end if;
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
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb; capacity_evidence jsonb;
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
 if age>30 and age<=45 and not public.running_continuity_observed_v1(p_goal_id,current_date) and (ref.continuity_confirmed_at is null
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
 where sw.user_id=u and sw.status not in ('cancelled') and wd.policy_version in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') and not coalesce(rs.prescription,'{}'::jsonb) ? 'control'
   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56
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
 capacity_evidence:=public.running_capacity_observed_v1(p_goal_id,p_week_start);
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,
   'capacity_minutes',capacity_evidence->'trial_minutes','capacity_evidence',capacity_evidence,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 -- El coordinador puede solicitar otra propuesta con el tiempo restante.
 -- La selección deportiva sigue en v5; la evidencia usa la realización real.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 result:=public.running_plan_v5(input);
 return result||jsonb_build_object('capacity_evidence',capacity_evidence,'evidence_policy_version','adaptive_evidence_v1','goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

create or replace function public.resolve_program_running_reference(p_goal_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 sel public.running_reference_selections%rowtype; r record; selected_test uuid;
 standard jsonb; controls jsonb:='[]'; n int;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 select * into sel from public.running_reference_selections where preparation_goal_id=g.id;
 if not found then raise exception 'Choose a compatible 2 km mark in this preparation'; end if;
 if g.program_id='fas_periodic_assessment' and sel.reference_source='fasPeriodicAssessment' then
   select a.completed_at,m.value/1000.0 seconds into r from public.fas_periodic_assessments a
   join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select jsonb_build_object('seconds',s.threshold/1000.0,'catalog_version',a.catalog_version,
     'category',a.category,'age_band',a.age_band,'scope','minimum_20_points_not_global_pass') into standard
   from public.fas_periodic_assessments a join public.fas_periodic_standards s
     on s.catalog_version=a.catalog_version and s.category=a.category and s.age_band=a.age_band and s.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
     'protocol',a.catalog_version||':run_2000_m') order by a.completed_at),'[]') into controls
   from public.fas_periodic_assessments a join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.preparation_goal_id=g.id and a.user_id=u and a.completed_at<=r.completed_at and a.completed_at<=now();
 elsif g.program_id='armed_forces_troop_entry' and sel.reference_source='troopOfficialAssessment' then
   select a.completed_at,m.value/1000.0 seconds into r from public.physical_assessments a
   join public.physical_assessment_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select jsonb_build_object('seconds',s.threshold/1000.0,'catalog_version',a.catalog_version,
     'category',a.category,'scope','test_minimum_not_global_pass') into standard
   from public.physical_assessments a join public.assessment_standards s
   on s.catalog_version=a.catalog_version and s.category=a.category and s.milestone=a.milestone and s.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
     'protocol',a.catalog_version||':run_2000_m') order by a.completed_at),'[]') into controls
   from public.physical_assessments a join public.physical_assessment_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.preparation_goal_id=g.id and a.user_id=u and a.completed_at<=r.completed_at and a.completed_at<=now();
 elsif sel.reference_source='trainingControl' or (g.program_id='armed_forces_troop_entry' and sel.reference_source='troopControl') then
   if g.program_id not in ('fas_periodic_assessment','armed_forces_troop_entry') and not exists(select 1 from public.program_training_modules where program_id=g.program_id and module_key='running_2000m_v1') then raise exception 'Este programa no tiene preparación de 2 km.'; end if;
   select t.completed_at,t.duration_seconds::numeric seconds into r from public.preparation_running_tests t
   where t.id::text=sel.reference_record_id and t.user_id=u and t.preparation_goal_id=g.id and t.protocol_version='run_2000m_v1';
   select coalesce(jsonb_agg(jsonb_build_object('date',t.completed_at::date,'seconds',t.duration_seconds,
     'protocol',t.protocol_version) order by t.completed_at),'[]') into controls
   from public.preparation_running_tests t where t.user_id=u and t.preparation_goal_id=g.id
     and t.completed_at<=r.completed_at and t.completed_at<=now();
   -- Un control sin evaluación no inventa categoría ni umbral oficial.
 elsif sel.reference_source='programAssessment' then
   select count(*) into n from public.program_assessment_attempts a
   cross join lateral jsonb_array_elements(a.result->'details') d
   join public.program_training_modules tm on tm.test_id::text=d->>'test_id' and tm.program_id=g.program_id and tm.module_key='running_2000m_v1'
   join public.preparation_programs pp on pp.id=tm.program_id and pp.enabled
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
   if n<>1 then raise exception 'Choose one unambiguous module-linked 2 km result'; end if;
   select a.assessed_on::timestamptz completed_at,(d->>'mark')::numeric seconds,
     (d->>'test_id')::uuid test_id,jsonb_build_object('seconds',(d->>'minimum_mark')::numeric,
       'catalog_version',a.scoring_version,'category',a.category,'age',a.result->'age',
       'scope','test_minimum_not_global_pass') official into r
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   join public.program_training_modules tm on tm.test_id::text=d->>'test_id' and tm.program_id=g.program_id and tm.module_key='running_2000m_v1'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
   selected_test:=r.test_id; standard:=r.official;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.assessed_on,'seconds',(d->>'mark')::numeric,
     'protocol','run_2000m_v1:'||selected_test::text) order by a.assessed_on),'[]') into controls
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   where a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id and d->>'test_id'=selected_test::text
     and a.assessed_on<=r.completed_at::date and a.assessed_on<=current_date
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
 else raise exception 'Reference source does not belong to this running program'; end if;
 if sel.reference_source='trainingControl' and exists(
  select 1 from public.preparation_running_tests t left join public.workout_execution_sets es on es.id=t.source_execution_set_id
  where t.id::text=sel.reference_record_id and t.source_execution_set_id is not null
   and (es.status<>'completed' or not public.adaptive_control_result_valid_v1(es.performance_prescription,es.performance_result))) then
  raise exception 'Choose a compatible 2 km mark: the automatic control was corrected or invalidated';
 end if;
 if r.completed_at is null or r.seconds is null or r.seconds not between 240 and 1800 then
   raise exception 'Choose a compatible 2 km mark in this preparation'; end if;
 return jsonb_build_object('reference_source',sel.reference_source,'reference_record_id',sel.reference_record_id,
   'continuity_confirmed_at',sel.continuity_confirmed_at,'completed_at',r.completed_at,'value',r.seconds*1000,
   'standard',standard,'controls',controls);
end $$;

create or replace function public.performance_goal_reviews_v1(goal uuid,wk date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare g public.preparation_goals%rowtype; item record; objective jsonb; setup jsonb;
 result jsonb:='[]'; mark numeric; measured date; source_id text; test_key text; fresh boolean; met boolean; automatic jsonb;
begin
 select * into g from public.preparation_goals where id=goal and user_id=auth.uid();
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 setup:=public.get_preparation_training_setup_base(goal);
 for item in select key,value from jsonb_each(coalesce((select objective_targets from public.adaptive_program_states
    where preparation_goal_id=goal),'{}')) loop
  select value into objective from jsonb_array_elements(setup->'objectives') where value->>'objective_key'=item.key;
  if objective is null or objective->>'measurement'<>item.value->>'measurement' then continue; end if;
  mark:=null; measured:=null; source_id:=null;
  if g.program_id='fas_periodic_assessment' and item.key like 'legacy:%' then
   test_key:=substr(item.key,8);
   select case when item.value->>'measurement' in ('DURATION','TIME_FOR_COURSE') then m.value/1000.0 else m.value end,
    a.completed_at::date,a.id::text into mark,measured,source_id
   from public.fas_periodic_assessments a join public.fas_periodic_marks m on m.assessment_id=a.id
   where a.user_id=auth.uid() and a.preparation_goal_id=goal and m.test_id=test_key
    and a.completed_at::date<=least(current_date,wk+6)
   order by a.completed_at desc,a.id limit 1;
  elsif objective->>'test_id' is not null then
   select (d->>'mark')::numeric,a.assessed_on,a.id::text into mark,measured,source_id
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   where a.user_id=auth.uid() and a.preparation_goal_id=goal and a.program_id=g.program_id
    and d->>'test_id'=objective->>'test_id' and not coalesce((d->>'invalid')::boolean,false)
    and a.assessed_on<=least(current_date,wk+6) order by a.assessed_on desc,a.created_at desc limit 1;
  end if;
  select value into automatic from jsonb_array_elements(public.adaptive_protocol_observations_v1(goal))
   where value->>'objective_key'=item.key and value->>'measurement'=item.value->>'measurement'
    and (value->>'observed_on')::date<=least(wk+6,current_date) order by value->>'observed_on' desc limit 1;
  if automatic is not null and (measured is null or (automatic->>'observed_on')::date>=measured) then
   mark:=(automatic->>'value')::numeric; measured:=(automatic->>'observed_on')::date; source_id:=automatic->>'id';
  else automatic:=null; end if;
  fresh:=mark is not null and measured>=wk-42;
  met:=case when mark is null then null when item.value->>'measurement'='TIME_FOR_COURSE'
    then mark<=(item.value->>'value')::numeric else mark>=(item.value->>'value')::numeric end;
  result:=result||jsonb_build_array(jsonb_build_object('objective_key',item.key,'name',objective->>'name',
   'measurement',item.value->>'measurement','target',item.value->'value','last_protocol_mark',mark,
   'observed_on',measured,'source_id',source_id,'recent_protocol_mark',fresh,
   'last_mark_meets_target',met,'priority',case when fresh and met then 2 when fresh and not met then 0 else 1 end,
   'control_kind','adaptive_protocol','updates','training_protocol_mark','official_assessment',false,
   'lower_bound',coalesce((automatic->>'lower_bound')::boolean,false),
   'review_reason',case when item.value->>'measurement'='REPS_IN_TIME' and not exists(
     select 1 from public.performance_training_references r where r.preparation_goal_id=goal and r.active
      and r.objective_key=item.key and r.reference->'task'->>'measurement'='REPS_IN_TIME') and automatic is null then
     'Tu trabajo libre mejora el movimiento, pero no acredita el ritmo de la prueba cronometrada. Conservamos su progresión; una práctica cronometrada compatible permitirá trabajar el ritmo sin repetir un máximo.'
    when mark is null then 'Aún no hay una marca compatible del protocolo. Las series de trabajo no se convierten en un máximo.'
    when not fresh then 'Esta es tu última marca del protocolo, no una estimación actual. Los entrenamientos siguen adaptándose desde tus registros; revisaremos la prueba cuando aporte información útil.'
    else 'La meta orienta la prioridad entre opciones compatibles; la dosis se adapta desde tu trabajo real, sin exigir hoy la marca deseada.' end));
 end loop;
 return result;
end $$;

create or replace function public.snapshot_performance_set() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    select s.performance_prescription into new.performance_prescription
      from public.workout_sets s where s.id = new.source_set_id;
  elsif new.performance_prescription is distinct from old.performance_prescription then
    raise exception 'La tarea de una ejecución es inmutable.';
  end if;
  if tg_op = 'UPDATE' and new.performance_prescription is not null
    and new.performance_result is not distinct from old.performance_result
    and (new.actual_reps,new.actual_duration_seconds,new.actual_distance_meters,new.actual_load_kg,new.actual_rir)
      is distinct from (old.actual_reps,old.actual_duration_seconds,old.actual_distance_meters,old.actual_load_kg,old.actual_rir) then
    raise exception 'Usa el registro deportivo para corregir esta tarea.';
  end if;
  if new.performance_prescription is not null then
    -- Proyección para las vistas antiguas; el decimal exacto permanece en JSON.
    new.actual_reps := case when new.performance_prescription->>'measurement'
      in ('REPS','LOAD_REPS','REPS_IN_TIME') then (new.performance_result->>'value')::integer end;
    new.actual_duration_seconds := case when new.performance_prescription->>'measurement'
      in ('DURATION','TIME_FOR_DISTANCE','TIME_FOR_COURSE','REACTIVE_METRICS')
      then floor((new.performance_result->>'value')::numeric)::integer end;
    new.actual_distance_meters := case when new.performance_prescription->>'measurement'
      in ('DISTANCE','HEIGHT') then (new.performance_result->>'value')::numeric end;
    new.actual_load_kg := case when new.performance_prescription->>'measurement' = 'MAX_LOAD'
      then (new.performance_result->>'value')::numeric else (new.performance_result->>'load_kg')::numeric end;
    new.actual_rir := (new.performance_result->>'rir')::numeric;
    if new.performance_prescription->>'policy_version'='adaptive_protocol_control_v1'
      and new.performance_prescription->>'measurement'='TIME_FOR_DISTANCE' then
     -- Solo una confirmación explícita del protocolo acredita la distancia fija.
     -- Un intento parcial/nulo conserva sus datos sin fabricar los 2 km.
     new.actual_distance_meters:=case when new.performance_result->>'conditions_confirmed'='true'
      then (new.performance_prescription->>'fixed_distance_meters')::numeric end;
     new.actual_rpe:=(new.performance_result->>'rpe')::numeric;
    end if;
  end if;
  return new;
end $$;

alter table public.workout_execution_sets drop constraint workout_execution_sets_running_result_complete;
alter table public.workout_execution_sets add constraint workout_execution_sets_running_result_complete check (
 status<>'completed' or block_format is distinct from 'running'
 or (actual_duration_seconds is not null and actual_distance_meters is not null)
 or coalesce((performance_prescription->>'policy_version'='adaptive_protocol_control_v1'
   and performance_prescription->>'measurement'='TIME_FOR_DISTANCE'
   and performance_prescription->>'protocol_key'='run_2000m_v1'
   and performance_prescription->>'intent'='control' and performance_result is not null),false)
);

revoke all on function public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[]) from public,anon,authenticated;

commit;
