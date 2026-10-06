-- Estrategia por objetivo sobre referencias reales. No contiene dosis de carrera.
-- Los plazos de 14/28/7 días son parámetros operativos, no óptimos universales.
create function public.performance_block_v3(reference jsonb, history jsonb, wk date,
 target_date date, started_on date, previous jsonb default '{}'::jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare phase text; remaining int:=target_date-wk; good int:=0; difficult int:=0;
 last_day date; h jsonb; signal text; entered date; reason text; interrupted boolean; counted int:=0;
begin
 for h in select value from jsonb_array_elements(coalesce(history,'[]'))
   where (value->>'completed_on')::date between greatest((reference->>'observed_on')::date,wk-21) and wk-1
   order by value->>'completed_on' desc loop
  if last_day=(h->>'completed_on')::date then continue; end if;
  signal:=public.performance_exposure_signal_v2(h,h->'dose');
  if signal='tolerated' then good:=good+1;
  elsif signal='difficulty' then difficult:=difficult+1; end if;
  last_day:=(h->>'completed_on')::date;
  counted:=counted+1; exit when counted>=2;
 end loop;
 interrupted:=not exists(select 1 from jsonb_array_elements(coalesce(history,'[]')) e
   where (e->>'completed_on')::date between wk-21 and wk-1);
 phase:=case when remaining<=7 then 'taper' when remaining<=28 then 'specific'
   when (previous->>'phase' in ('development','specific') and not interrupted)
     or (good>=2 and not interrupted) then 'development' else 'base' end;
 reason:=case phase when 'base' then 'Encontrar trabajo practicable y consolidar técnica antes de ampliar la exigencia.'
  when 'development' then 'Desarrollar capacidad específica y apoyos pertinentes, conservando lo que permite comparar tu respuesta.'
  when 'specific' then 'Aumentar la prioridad del protocolo del examen con la capacidad actual; no perseguir aún una marca deseada.'
  else 'Conservar práctica conocida y reducir trabajo fatigante antes de la prueba.' end;
 if difficult>0 then reason:=reason||' La dificultad reciente modifica la dosis; cambiar de fecha no acredita preparación.'; end if;
 entered:=case when previous->>'phase'=phase and not interrupted then coalesce((previous->'block'->>'entered_on')::date,wk) else wk end;
 return jsonb_build_object('code',phase,'name',case phase when 'base' then 'Consolidar el punto de partida'
   when 'development' then 'Desarrollar fuerza y resistencia' when 'specific' then 'Preparar el formato del examen' else 'Llegar recuperado' end,
   'purpose',reason,'entered_on',entered,'weeks_in_block',greatest(1,(wk-entered)/7+1),
   'target_date',target_date,'days_remaining',remaining,'comparable_tolerated_exposures',good,
   'next_review','Revisamos la dosis con cada cierre de semana y el énfasis al cambiar la respuesta o acercarse la prueba.',
   'recent_difficulty',difficult>0,'parameter_status','operational_requires_outcome_monitoring');
end $$;

create function public.performance_select_v3(proposals jsonb) returns jsonb
language sql immutable set search_path='' as $$
 -- Mantener una práctica principal y como máximo un apoyo opcional por objetivo.
 -- Una referencia libre puede ser la única cobertura de una prueba cronometrada.
 with ranked as (
  select p,row_number() over(partition by p->>'objective_key' order by
   case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
   case p->>'exercise_code' when 'push_up_standard' then 0 when 'push_up_weighted' then 1
    when 'bench_press_barbell' then 2 else 3 end,p->>'reference_id') n
  from jsonb_array_elements(proposals) p where p->>'status'='ready'
 ), selected as (
  select p||jsonb_build_object('selection_rank',n,'optional',n>1,
    'role',case when n>1 then 'support' else p->>'role' end,
    'frequency',case when n>1 then 1 else (p->>'frequency')::int end,
    'selection_reason',coalesce(p->>'selection_reason','')||case when n>1
      then ' Apoyo opcional con referencia propia; se retira si desplaza trabajo prioritario.' else '' end) p
  from ranked where n=1 or (n=2
   and exists(select 1 from ranked main where main.n=1 and main.p->>'objective_key'=p->>'objective_key'
     and main.p->>'phase'='development' and (
       (main.p->>'exercise_code'='push_up_standard' and p->>'role'='support')
       or (main.p->>'model'='course' and p->>'role'='support' and p->>'model'='load_repetitions')
       or (main.p->>'exercise_code'='front_plank_forearms' and p->>'exercise_code'='dead_bug'))
     and coalesce(main.p->>'outcome','initial')<>'reduce')
   and jsonb_array_length(p->'dose'->'targets')<=2)
  union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) select coalesce(jsonb_agg(p order by coalesce((p->>'selection_rank')::int,0),p->>'reference_id'),'[]') from selected
$$;

create function public.performance_program_path_v3(started_on date,target_date date,wk date,proposals jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare stages jsonb:='[]'; first_specific date:=greatest(started_on,target_date-28);
 first_taper date:=greatest(started_on,target_date-7); first_development date;
begin
 first_development:=least(first_specific,started_on+14);
 if started_on<first_development then stages:=stages||jsonb_build_array(jsonb_build_object(
  'code','base','name','Consolidar el punto de partida','starts_on',started_on,'ends_on',first_development-1,
  'purpose','Confirmar técnica, datos y una dosis tolerable. La transición se revisa con los resultados.')); end if;
 if first_development<first_specific then stages:=stages||jsonb_build_array(jsonb_build_object(
  'code','development','name','Desarrollar fuerza y resistencia','starts_on',first_development,'ends_on',first_specific-1,
  'purpose','Desarrollo revisable por bloques; trabajo específico y apoyos con datos propios.')); end if;
 if first_specific<first_taper then stages:=stages||jsonb_build_array(jsonb_build_object(
  'code','specific','name','Preparar el formato del examen','starts_on',first_specific,'ends_on',first_taper-1,
  'purpose','Dar más peso a las condiciones de la prueba sin convertir cada entrenamiento en un máximo.')); end if;
 stages:=stages||jsonb_build_array(jsonb_build_object('code','taper','name','Llegar recuperado',
  'starts_on',first_taper,'ends_on',target_date,'purpose','Menos trabajo fatigante y práctica conocida.'));
 return jsonb_build_object('version','program_path_v3','planned',true,'target_date',target_date,
  'stages',stages,'objectives',coalesce((select jsonb_agg(coalesce(p->'block',jsonb_build_object(
     'code',p->>'phase','name',case p->>'phase' when 'base' then 'Consolidar el punto de partida' when 'development' then 'Desarrollar fuerza y resistencia' when 'specific' then 'Preparar el formato del examen' else 'Llegar recuperado' end,
     'purpose',coalesce(p->>'selection_reason',p->>'reason')))||jsonb_build_object(
     'objective_key',p->>'objective_key','exercise_name',p->>'name')) from jsonb_array_elements(proposals) p
     where p->>'status'='ready' and p->>'optional' is distinct from 'true'),'[]'),
  'note','Fechas orientativas. Cada objetivo conserva su fase real según resultados y tiempo hasta la prueba.');
end $$;

create function public.performance_calibration_options_v3(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then
   raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select coalesce(jsonb_agg(x.item),'[]') into result from (
  select distinct jsonb_build_object('objective_key',r.objective_key,'goal_code',r.target_profile_code,
   'goal_version',r.target_profile_version,'measurement',r.target_measurement,'test_id',r.test_id,
   'program_objective_key',r.reference->>'program_objective_key','work_code',rel.work_code,
   'name',ep.definition->>'name','optional',true,
   'reason','Opción de apoyo. Registra una práctica real de esta variante; no se deduce de la marca de la prueba.') item
  from public.performance_training_references r
  join public.performance_exercise_relations rel on rel.goal_code=r.target_profile_code
    and (rel.role='support' or (rel.goal_code='front_plank_forearms' and rel.work_code='dead_bug')) and rel.policy_version='performance_v1'
  join public.exercise_training_profiles ep on ep.code=rel.work_code
  join public.performance_training_contexts ctx on ctx.user_id=r.user_id
  where r.user_id=auth.uid() and r.preparation_goal_id=p_goal_id and r.active
   and ctx.capacity_confirmed and not ctx.reports_pain and ctx.observed_at>=now()-interval '30 days'
   and (select target_date from public.preparation_goals where id=p_goal_id)>current_date+28
   and not exists(select 1 from public.exercise_training_profiles newer where newer.code=ep.code and newer.definition_version>ep.definition_version)
   and not exists(select 1 from jsonb_array_elements_text(ep.definition->'required_equipment') eq where not eq=any(ctx.equipment))
   and exists(select 1 from public.exercises ex where ex.training_profile_code=ep.code and ex.training_profile_version=ep.definition_version and ex.is_public)
   and not exists(select 1 from public.performance_training_references known where known.preparation_goal_id=p_goal_id
    and known.active and known.objective_key=r.objective_key and known.reference->'task'->>'exercise_code'=rel.work_code)
  union
  select distinct jsonb_build_object('objective_key',r.objective_key,'goal_code',r.target_profile_code,
   'goal_version',r.target_profile_version,'measurement',r.target_measurement,'test_id',r.test_id,
   'program_objective_key',r.reference->>'program_objective_key','work_code',r.target_profile_code,
   'preferred_measurement','REPS_IN_TIME','name','Flexiones · práctica cronometrada','optional',true,
   'reason','Si tienes un resultado reciente con el tiempo de la prueba, regístralo. Permite pautar fragmentos de ritmo; no exige repetir un máximo ni convierte tu serie libre en una marca temporal.') item
  from public.performance_training_references r join public.performance_training_contexts ctx on ctx.user_id=r.user_id
  where r.user_id=auth.uid() and r.preparation_goal_id=p_goal_id and r.active
   and r.target_profile_code='push_up_standard' and r.target_measurement='REPS_IN_TIME'
   and ctx.capacity_confirmed and not ctx.reports_pain and ctx.observed_at>=now()-interval '30 days'
   and not exists(select 1 from public.performance_training_references known where known.preparation_goal_id=p_goal_id and known.active
    and known.objective_key=r.objective_key and known.reference->'task'->>'measurement'='REPS_IN_TIME')
 ) x;
 return result;
end $$;
revoke all on function public.performance_block_v3(jsonb,jsonb,date,date,date,jsonb),
 public.performance_select_v3(jsonb),public.performance_program_path_v3(date,date,date,jsonb),
 public.performance_calibration_options_v3(uuid) from public,anon,authenticated;

-- Una comprobación submáxima sustituye la primera exposición ordinaria al
-- cambiar a especificidad, si hay respuesta comparable suficiente. No se
-- añade volumen, no estima una marca máxima y no se activa por contador.
create function public.performance_controls_v3(sessions jsonb,previous jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare result jsonb:='[]'; session jsonb; work jsonb; items jsonb; old jsonb; used text[]:='{}'; key text;
begin
 for session in select value from jsonb_array_elements(coalesce(sessions,'[]')) order by value->>'date' loop
  items:='[]';
  for work in select value from jsonb_array_elements(session->'work') loop
   key:=work->>'reference_id';
   select value into old from jsonb_array_elements(coalesce(previous->'proposals','[]')) p
    where p->>'reference_id'=key or p->'covered_reference_ids' ? key limit 1;
   if work->>'phase'='specific' and old->>'phase'='development'
     and (work->'block'->>'comparable_tolerated_exposures')::int>=2
     and work->>'outcome'<>'reduce' and work->>'optional' is distinct from 'true'
     and not key=any(used) then
    work:=work||jsonb_build_object('control',jsonb_build_object('kind','submaximal_work',
      'purpose','Comprobar calidad y esfuerzo al entrar en trabajo específico. No mide tu máximo.',
      'replaces','ordinary_exposure','updates','work_capacity_only'),
      'name','Control submáximo · '||(work->>'name'),
      'reason',(work->>'reason')||' Hoy comprobamos la respuesta en condiciones repetibles. Registra trabajo válido, esfuerzo y técnica; no añadas un máximo.');
    used:=array_append(used,key);
   end if;
   items:=items||jsonb_build_array(work);
  end loop;
  result:=result||jsonb_build_array(session||jsonb_build_object('work',items));
 end loop;
 return result;
end $$;
revoke all on function public.performance_controls_v3(jsonb,jsonb) from public,anon,authenticated;

create function public.performance_warm_up_steps_v3(session jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare output jsonb:='[]'; mobility text; rehearsal text:=''; w jsonb; shared boolean:=coalesce((session->>'warm_up_seconds')::int,420)=180;
begin
 if not shared then output:=output||jsonb_build_array(jsonb_build_object('name','Activación suave','seconds',180,
   'instructions','Camina o trota suavemente. Aumenta el movimiento de forma gradual, a un ritmo que te permita hablar con comodidad.')); end if;
 mobility:='Movimientos cómodos de hombros, codos y muñecas para los apoyos. Si hay desplazamientos, incluye tobillos, rodillas y caderas. Sin forzar posiciones.';
 for w in select value from jsonb_array_elements(coalesce(session->'work','[]')) loop
   rehearsal:=rehearsal||coalesce(w->>'name','Movimiento pautado')||': '||case
    when w->>'model'='course' then 'ensaya despacio la salida, los giros y la frenada; comprueba el espacio libre.'
    when w->>'model'='isometric' then 'ensaya la postura unos segundos, respirando, y termina antes de que cueste.'
    else 'ensaya pocas repeticiones con apoyo o carga fácil, lejos del agotamiento.' end||E'\n';
 end loop;
 return output||jsonb_build_array(
   jsonb_build_object('name','Movilidad cómoda','seconds',case when shared then 60 else 120 end,'instructions',mobility),
   jsonb_build_object('name','Ensayo de los movimientos','seconds',120,'instructions',rehearsal||'La duración es orientativa. Amplía la preparación si aún no te encuentras preparado; hoy no buscamos fatiga ni máximos.'));
end $$;
revoke all on function public.performance_warm_up_steps_v3(jsonb) from public,anon,authenticated;
