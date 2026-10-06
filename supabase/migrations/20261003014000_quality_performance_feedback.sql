begin;
create or replace function public.performance_task_v1(
  reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
  previous jsonb default '{}'::jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare cfg jsonb:=public.performance_policy_v1(); task jsonb:=reference->'task';
  dose jsonb; comparison_dose jsonb; baseline jsonb; targets jsonb; m text:=task->>'measurement'; model text;
  signals jsonb:='[]'; e jsonb; signal text; n int:=0; good int:=0; bad int:=0;
  phase text; outcome text:='maintain'; reason text; idx int; v numeric; step numeric;
  load numeric; minimum int; maximum int; freq int; last_on date; days_left int:=target_date-wk;
  fresh boolean; same_reference boolean; minutes int; work_seconds numeric; rest_seconds int;
  task_date date:=(reference->>'observed_on')::date; target_count int; latest_dates date[]:='{}'; demonstrated numeric; old_target numeric;
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
    signals:=signals||jsonb_build_array(jsonb_build_object('execution_id',e->'execution_id','date',e->'completed_on','signal',signal,'exposure',e));
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
    if model in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') then
      select ordinality::int-1,value::numeric into idx,v from jsonb_array_elements_text(targets) with ordinality
        order by value::numeric,ordinality limit 1;
      if model='load_repetitions' and v>=maximum then
        if step is not null and step>0 and step<=load*0.1 then
          task:=jsonb_set(task,'{external_load_kg}',to_jsonb(load+step));
          select jsonb_agg(minimum) into targets from generate_series(1,target_count);
          outcome:='progress'; reason:='Extremo alto consolidado: subir un escalón disponible de carga y volver al inicio de la horquilla.';
        else reason:='Horquilla consolidada. Confirma un escalón de carga practicable antes de subir kilos.'; end if;
      else
        targets:=jsonb_set(targets,array[idx::text],to_jsonb(v+case when model='isometric' or (model='carry' and m='DURATION') then 2 when model='carry' and m='DISTANCE' then least(1,v*0.1) else 1 end));
        outcome:='progress'; reason:='Dos exposiciones comparables toleradas: aumentar solo una serie, conservando montaje y descansos.';
      end if;
    elsif (model='power' and m in ('DISTANCE','HEIGHT')) or (model in ('rope','course','reactive_agility') and m in ('TIME_FOR_DISTANCE','TIME_FOR_COURSE')) then
      -- Cambia la referencia de rendimiento ya repetido, no el número de intentos
      -- ni la altura/trayecto. No estima velocidad o potencia desde repeticiones.
      for idx in 0..target_count-1 loop
        old_target:=(targets->>idx)::numeric;
        select case when m in ('DISTANCE','HEIGHT') then min((h->'sets'->idx->'result'->>'value')::numeric)
          else max((h->'sets'->idx->'result'->>'value')::numeric) end into demonstrated
          from jsonb_array_elements(history) h where (h->>'completed_on')::date=any(latest_dates)
            and public.performance_exposure_signal_v1(h,dose)='tolerated';
        if demonstrated>0 and ((m in ('DISTANCE','HEIGHT') and demonstrated>old_target)
          or (m in ('TIME_FOR_DISTANCE','TIME_FOR_COURSE') and demonstrated<old_target)) then
          targets:=jsonb_set(targets,array[idx::text],to_jsonb(demonstrated)); outcome:='consolidated_performance';
        end if;
      end loop;
      reason:=case when outcome='consolidated_performance' then
        'Referencia actualizada al rendimiento válido repetido en dos exposiciones. Conserva intentos, material y recorrido; no busques un máximo forzado.'
        else 'Mantener intentos de calidad: aún no hay dos rendimientos mejores y comparables para actualizar la referencia.' end;
    else reason:='Práctica válida consolidada. Mantener intentos de calidad; cambiar complejidad, asistencia o material requiere una referencia propia.'; end if;
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
  task:=task||jsonb_build_object('policy_version','performance_v1_1');
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
  return jsonb_build_object('status','ready','policy_version','performance_v1_1','reference_id',reference->>'id',
    'model',model,'phase',phase,'outcome',outcome,'reason',reason,'comparison_dose',comparison_dose,'dose',dose,'frequency',freq,
    'work_minutes',minutes,'body_regions',profile->'body_regions','movement_patterns',profile->'movement_patterns',
    'evidence',signals,'review_due',coalesce((previous->>'weeks_since_review')::int,0)>=3,
    'weeks_since_review',case when coalesce((previous->>'weeks_since_review')::int,0)>=3 then 0 else coalesce((previous->>'weeks_since_review')::int,0)+1 end,
    'parameter_status',cfg->>'parameter_status');
end $$;
create or replace function public.save_performance_context(p_availability jsonb,p_equipment text[],
  p_reports_pain boolean,p_capacity_confirmed boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare x record;
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  -- Comparte el candado del publicador: contexto y revisión no se intercalan.
  perform 1 from public.profiles where id=auth.uid() for update;
  if p_availability is null or jsonb_typeof(p_availability)<>'object'
    or p_equipment is null or p_reports_pain is null or p_capacity_confirmed is null then
    raise exception 'Completa disponibilidad y contexto.' using errcode='22023'; end if;
  for x in select * from jsonb_each(p_availability) loop
    if x.key !~ '^[1-7]$' or jsonb_typeof(x.value)<>'number'
      or (x.value::text)::numeric not between 0 and 180
      or (x.value::text)::numeric<>trunc((x.value::text)::numeric) then
      raise exception 'Disponibilidad no válida.' using errcode='22023'; end if;
  end loop;
  if cardinality(p_equipment)>100 or exists(select 1 from unnest(p_equipment) as eq(value) where eq.value is null or eq.value !~ '^[a-z][a-z0-9_]{0,79}$') then
    raise exception 'Material no válido.' using errcode='22023'; end if;
  insert into public.performance_training_contexts(user_id,availability,equipment,reports_pain,capacity_confirmed)
    values(auth.uid(),p_availability,p_equipment,p_reports_pain,p_capacity_confirmed)
    on conflict(user_id) do update set availability=excluded.availability,equipment=excluded.equipment,
      reports_pain=excluded.reports_pain,capacity_confirmed=excluded.capacity_confirmed,observed_at=now();
end $$;

commit;
