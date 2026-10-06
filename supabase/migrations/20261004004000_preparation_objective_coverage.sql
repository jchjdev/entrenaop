-- Cobertura deportiva antes de segunda exposición o apoyos.
begin;
create function public.performance_compact_proposal_v2(p jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare targets jsonb; dose jsonb; seconds int;
begin
 if p->>'status'<>'ready' then return p; end if;
 select jsonb_agg(value order by ordinality) into targets from jsonb_array_elements(p->'dose'->'targets') with ordinality
 where ordinality<=case when p->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') then 2 else 1 end;
 dose:=jsonb_set(p->'dose','{targets}',targets); seconds:=public.performance_work_seconds_v2(dose);
 return p||jsonb_build_object('dose',dose,'outcome','reduce','compact',true,'work_seconds',seconds,'work_minutes',ceil(seconds/60.0),
  'reason',p->>'reason'||' Formato corto por disponibilidad: menos series, misma técnica y margen. No aumentes la intensidad para compensarlo.');
end $$;
-- Dos exposiciones muy fáciles permiten recuperar margen sin estimar un máximo.
create function public.performance_task_v2_1(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,previous jsonb default '{}'::jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare p jsonb:=public.performance_task_v2(reference,profile,history,wk,target_date,previous); baseline jsonb; targets jsonb; e jsonb;
 good int:=0; easy int:=0; budget int; idx int; initial numeric; current_value numeric; count_sets int; n int; seconds int;
begin
 if p->>'outcome'<>'progress' or p->>'model' not in ('repetitions','isometric') then return p; end if;
 for e in select value from jsonb_array_elements(p->'evidence') where value->>'signal'='tolerated' loop
  good:=good+1;
  if not exists(select 1 from jsonb_array_elements(e->'exposure'->'sets') s where
    case when p->>'model'='repetitions' then coalesce((s->'result'->>'rir')::numeric,0)<6
    else coalesce((s->'result'->>'rpe')::numeric,10)>4 end) then easy:=easy+1; end if;
 end loop;
 if good<2 or easy<2 then return p; end if;
 baseline:=p->'comparison_dose'->'targets'; targets:=baseline; count_sets:=jsonb_array_length(targets);
 select greatest(1,floor(sum(value::numeric)*0.10))::int into budget from jsonb_array_elements_text(targets);
 -- Cota operativa: hasta 10% de volumen, como máximo tres unidades por serie.
 budget:=least(budget,count_sets*3);
 for n in 1..budget loop
  select ordinality::int-1 into idx from jsonb_array_elements_text(targets) with ordinality
   where value::numeric<(baseline->>(ordinality::int-1))::numeric+3 order by value::numeric,ordinality limit 1;
  if idx is null then exit; end if;
  targets:=jsonb_set(targets,array[idx::text],to_jsonb((targets->>idx)::numeric+1));
 end loop;
 p:=jsonb_set(p,'{dose,targets}',targets); p:=jsonb_set(p,'{dose,task,target_value}',targets->0);
 seconds:=public.performance_work_seconds_v2(p->'dose');
 return p||jsonb_build_object('work_seconds',seconds,'work_minutes',ceil(seconds/60.0),'adaptation_rule','repeated_very_easy_bounded_volume_v1',
  'reason',p->>'reason'||' Ambas exposiciones dejaron mucho margen: ajuste limitado del volumen, sin estimar un máximo ni cambiar la variante.');
end $$;
create function public.performance_place_v2_1(proposals jsonb,availability jsonb,occupied jsonb,
 prior_loads jsonb,rotation int,wk date,target_date date) returns jsonb
language plpgsql immutable set search_path='' as $$
declare days jsonb:='{}'; placed jsonb:='[]'; missing jsonb:='[]'; p jsonb; day jsonb; old jsonb;
 n int; d int; used int; cost int; wanted int; assigned int; blocked boolean; same_demand boolean;
 lower_days jsonb:='[]'; remaining jsonb:='{}'; score int:=0; actual_days int[]; rounds int;
begin
 for d in 1..7 loop days:=days||jsonb_build_object(d::text,jsonb_build_object('minutes',0,'work','[]'::jsonb)); end loop;
 -- Primero cubrir cada objetivo una vez; después distribuir su segunda exposición.
 for rounds in 1..2 loop
 for p in select value from jsonb_array_elements(proposals) where value->>'status'='ready'
  order by case when value->>'required_for_objective'='true' then 0 else 1 end,
   case when value->>'model' in ('course','power','rope','reactive_agility') then 0 else 1 end,
   value->>'objective_key',value->>'reference_id' loop
  wanted:=(p->>'frequency')::int;
  select coalesce(array_agg((q->>'day')::int),'{}') into actual_days from jsonb_array_elements(placed) q where q->>'reference_id'=p->>'reference_id';
  assigned:=cardinality(actual_days); if rounds>wanted or assigned<>rounds-1 then continue; end if;
  for n in 0..6 loop
   d:=1+(n+rotation)%7;
   if coalesce(occupied,'[]') @> to_jsonb(array[d]) or wk+d-1>=target_date-1 then continue; end if;
   if exists(select 1 from unnest(actual_days) ad where abs(ad-d)<=1 or abs(ad-d)=6) then continue; end if;
   blocked:=false;
   for old in select value from jsonb_array_elements(placed||coalesce(prior_loads,'[]')) loop
    if abs((old->>'day')::int-d)=1 and exists(select 1 from jsonb_array_elements_text(p->'body_regions') reg
     where coalesce(old->'body_regions','["upper_body","lower_body","trunk"]') ? reg) then blocked:=true; exit; end if;
   end loop;
   if blocked then continue; end if;
   day:=days->d::text; used:=(day->>'minutes')::int;
   -- No apilar apoyos equivalentes o dos bloques fuertes del mismo patrón por ser ejercicios distintos.
   same_demand:=exists(select 1 from jsonb_array_elements(day->'work') q where
    exists(select 1 from jsonb_array_elements_text(p->'movement_patterns') pat where q->'movement_patterns' ? pat)
    or (p->'body_regions' ? 'upper_body' and q->'body_regions' ? 'upper_body'
       and (p->>'model'='isometric' or q->>'model'='isometric')
       and jsonb_array_length(p->'dose'->'targets') + coalesce((select sum(jsonb_array_length(t->'dose'->'targets')) from jsonb_array_elements(day->'work') t where t->'body_regions' ? 'upper_body'),0)>(public.performance_bank_v2()->>'maximum_shared_upper_sets')::int));
   if same_demand then continue; end if;
   cost:=(p->>'work_minutes')::int+case when used=0 then 10 else 0 end;
   if used+cost>coalesce((availability->>d::text)::int,0) then continue; end if;
   day:=day||jsonb_build_object('minutes',used+cost,'work',day->'work'||jsonb_build_array(p));
   days:=jsonb_set(days,array[d::text],day);
   placed:=placed||jsonb_build_array(jsonb_build_object('day',d,'reference_id',p->>'reference_id','body_regions',p->'body_regions'));
   score:=score+case when rounds=1 and p->>'required_for_objective'='true' then 1000 when p->>'required_for_objective'='true' then 100 else 10 end;
   exit;
  end loop;
 end loop;
 end loop;
 for p in select value from jsonb_array_elements(proposals) where value->>'status'='ready' loop
  select count(*) into assigned from jsonb_array_elements(placed) q where q->>'reference_id'=p->>'reference_id';
  wanted:=coalesce((p->>'requested_frequency')::int,(p->>'frequency')::int);
  if assigned<wanted then missing:=missing||jsonb_build_array(jsonb_build_object('reference_id',p->>'reference_id',
   'required_for_objective',p->'required_for_objective','objective_key',p->>'objective_key','name',p->>'name','role',p->>'role','requested',wanted,'scheduled',assigned,
   'reason',case when assigned=0 then 'No cabe este estímulo con tiempo y recuperación suficientes. Amplía días o revisa prioridades.' else 'Se pauta una exposición: la segunda no cabe respetando tiempo y recuperación.' end)); end if;
 end loop;
 for d in 1..7 loop
  day:=days->d::text; remaining:=remaining||jsonb_build_object(d::text,greatest(0,coalesce((availability->>d::text)::int,0)-(day->>'minutes')::int));
  if exists(select 1 from jsonb_array_elements(day->'work') x where coalesce((x->>'running_leg_load')::boolean,x->'body_regions' ? 'lower_body')) then lower_days:=lower_days||to_jsonb(d); end if;
 end loop;
 return jsonb_build_object('days',days,'remaining',remaining,'lower_days',lower_days,'missing',missing,'score',score);
end $$;
create or replace function public.calculate_preparation_week_core(p_goal_id uuid,p_week_start date,p_revision boolean)
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
   where r.preparation_goal_id=p_goal_id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
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
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=p_goal_id order by a.assessed_on desc,a.created_at desc limit 1;
 if selected_category is null and exists(select 1 from public.program_assessment_tests where program_id=g.program_id and (category<>'both' or min_age<>0 or max_age<>120)) then
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_assessment','name','Categoría de las pruebas',
     'reason','Completa la evaluación de esta preparación para identificar las pruebas que te corresponden.')); end if;
 for ref in select b.test_id,t.name from public.program_test_training_bindings b
   join public.program_assessment_tests t on t.id=b.test_id
   where b.program_id=g.program_id and public.performance_test_applies(g.id,t.id) and (t.category='both' or t.category=selected_category)
     and not exists(select 1 from public.performance_training_references r where r.preparation_goal_id=p_goal_id and r.active and r.test_id=b.test_id) loop
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
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::int),'[]') into occupied
   from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6 and status not in ('cancelled','skipped')
   and (not p_revision or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)));
 select coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
     and sw.status not in ('cancelled','skipped')
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',sw.scheduled_date-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped')
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry');
 -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and q->>'objective_key'=p->>'objective_key'
   and (case q->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
        q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,p->>'reference_id')))),'[]') into proposals
 from jsonb_array_elements(proposals) p;
 if has_running then
  begin
   expected_running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
    jsonb_build_object('revise_week',p_revision,'availability',ctx.availability,'strength_days','[]'::jsonb,'leg_load_days','[]'::jsonb));
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
         jsonb_build_object('revise_week',p_revision,'availability',candidate->'remaining','strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days'));
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
   'policy_version','preparation_coordinator_v2_1','week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;
revoke all on function public.performance_place_v2_1(jsonb,jsonb,jsonb,jsonb,int,date,date), public.performance_compact_proposal_v2(jsonb), public.performance_task_v2_1(jsonb,jsonb,jsonb,date,date,jsonb) from public,anon,authenticated;
commit;
