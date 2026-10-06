-- Dominio puro: no lee usuarios, agenda, tablas ni la fecha del servidor.
begin;

create function public.performance_policy_v1() returns jsonb
language sql immutable set search_path = '' as $$
select '{"version":"performance_v1","reference_days":14,"return_days":21,
  "comparable_exposures":2,"rep_increment":1,"duration_increment":2,
  "specific_days":28,"taper_days":7,"review_weeks":4,
  "warm_up_seconds":420,"transition_seconds":60,"cool_down_seconds":180,
  "parameter_status":"operational_requires_outcome_monitoring"}'::jsonb
$$;

create function public.performance_exposure_signal_v1(e jsonb,dose jsonb)
returns text language plpgsql immutable set search_path = '' as $$
declare s jsonb; p jsonb; r jsonb; m text; actual numeric; target numeric;
  unknown boolean:=false; difficulty boolean:=false; idx integer:=0;
begin
  if e->>'abandonment_reason'='discomfort' then return 'pain'; end if;
  if exists(select 1 from jsonb_array_elements(coalesce(e->'sets','[]')) x
    where x->'result'->>'stop_reason'='discomfort' or x->'result'->>'tolerated'='false') then
    return 'pain'; end if;
  if e->'dose' is distinct from dose then return 'different_dose'; end if;
  if e->>'abandonment_reason'='lack_of_time' then return 'time'; end if;
  if e->>'abandonment_reason'='too_difficult' then return 'difficulty'; end if;
  if e->>'status' <> 'completed' or jsonb_array_length(coalesce(e->'sets','[]')) <> jsonb_array_length(dose->'targets') then return 'unknown'; end if;
  for s in select value from jsonb_array_elements(e->'sets') loop
    p:=s->'prescription'; r:=s->'result'; m:=p->>'measurement';
    if s->>'status' <> 'completed' or r is null then return 'unknown'; end if;
    if r->>'stop_reason'='time' then return 'time'; end if;
    if r->>'conditions_confirmed' is distinct from 'true' then return 'different_conditions'; end if;
    if p->>'load_mode' in ('external_load','bodyweight_plus_external')
      and (r->'load_kg' is distinct from p->'external_load_kg') then return 'different_load'; end if;
    if p->>'load_mode'='assisted' and p->>'external_load_kg' is not null
      and r->'load_kg' is distinct from p->'external_load_kg' then return 'different_load'; end if;
    if p->>'load_mode'='bodyweight_plus_external' and r->'body_mass_kg' is distinct from p->'body_mass_kg' then return 'different_body_mass'; end if;
    if m='REPS_IN_TIME' and r->'actual_duration_seconds' is distinct from p->'fixed_duration_seconds' then return 'different_window'; end if;
    actual:=(r->>'value')::numeric; target:=(dose->'targets'->>idx)::numeric;
    if r->>'technique_valid'='false' or r->>'stop_reason'='difficulty' then difficulty:=true; end if;
    if r->>'technique_valid' is null or r->>'tolerated' is distinct from 'true'
      or coalesce(r->>'stop_reason','unknown')='unknown' then unknown:=true; end if;
    if m='PASS_FAIL' then
      if r->>'succeeded'='false' then difficulty:=true; end if;
      if r->>'succeeded' is null then unknown:=true; end if;
    elsif actual is null then unknown:=true;
    elsif dose->>'model' in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') then
      if actual<target then difficulty:=true; end if;
    end if;
    if dose->>'model' in ('repetitions','load_repetitions','timed_repetitions') then
      if r->>'rir' is null then unknown:=true;
      elsif (r->>'rir')::numeric < 2 then difficulty:=true;
      elsif (r->>'rir')::numeric < coalesce((p->>'target_rir')::numeric,3) then unknown:=true; end if;
    end if;
    idx:=idx+1;
  end loop;
  if difficulty then return 'difficulty'; end if;
  if unknown then return 'unknown'; end if;
  return 'tolerated';
end $$;

create function public.performance_task_v1(
  reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
  previous jsonb default '{}'::jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare cfg jsonb:=public.performance_policy_v1(); task jsonb:=reference->'task';
  dose jsonb; comparison_dose jsonb; baseline jsonb; targets jsonb; m text:=task->>'measurement'; model text;
  signals jsonb:='[]'; e jsonb; signal text; n int:=0; good int:=0; bad int:=0;
  phase text; outcome text:='maintain'; reason text; idx int; v numeric; step numeric;
  load numeric; minimum int; maximum int; freq int; last_on date; days_left int:=target_date-wk;
  fresh boolean; same_reference boolean; minutes int; work_seconds numeric; rest_seconds int;
  task_date date:=(reference->>'observed_on')::date; target_count int; latest_dates date[]:='{}';
begin
  if wk is null or extract(isodow from wk)<>1 then raise exception 'Semana no válida.'; end if;
  if target_date<wk then return jsonb_build_object('status','blocked','reason','La fecha objetivo ya ha pasado.'); end if;
  model:=case
    when profile->>'family' in ('carry','suitcase_carry') or profile->'movement_patterns' ? 'carry' then 'carry'
    when profile->'movement_modes' ? 'plyometric' or profile->>'code' in ('medicine_ball_chest_throw','kettlebell_swing') then 'power'
    when profile->'movement_patterns' ? 'rope_climb' then 'rope'
    when profile->'movement_patterns' ? 'reactive_agility' then 'reactive_agility'
    when m='TIME_FOR_COURSE' then 'course'
    when m='LOAD_REPS' then 'load_repetitions'
    when m='REPS' then 'repetitions'
    when m='REPS_IN_TIME' then 'timed_repetitions'
    when m='DURATION' then 'isometric'
    when m='MAX_LOAD' then 'max_test'
    else 'skill' end;
  if model='max_test' then return jsonb_build_object('status','needs_calibration',
    'reason','El RM es una medición de control. Registra una dosis submáxima con carga y repeticiones para entrenar.'); end if;
  same_reference:=previous->>'reference_id'=reference->>'id';
  baseline:=jsonb_build_object('task',task,'targets',reference->'targets',
    'rest_seconds',(reference->>'rest_seconds')::int,'model',model);
  dose:=case when same_reference and previous->'dose' is not null then previous->'dose' else baseline end;
  -- Una descarga no redefine la capacidad basal antes de tolerar esa dosis.
  comparison_dose:=dose;
  targets:=dose->'targets'; task:=dose->'task';
  select max((x->>'completed_on')::date) into last_on from jsonb_array_elements(coalesce(history,'[]')) x;
  fresh:=task_date between wk-(cfg->>'reference_days')::int and wk+6;
  if task_date>wk+6 or reference->>'current_capacity_confirmed' is distinct from 'true' then
    return jsonb_build_object('status','needs_calibration','reason','Confirma una referencia actual de trabajo.'); end if;
  if not fresh and (last_on is null or last_on<wk-(cfg->>'return_days')::int) then
    return jsonb_build_object('status','needs_calibration','reason','Tras la interrupción hay que confirmar de nuevo la capacidad de trabajo.'); end if;
  if model in ('repetitions','load_repetitions','timed_repetitions') and
    ((reference->>'reported_rir') is null or (reference->>'reported_rir')::numeric not between 2 and 4) then
    return jsonb_build_object('status','needs_calibration','reason','Necesitamos una serie de trabajo con técnica válida y aproximadamente 2–4 repeticiones en reserva.'); end if;
  phase:=case when days_left<=7 then 'taper' when days_left<=28 then 'specific'
    when last_on is null then 'entry' else 'development' end;
  reason:='Consolidar la dosis de trabajo; faltan dos respuestas comparables para aumentarla.';
  for e in select value from jsonb_array_elements(coalesce(history,'[]'))
    where (value->>'completed_on')::date>=greatest(task_date,wk-14)
      and (value->>'completed_on')::date<wk order by value->>'completed_on' desc loop
    if (e->>'completed_on')::date=any(latest_dates) then continue; end if;
    latest_dates:=array_append(latest_dates,(e->>'completed_on')::date);
    signal:=public.performance_exposure_signal_v1(e,dose);
    signals:=signals||jsonb_build_array(jsonb_build_object('execution_id',e->'execution_id','date',e->'completed_on','signal',signal));
    if signal='pain' then return jsonb_build_object('status','blocked','reason','Hay molestias registradas. Actualiza el contexto y confirma la capacidad antes de volver a pautar.','evidence',signals); end if;
    if signal='tolerated' then good:=good+1; end if;
    if signal='difficulty' then bad:=bad+1; end if;
    n:=n+1; exit when n=2;
  end loop;
  target_count:=jsonb_array_length(targets);
  if target_count not between 1 and 6 then raise exception 'Dosis de trabajo no válida.'; end if;
  minimum:=coalesce((reference->>'rep_min')::int,4);
  maximum:=coalesce((reference->>'rep_max')::int,6);
  load:=(task->>'external_load_kg')::numeric;
  step:=(reference->>'load_step_kg')::numeric;
  if bad=2 then
    outcome:='reduce'; reason:='Dos exposiciones comparables difíciles: reducir una demanda y comprobar su tolerancia.';
    if model in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') then
      select ordinality::int-1,value::numeric into idx,v from jsonb_array_elements_text(targets) with ordinality
        order by value::numeric desc,ordinality limit 1;
      if model='load_repetitions' and v<=minimum then
        if step is null or step<=0 or load-step<=0 or step>load*0.1 then
          return jsonb_build_object('status','needs_calibration','reason','La dosis mínima sigue siendo difícil; calibra una carga menor o una variante accesible.'); end if;
        task:=jsonb_set(task,'{external_load_kg}',to_jsonb(load-step));
      elsif v<=1 then
        return jsonb_build_object('status','needs_calibration','reason','Hace falta una variante accesible y una referencia propia.');
      else targets:=jsonb_set(targets,array[idx::text],to_jsonb(greatest(case when model='load_repetitions' then minimum else 1 end,
        v-case when model='isometric' then 2 when model='carry' and m='DISTANCE' then least(1,v*0.1) else 1 end))); end if;
    elsif target_count>1 then targets:=targets-(target_count-1);
    else return jsonb_build_object('status','needs_calibration','reason','Revisa la técnica y calibra una tarea accesible antes de repetir la dificultad.'); end if;
  elsif good=2 and phase not in ('taper') then
    if model in ('repetitions','load_repetitions','isometric','timed_repetitions') then
      select ordinality::int-1,value::numeric into idx,v from jsonb_array_elements_text(targets) with ordinality
        order by value::numeric,ordinality limit 1;
      if model='load_repetitions' and v>=maximum then
        if step is not null and step>0 and step<=load*0.1 then
          task:=jsonb_set(task,'{external_load_kg}',to_jsonb(load+step));
          select jsonb_agg(minimum) into targets from generate_series(1,target_count);
          outcome:='progress'; reason:='Extremo alto consolidado: subir un escalón disponible de carga y volver al inicio de la horquilla.';
        else reason:='Horquilla consolidada. Confirma un escalón de carga practicable antes de subir kilos.'; end if;
      else
        targets:=jsonb_set(targets,array[idx::text],to_jsonb(v+case when model='isometric' then 2 else 1 end));
        outcome:='progress'; reason:='Dos exposiciones comparables toleradas: aumentar solo una serie, conservando montaje y descansos.';
      end if;
    else reason:='Práctica válida consolidada. Mantener intentos de calidad y comparar el rendimiento; más fatiga no acredita potencia ni técnica.'; end if;
  elsif n=0 and previous->'dose' is null then outcome:='initial'; reason:='Entrada desde la dosis de trabajo demostrada, sin convertir un máximo del examen en volumen.';
  elsif n>0 and good<2 and bad<2 then reason:='Mantener: respuestas incompletas, distintas o aún insuficientes para atribuir un cambio de capacidad.';
  end if;
  if phase='taper' then
    -- Reducir series conserva el gesto y evita pedir récords en la última semana.
    if jsonb_array_length(targets)>1 then
      select jsonb_agg(value order by ordinality) into targets from jsonb_array_elements(targets) with ordinality
        where ordinality<=greatest(1,ceil(target_count/2.0));
    end if;
    outcome:='maintain'; reason:='Puesta a punto: menos series, conservar familiaridad y evitar nuevas progresiones antes de la prueba.';
  end if;
  dose:=dose||jsonb_build_object('task',task,'targets',targets);
  freq:=least(2,greatest(1,coalesce((reference->>'frequency')::int,1)));
  if phase='taper' or (phase='specific' and reference->>'role'='support') then freq:=1; end if;
  rest_seconds:=(dose->>'rest_seconds')::int;
  select sum(case when m='DURATION' then value::numeric
    when m='REPS_IN_TIME' then (task->>'fixed_duration_seconds')::numeric
    when m in ('TIME_FOR_DISTANCE','TIME_FOR_COURSE') then greatest(30,value::numeric)
    when m in ('REPS','LOAD_REPS') then value::numeric*5
    when model in ('power','skill','reactive_agility','rope') then 30
    when m='DISTANCE' and model='carry' then value::numeric*2
    else value::numeric*5 end) into work_seconds from jsonb_array_elements_text(targets);
  minutes:=ceil((work_seconds+greatest(0,jsonb_array_length(targets)-1)*rest_seconds+60)/60.0);
  return jsonb_build_object('status','ready','policy_version','performance_v1','reference_id',reference->>'id',
    'model',model,'phase',phase,'outcome',outcome,'reason',reason,'comparison_dose',comparison_dose,'dose',dose,'frequency',freq,
    'work_minutes',minutes,'body_regions',profile->'body_regions','movement_patterns',profile->'movement_patterns',
    'evidence',signals,'review_due',coalesce((previous->>'weeks_since_review')::int,0)>=3,
    'weeks_since_review',case when coalesce((previous->>'weeks_since_review')::int,0)>=3 then 0 else coalesce((previous->>'weeks_since_review')::int,0)+1 end,
    'parameter_status',cfg->>'parameter_status');
end $$;

revoke all on function public.performance_exposure_signal_v1(jsonb,jsonb),
  public.performance_task_v1(jsonb,jsonb,jsonb,date,date,jsonb) from public,anon,authenticated;
commit;
