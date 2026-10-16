-- Guarda común de máximos; no cambia la programación ordinaria.
begin;

create or replace function public.apply_adaptive_protocol_controls_v1(goal uuid,wk date,plan jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare candidates jsonb; c jsonb; s jsonb; r jsonb; w jsonb; source_work jsonb; local_work jsonb; task jsonb; dose jsonb; meta jsonb; out_sessions jsonb;
 items jsonb; updated jsonb; chosen date; day date; m text; cap numeric; oldcost int; newcost int; delta int; total int;
 reserved int; exam_date date; share_undo int; standalone int; used boolean:=false; recovery_removed jsonb:='[]'; record jsonb;
begin
 if plan->>'status'<>'ready' or plan->>'already_published'='true' then return plan; end if;
 -- Una descarga global o una revisión de datos no es una oportunidad para
 -- añadir un máximo de otra disciplina. El trabajo normal permanece intacto.
 if coalesce(plan->'running'->>'mode','') in ('global_deload','reentry')
   or coalesce((plan->'running'->>'rpe_review_required')::boolean,false)
   or (coalesce((plan->'running'->>'data_review_required')::boolean,false) and
     (not (plan->'running') ? 'evidence' or exists(
      select 1 from jsonb_array_elements(plan->'running'->'evidence'->'observations') o
      where (o->>'date')::date>=(plan->>'week_start')::date-7
       and o->'signal'->>'status' in ('unknown','missing')))) then
  return plan||jsonb_build_object('control_policy_version','adaptive_protocol_control_v1',
   'control_schedule',jsonb_build_object('scheduled','[]'::jsonb,'reviewed','[]'::jsonb,
    'reason','shared_recovery','recovery_adjustments','[]'::jsonb));
 end if;
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

commit;
