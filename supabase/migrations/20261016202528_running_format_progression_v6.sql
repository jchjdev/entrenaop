begin;

-- Reutilizar datos realizados, no la etiqueta de una referencia antigua.
-- La tolerancia se vuelve a comprobar con los parciales y el esfuerzo reales.
create function public.running_dose_evidence_v6(
 history jsonb,wk date,family text,step int,anchor numeric,factor numeric
) returns jsonb language plpgsql immutable set search_path='' as $$
declare h jsonb; original jsonb; compatible jsonb; prescription jsonb;
 samples jsonb:='[]'; checked int:=0;
begin
 prescription:=public.running_session_v2(family,step,anchor,180,factor);
 for h in select value from jsonb_array_elements(coalesce(history,'[]'))
  where (value->>'date')::date<wk and (value->>'date')::date>=wk-56
   and value->'session'->>'family'=family
   and not coalesce((value->'session'->>'taper')::boolean,false)
  order by (value->>'date')::date desc loop
  original:=public.running_evaluate_v2(h->'session',h->'execution');
  -- Una incidencia posterior invalida el permiso de progresar que daban
  -- éxitos anteriores. Se vuelve a reunir evidencia, sin borrar el historial.
  exit when original->>'status'<>'tolerated';
  if (h->'session'->>'step')::int is distinct from step then continue; end if;
  checked:=checked+1;
  compatible:=public.running_evaluate_v2(prescription,h->'execution');
  if compatible->>'status'='tolerated' then
   samples:=samples||jsonb_build_array(jsonb_build_object('date',h->'date',
    'original_anchor_seconds',h->'session'->'anchor_seconds',
    'pace_seconds_per_km',compatible->'pace_seconds_per_km','rpe',compatible->'rpe'));
  end if;
 end loop;
 return jsonb_build_object('policy','running_dose_evidence_v6','family',family,
  'step',step,'anchor_seconds',anchor,'speed_factor',factor,
  'checked',checked,'compatible_successes',jsonb_array_length(samples),'samples',samples);
end $$;

revoke all on function public.running_dose_evidence_v6(jsonb,date,text,int,numeric,numeric)
 from public,anon,authenticated;


create function public.running_plan_v6(p_input jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
 cfg jsonb:=public.running_policy_v1();
 selection_cfg jsonb:=public.running_selection_policy_v4();
 allocations int[]; fit jsonb; pairing jsonb; requested_family text; choices text[];
 dose_evidence jsonb; frequency_probe jsonb; future_fit jsonb; minimum_quality_minutes int; future_day int; defer_quality boolean;
 j int; spare int; assigned int; capacity int; prior_quality int;
 eligible_exposures int; eligible_weeks int; work_cap int; tolerated_work int;
 reserve_second boolean:=false; added_second boolean:=false; pairing_unchanged boolean:=false;
 recommendations jsonb:='[]';
 wk date := (p_input->>'week_start')::date;
 target date := (p_input->>'target_date')::date;
 anchor numeric := (p_input->>'anchor_seconds')::numeric;
 goal_seconds numeric := (p_input->>'goal_seconds')::numeric;
 goal_info jsonb; control_due boolean:=false;
 prev jsonb := coalesce(p_input->'previous','{}');
 ev jsonb; obs jsonb; session jsonb; candidate jsonb; last_session jsonb;
 days integer[] := '{}'; selected_days integer[] := '{}'; quality_days integer[] := '{}';
 strength integer[]; d integer; i integer; cnt integer; budget integer; used integer := 0;
 baseline integer; last_budget integer; recent_days integer; latest_minutes integer;
 objective_bad integer; unknown_count integer; omitted integer; tests jsonb;
 n integer; good integer; bad integer; missing integer; off_intent integer; pain integer;
 successes integer; previous_count integer; dose_step integer; held_step integer;
 best_step integer; same_good integer; max_step integer; exposures integer;
 block_count integer; quality_count integer := 0; max_quality integer := 1;
 min_minutes integer; minutes integer; cap integer; last_minutes integer;
 available integer; weeks_left integer; f text; chosen text; priority text;
 cycle text[]; phase text; mode text := 'normal'; outcome text := 'initial';
 reason text := 'Entrada según carga reciente y disponibilidad'; basis text := 'recent';
 can_quality boolean; progressed boolean := false; changed_anchor boolean := false;
 missed boolean := false; quality_changed boolean := false; changed jsonb := '[]';
 sessions jsonb := '[]'; rejected jsonb := '[]'; need_control boolean;
 factor numeric := 1; previous_factor numeric := 1;
begin
 if wk is null or extract(isodow from wk)<>1 or anchor not between 240 and 1800 then
   raise exception 'Invalid running engine input'; end if;
 if coalesce((p_input->>'pain')::boolean,false) then raise exception 'Health flag pauses proposal'; end if;
 if target is not null and target < wk then raise exception 'Target date has passed'; end if;
 goal_info:=public.running_goal_v2(p_input);
 goal_seconds:=(goal_info->>'seconds')::numeric;
 tests:=public.running_test_trend_v2(coalesce(p_input->'controls','[]'),wk);
 control_due:=coalesce((p_input->>'anchor_age_days')::integer,0)>=28 and (target is null or target-wk>14);
 need_control := coalesce((p_input->>'anchor_age_days')::integer,0)>45;
 ev := public.running_evidence_v2(coalesce(p_input->'history','[]'),wk);
 obs := ev->'observations';
 if exists(select 1 from jsonb_array_elements(obs) o where (o->>'date')::date>=wk-7 and o->'signal'->>'status'='pain') then
   raise exception 'Update health status after discomfort'; end if;
 select coalesce(array_agg(value::integer),'{}') into strength
 from jsonb_array_elements_text(coalesce(p_input->'strength_days','[]'));
 for d in 1..7 loop
   if coalesce((p_input->'availability'->>d::text)::integer,0)>=25
     and not d=any(strength)
     and not coalesce(p_input->'occupied_days','[]') @> to_jsonb(array[d])
     and (target is null or wk+d-1<target) then days:=array_append(days,d); end if;
 end loop;
 if cardinality(days)=0 then raise exception 'No free day of at least 25 minutes'; end if;
 if p_input->>'capacity_minutes' is not null and (p_input->>'capacity_minutes')::integer<30 then
   foreach d in array days loop
     exit when jsonb_array_length(sessions)=2;
     if cardinality(selected_days)>0 and d-selected_days[cardinality(selected_days)]<2 then continue; end if;
     if (p_input->'availability'->>d::text)::integer>=30 then
       sessions:=sessions||jsonb_build_array(public.running_walk_run_v1()||jsonb_build_object('date',wk+d-1));
       selected_days:=array_append(selected_days,d);
     end if;
   end loop;
   if jsonb_array_length(sessions)=0 then raise exception 'No free day of at least 30 minutes'; end if;
   return jsonb_build_object('policy_version','running_2k_v6','catalog_version','running_catalog_v2',
     'week_start',wk,'target_date',target,'anchor_seconds',anchor,'basis','introductory','outcome','maintain','goal',goal_info,'control_due',control_due,
     'phase','reentry','mode','reentry','reason','Caminar y trotar según capacidad actual; confirmar nueva capacidad antes de progresar',
     'normal_budget',30*jsonb_array_length(sessions),'load_weeks',0,'rotation',0,
     'sessions',sessions,'evidence',ev,'changes','[]'::jsonb,'rejected','[]'::jsonb,
     'intense_work_seconds',0,'calibration','provisional');
 end if;
 recent_days := coalesce((p_input->'recent_days'->>0)::integer,0);
 latest_minutes := coalesce((p_input->'recent_minutes'->>0)::integer,0);
 select least(latest_minutes,coalesce(avg(value::integer)::integer,0)) into baseline
 from jsonb_array_elements_text(p_input->'recent_minutes');
 select count(*),count(*) filter(where o->'signal'->>'status'='tolerated'),
   count(*) filter(where o->'signal'->>'status'='struggle'),
   count(*) filter(where o->'signal'->>'status' in ('missing','unknown')),
   count(*) filter(where o->'signal'->>'status'='off_intent'),
   count(*) filter(where o->'signal'->>'status'='pain'),
   count(*) filter(where o->'signal'->>'status'='unknown'),
   count(*) filter(where o->'signal'->>'status'='missing')
 into n,good,bad,missing,off_intent,pain,unknown_count,omitted
 from jsonb_array_elements(obs) o where (o->>'date')::date>=wk-7;
 if pain>0 then raise exception 'Update health status after discomfort'; end if;
 select count(*) into objective_bad from jsonb_array_elements(obs) o where (o->>'date')::date>=wk-7
   and o->'signal'->>'status'='struggle' and (coalesce((o->'signal'->>'objective_difficulty')::boolean,false) or o->'signal'->>'reason'='abandoned_too_difficult');
 previous_count := coalesce(jsonb_array_length(prev->'sessions'),0);
 changed_anchor := prev ? 'anchor_seconds' and (prev->>'anchor_seconds')::numeric<>anchor;
 if changed_anchor then
   changed:=jsonb_build_array(jsonb_build_object('dimension','anchor_recalibration',
     'from_seconds',prev->'anchor_seconds','to_seconds',anchor));
 end if;
 missed := prev ? 'week_start' and (prev->>'week_start')::date<wk-7;
 last_budget := coalesce((prev->>'normal_budget')::integer,baseline);
 -- Tras dificultad corroborada, la base vuelve a ser la dosis reducida.
 -- No restaurar de golpe el volumen anterior como tras una descarga prevista.
 if prev->>'mode'='global_deload' then
   select sum((s->>'minutes')::integer) into last_budget from jsonb_array_elements(prev->'sessions') s;
 end if;
 block_count := coalesce((prev->>'load_weeks')::integer,0);
 if previous_count>0 then
   outcome := 'maintain'; reason := 'Consolidar con las ejecuciones disponibles';
   budget := greatest(25,last_budget);
   if missed or (n>=previous_count and omitted=n and n>0) then
     budget:=greatest(25,floor(budget*0.75)::integer); mode:='reentry'; outcome:='reduce';
     reason:='Semana sin continuidad: reentrada sin recuperar sesiones perdidas';
   elsif objective_bad>=2 or (objective_bad>0 and (select count(*) from jsonb_array_elements(obs) o
     where (o->>'date')::date>=wk-14 and o->'signal'->>'status'='struggle' and (coalesce((o->'signal'->>'objective_difficulty')::boolean,false) or o->'signal'->>'reason'='abandoned_too_difficult'))>=2) then
     mode:='global_deload'; outcome:='reduce'; reason:='Dificultad repetida: reducción global';
   elsif off_intent>=2 then
     mode:='intensity_deload'; reason:='Varias sesiones demasiado rápidas: recuperar la intención fácil';
   elsif bad=0 and missing=0 and off_intent=0 and good>=previous_count and not changed_anchor then
     outcome:='progress'; reason:='Respuesta repetible: progresar una variable si cabe';
   elsif changed_anchor then reason:='Nueva referencia: recalibrar ritmos y consolidar dosis';
   elsif unknown_count>0 then reason:='Sesiones registradas con información insuficiente: mantener sin inferir inactividad';
   elsif n<previous_count then reason:='Faltan registros de la semana: mantener sin asumir que no entrenaste';
   elsif bad=1 then reason:='Un día difícil: consolidar, sin concluir pérdida de forma';
   elsif bad>=2 and objective_bad=0 then reason:='Dosis completada con esfuerzo alto declarado: mantener y revisar la escala RPE';
   end if;
   if prev->>'mode'='global_deload' and mode='normal' then
     mode:='reentry'; outcome:='maintain';
     reason:='Consolidar la dosis reducida antes de recuperar calidad y volumen';
   end if;
 else
   basis := case when latest_minutes=0 then
     case when coalesce((p_input->>'capacity_minutes')::integer,0)>=30 then 'returning' else 'introductory' end
     else 'recent' end;
   if basis='introductory' then raise exception 'Current running capacity needs walk run protocol'; end if;
   budget := greatest(30,baseline);
   if latest_minutes=0 then budget:=60; end if;
   if baseline>=50 and recent_days>=2 then budget:=greatest(60,baseline); end if;
 end if;
 weeks_left := case when target is not null then (target-wk)/7 end;
 phase:=case when target is not null and target-wk<=7 then 'taper'
   when target is not null and target-wk<=28 then 'specific'
   when target is not null and target-wk<=56 then 'build' else 'general' end;
 -- Oportunidad de descarga 2:1 o 3:1. Solo con carga de calidad acumulada;
 -- las semanas vacías no cuentan como carga y el taper tiene prioridad.
 select count(*) into exposures from jsonb_array_elements(obs) o
 where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated'
   and (o->>'date')::date>=wk-21;
 if mode='normal' and block_count>=(case when last_budget<120 or cardinality(strength)>1 then 2 else 3 end)
   and exposures>=2 then mode:='intensity_deload'; reason:='Descarga de intensidad tras carga acumulada'; end if;
 if phase='taper' then mode:='taper'; outcome:='reduce'; reason:='Puesta a punto por proximidad de la prueba'; end if;
 if mode in ('global_deload','taper') then
   budget:=greatest(25,floor(budget*case when mode='taper' then 0.60 else 0.75 end)::integer);
 end if;
 -- Conservar frecuencia durante una reducción si caben salidas mínimas.
 if previous_count>0 and mode in ('reentry','global_deload','taper') then
   budget:=greatest(budget,least(previous_count,cardinality(days))*25);
 end if;
 cnt:=least(5,cardinality(days),greatest(1,budget/25));
 if previous_count=0 then cnt:=least(cnt,greatest(2,recent_days));
 elsif outcome<>'progress' then cnt:=least(cnt,previous_count);
 else cnt:=least(cnt,previous_count+1); end if;
 -- No comprar otro día a costa de perder una calidad conocida. Primero
 -- debe caber completa junto al suelo de las otras salidas, con igual volumen.
 if cnt>previous_count and previous_count>0 and not need_control then
   select o->'session' into last_session from jsonb_array_elements(obs) o
    where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated'
     and not coalesce((o->'session'->>'taper')::boolean,false)
    order by o->>'date' desc limit 1;
   if last_session is not null then
    frequency_probe:=public.running_session_v2(last_session->>'family',
      (last_session->>'step')::int,anchor,180,case when changed_anchor then 1 else coalesce((last_session->>'speed_factor')::numeric,1) end);
    minimum_quality_minutes:=ceil((10800-(frequency_probe->'segments'->-1->>'seconds')::int+360)/60.0)::int;
    if budget<minimum_quality_minutes+(cnt-1)*25 then
     cnt:=previous_count;
     recommendations:=recommendations||jsonb_build_array(jsonb_build_object(
      'code','frequency_preserves_known_quality','message',
      'Conservamos las salidas actuales para que el trabajo conocido quepa completo; ampliar días aún lo desplazaría.'));
    end if;
   end if;
 end if;
 if previous_count>0 and cnt<>previous_count then
   progressed:=true;
   changed:=changed||jsonb_build_array(jsonb_build_object('dimension','frequency','from',previous_count,'to',cnt));
 end if;
 -- Repartir la frecuencia por la semana; no eliminar días fáciles solo por
 -- ser contiguos. La separación exigente se decide para T/V/S/R.
 for i in 1..cnt loop
   d:=days[1+round((i-1)*(cardinality(days)-1)::numeric/greatest(1,cnt-1))::integer];
   selected_days:=array_append(selected_days,d);
 end loop;
 can_quality:=cnt>=2 and (recent_days>=2 or good>=2) and budget>=55
   and not need_control and mode='normal' and basis<>'returning';
 if previous_count>0 and mode='normal' and good>=2 and budget>=55 then can_quality:=not need_control; end if;
 if bad>0 or missing>0 or off_intent>0 then
   can_quality:=can_quality and exists(select 1 from jsonb_array_elements(prev->'sessions') s
     where s->>'family' in ('T','V','S'));
 end if;
 -- Dos calidades también pueden caber en tres días, tras tolerancia real.
 -- Ventana alcanzable con una calidad semanal y descargas: cuatro
 -- exposiciones en seis semanas, en tres semanas distintas y dos recientes.
 select count(*),count(distinct date_trunc('week',(o->>'date')::date))
 into eligible_exposures,eligible_weeks from jsonb_array_elements(obs) o
 where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated'
   and (o->>'date')::date>=wk-(selection_cfg->>'quality_history_days')::int;
 select coalesce(max(work),0)::int into tolerated_work from (
   select sum((o->'session'->>'work_seconds')::int) work
   from jsonb_array_elements(obs) o where o->'session'->>'family' in ('T','V','S')
     and o->'signal'->>'status'='tolerated' and (o->>'date')::date>=wk-28
     and abs((o->'session'->>'anchor_seconds')::numeric/anchor-1)<=0.03
   group by date_trunc('week',(o->>'date')::date)) x;
 select coalesce(max(q.n),0)::int into prior_quality from (
   select count(*) n from jsonb_array_elements(obs) o
   where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated'
     and (o->>'date')::date>=wk-28 group by date_trunc('week',(o->>'date')::date)) q;
 work_cap:=floor(tolerated_work*(selection_cfg->>'work_growth_limit')::numeric)::int;
 reserve_second:=can_quality and cnt>=(selection_cfg->>'two_quality_min_days')::int
   and budget>=(selection_cfg->>'two_quality_min_minutes')::int
   and eligible_exposures>=(selection_cfg->>'required_quality_exposures')::int
   and eligible_weeks>=(selection_cfg->>'required_quality_weeks')::int
   and exposures>=(selection_cfg->>'required_recent_quality')::int
   and good>=previous_count and previous_count>0 and not progressed and (not changed_anchor or prior_quality>=2)
   and not exists(select 1 from jsonb_array_elements(obs) o
     where (o->>'date')::date>=wk-(selection_cfg->>'adverse_days')::int
       and o->'signal'->>'status'<>'tolerated');
 cycle:=case phase when 'general' then array['T','V','S'] else array['S','T','V'] end;
 priority:=case when phase in ('build','specific') then 'S'
   else cycle[1+mod(coalesce((prev->>'rotation')::integer,0),3)] end;
 -- El formato del examen gana prioridad al acercarse la prueba. Conserva
 -- puertas de entrada, tendencias, recuperación y alternativas completas.
 if ev->'families'->'T'->>'trend'='improving' and ev->'families'->'E'->>'trend'='improving'
   and ev->'families'->'S'->>'trend' in ('stable','worsening') then
   priority:='S'; reason:=reason||'; mejora sostenida con especificidad rezagada';
 elsif ev->'families'->'S'->>'trend'='improving' and ev->'families'->'T'->>'trend' in ('stable','worsening') then
   priority:='T'; reason:=reason||'; reforzar trabajo sostenido';
 end if;
 if ev->'families'->'V'->>'trend'='improving' and tests->>'trend' in ('stable','worsening') then
   priority:='T'; reason:=reason||'; series mejoran sin transferencia al 2 km: consolidar trabajo sostenido';
 end if;
 if (select count(*) from jsonb_each(ev->'families') where value->>'trend'='worsening')>=2
   and objective_bad>0 then
   mode:='global_deload'; outcome:='reduce'; can_quality:=false;
   budget:=greatest(cnt*25,floor(budget*0.75)::integer);
   reason:='Empeoramiento comparable de varias familias y esfuerzo alto';
 end if;
 -- Reservar la segunda calidad no puede bloquear la progresión de una
 -- sola mientras aún falta dosis tolerada para que quepan ambas entradas.
 -- La reserva no debe retener una progresión si la pareja aún usa una
 -- familia desconocida y el colocador necesariamente la rechazará.
 reserve_second:=reserve_second
   and exists(select 1 from jsonb_array_elements(obs) o where o->'session'->>'family'=priority and o->'signal'->>'status'='tolerated')
   and exists(select 1 from jsonb_array_elements(obs) o where o->'session'->>'family'=case when priority='T' then 'V' else 'T' end and o->'signal'->>'status'='tolerated')
   and mode='normal' and can_quality
   and work_cap>=(public.running_session_v2(priority,
       case when priority='S' then 0 else -1 end,anchor,180)->>'work_seconds')::int
     +(public.running_session_v2(case when priority='T' then 'V' else 'T' end,
       -1,anchor,180)->>'work_seconds')::int;
 -- Distribución inicial limitada por la disponibilidad. Los minutos se pueden
 -- transferir después a calidad, manteniendo el mismo presupuesto semanal.
 allocations:=array_fill(25,array[cnt]);
 spare:=greatest(0,budget-cnt*25);
 loop
   assigned:=0;
   for j in 1..cnt loop
     capacity:=least(60,(p_input->'availability'->>selected_days[j]::text)::int);
     if spare>0 and allocations[j]<capacity then
       allocations[j]:=allocations[j]+1; spare:=spare-1; assigned:=assigned+1;
     end if;
   end loop;
   exit when spare=0 or assigned=0;
 end loop;
 for i in 1..cnt loop
   d:=selected_days[i];
   available:=least(60,(p_input->'availability'->>d::text)::integer);
   minutes:=allocations[i];
   chosen:='E'; dose_step:=0; factor:=1;
   if can_quality and quality_count<max_quality
     and not exists(select 1 from unnest(strength) x where abs(x-d)<=1 or abs(x-d)=6)
     and not exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::integer-d)<=1)
     and not exists(select 1 from unnest(quality_days) x where abs(x-d)<=1)
     and not exists(select 1 from jsonb_array_elements(obs) o
       where (o->>'date')::date=wk+d-2 and o->'session'->>'family' in ('T','V','S','R')) then
     requested_family:=priority;
     choices:=array[priority]||array_remove(cycle,priority);
     foreach f in array choices loop
     if f='T' and exists(select 1 from jsonb_array_elements(sessions) x where x->>'family'='T') then f:='V'; end if;
     if progressed and not exists(select 1 from jsonb_array_elements(obs) o where o->'session'->>'family'=f and o->'signal'->>'status'='tolerated') then
       select o->'session'->>'family' into f from jsonb_array_elements(obs) o
       where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated' order by o->>'date' desc limit 1;
       f:=coalesce(f,'T');
     end if;
     if f='S' and (select count(*) from jsonb_array_elements(obs) o
       where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated')<2 then
       rejected:=rejected||jsonb_build_array(jsonb_build_object('family','S','reason','needs_prior_quality_tolerance'));
       f:='T';
     end if;
     select o->'session' into last_session from jsonb_array_elements(obs) o
       where o->'session'->>'family'=f order by o->>'date' desc limit 1;
     held_step:=coalesce((last_session->>'step')::integer,0);
     dose_step:=held_step;
     previous_factor:=coalesce((last_session->>'speed_factor')::numeric,1);
     factor:=case when changed_anchor then 1 else previous_factor end;
     dose_evidence:=public.running_dose_evidence_v6(p_input->'history',wk,f,held_step,anchor,factor);
     same_good:=(dose_evidence->>'compatible_successes')::int;
     select jsonb_array_length(value->'steps')-1 into max_step
       from jsonb_array_elements(public.running_catalog_v1()) where value->>'family'=f;
     if same_good>=(cfg->>'required_successes')::integer and outcome='progress' and not progressed and (not reserve_second or prior_quality>=2) and not changed_anchor then dose_step:=least(max_step,held_step+1); end if;
     if f='S' and dose_step>=6 then
       select count(*) into successes from jsonb_array_elements(obs) o
         where o->'session'->>'family'='S' and (o->'session'->>'step')::integer>=4
         and o->'signal'->>'status'='tolerated';
       if successes<4 then dose_step:=least(5,held_step); end if;
     end if;
     previous_factor:=coalesce((last_session->>'speed_factor')::numeric,1);
     factor:=case when changed_anchor then 1 else previous_factor end;
     -- La meta no acredita un ritmo de entrenamiento. Se progresa la dosis
     -- compatible; las marcas reales siguen recalibrando ritmos por separado.
     fit:=public.running_fit_slot_v4(f,dose_step,anchor,factor,i,allocations,selected_days,p_input->'availability',sessions);
     if fit is null then
       rejected:=rejected||jsonb_build_array(jsonb_build_object('day',d,'family',f,'step',dose_step,'reason','does_not_fit'));
       -- Antes de reducir al formato anterior, intentar otro día ya elegido.
       -- No añade días, minutos ni calidad junto a piernas u otra calidad.
       defer_quality:=false;
       if f=requested_family and dose_step>held_step then
        for j in i+1..cnt loop
         future_day:=selected_days[j];
         if exists(select 1 from unnest(strength) x where abs(x-future_day)<=1 or abs(x-future_day)=6)
          or exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::int-future_day)<=1)
          or exists(select 1 from unnest(quality_days) x where abs(x-future_day)<=1)
          or exists(select 1 from jsonb_array_elements(obs) o where (o->>'date')::date=wk+future_day-2 and o->'session'->>'family' in ('T','V','S','R')) then continue; end if;
         future_fit:=public.running_fit_slot_v4(f,dose_step,anchor,factor,j,allocations,selected_days,p_input->'availability',sessions);
         if future_fit is not null then defer_quality:=true; exit; end if;
        end loop;
       end if;
       if defer_quality then
        recommendations:=recommendations||jsonb_build_array(jsonb_build_object('code','quality_later_slot',
         'message','El formato que ya puedes probar cabe completo en otro día previsto; hoy conservamos carrera fácil.'));
        exit;
       end if;
       dose_step:=held_step;
       factor:=case when changed_anchor then 1 else previous_factor end;
       fit:=public.running_fit_slot_v4(f,dose_step,anchor,factor,i,allocations,selected_days,p_input->'availability',sessions);
     end if;
     if fit is null then continue; end if;
     candidate:=(fit->'session')||jsonb_build_object('progression_evidence',dose_evidence); sessions:=fit->'sessions';
     select array_agg(value::int order by ord) into allocations
       from jsonb_array_elements_text(fit->'allocations') with ordinality x(value,ord);
     minutes:=allocations[i];
     if (fit->>'redistributed_minutes')::int>0 then
       changed:=changed||jsonb_build_array(jsonb_build_object('dimension','redistribute_easy_minutes',
         'family',f,'minutes',(fit->>'redistributed_minutes')::int));
     end if;
     if f<>requested_family then
       changed:=changed||jsonb_build_array(jsonb_build_object('dimension','compatible_quality_alternative',
         'requested_family',requested_family,'selected_family',f));
       recommendations:=recommendations||jsonb_build_array(jsonb_build_object('code','quality_slot',
         'message','La sesión prioritaria no cabe completa. Usamos otra calidad compatible; disponer de 45 minutos en un día ofrece más opciones, sin obligarte a entrenarlos todos.'));
     end if;
     if candidate is not null then
       chosen:=f; quality_count:=quality_count+1; quality_days:=array_append(quality_days,d);
       if last_session is null then
         progressed:=true;
         changed:=changed||jsonb_build_array(jsonb_build_object('family',f,'dimension','introduce_stimulus'));
       end if;
       if dose_step<>held_step or factor<>previous_factor then
         progressed:=true;
         changed:=changed||jsonb_build_array(jsonb_build_object('family',f,
           'dimension',case when factor<>previous_factor then 'speed' else 'dose_step' end,
           'from_step',held_step,'to_step',dose_step,'from_factor',previous_factor,'to_factor',factor));
       end if;
     end if;
     exit;
     end loop;
   end if;
   if chosen='E' then
     -- Una exposición R breve es opcional, después de E tolerada, separada
     -- también de piernas/familias intensas. Nunca convierte R en esprint máximo.
     if mode='normal' and not progressed and not reserve_second and good>=2 and cnt>=3 and i=cnt and not need_control and minutes>=30
       and mod(coalesce((prev->>'rotation')::integer,0),2)=0
       and not exists(select 1 from unnest(strength) x where abs(x-d)<=1 or abs(x-d)=6)
       and not exists(select 1 from unnest(quality_days) x where abs(x-d)<=1)
       and not exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::integer-d)<=1)
       and not exists(select 1 from jsonb_array_elements(obs) o where (o->>'date')::date=wk+d-2 and o->'session'->>'family' in ('T','V','S','R')) then
       chosen:='R';
       select o->'session' into last_session from jsonb_array_elements(obs) o
         where o->'session'->>'family'='R' order by o->>'date' desc limit 1;
       held_step:=coalesce((last_session->>'step')::integer,0); dose_step:=held_step;
       select count(*) into same_good from jsonb_array_elements(obs) o where o->'session'->>'family'='R'
         and (o->'session'->>'step')::integer=held_step and o->'signal'->>'status'='tolerated';
       if same_good>=2 and outcome='progress' and not changed_anchor then dose_step:=least(2,held_step+1); end if;
       if last_session is null or dose_step<>held_step then
         progressed:=true;
         changed:=changed||jsonb_build_array(jsonb_build_object('family','R','dimension',
           case when last_session is null then 'introduce_stimulus' else 'dose_step' end,'from_step',held_step,'to_step',dose_step));
       end if;
     end if;
     if chosen='E' and p_input->>'capacity_minutes' is not null then
       minutes:=least(minutes,greatest(25,(p_input->>'capacity_minutes')::integer)); end if;
     allocations[i]:=minutes;
     candidate:=public.running_session_v1(chosen,case when chosen='R' then dose_step else 0 end,anchor,minutes);
   end if;
   if candidate is null then candidate:=public.running_session_v1('E',0,anchor,minutes); end if;
   if mode='taper' and i=1 and not need_control and target-wk>=4
     and not exists(select 1 from unnest(strength) x where abs(x-d)<=1 or abs(x-d)=6)
     and not exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::integer-d)<=1)
       and not exists(select 1 from jsonb_array_elements(obs) o where (o->>'date')::date=wk+d-2 and o->'session'->>'family' in ('T','V','S','R')) then
     select o->'session' into last_session from jsonb_array_elements(obs) o
       where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated'
         and (o->'session'->>'anchor_seconds')::numeric=anchor
       order by o->>'date' desc limit 1;
     if last_session is not null then
       session:=public.running_taper_session_v1(last_session,minutes);
       if session is not null then candidate:=session; quality_days:=array_append(quality_days,d); end if;
     end if;
   end if;
   if need_control then
     candidate:=candidate||jsonb_build_object('pace_basis','effort_only_expired_anchor',
       'segments',jsonb_build_array(jsonb_build_object('role','work','seconds',minutes*60)));
   end if;
   sessions:=sessions||jsonb_build_array(candidate||jsonb_build_object('date',wk+d-1));
   used:=used+minutes;
 end loop;
 -- Repartir calidad solo entre familias conocidas y con una cota de trabajo
 -- tolerado: una segunda sesión no duplica automáticamente el estímulo.
 if reserve_second and (not progressed or prior_quality>=2) then
   pairing:=public.running_second_quality_v4(sessions,obs,p_input,work_cap);
   if pairing is not null then
     sessions:=pairing->'sessions'; added_second:=true;
     -- Mantener dos estímulos ya tolerados no consume la progresión semanal.
     select count(*)=2 into pairing_unchanged
     from jsonb_array_elements(sessions) next_s
     where next_s->>'family' in ('T','V','S')
       and exists(select 1 from jsonb_array_elements(coalesce(prev->'sessions','[]')) old_s
         where old_s->>'family'=next_s->>'family'
           and old_s->>'step'=next_s->>'step'
           and old_s->>'work_seconds'=next_s->>'work_seconds'
           and coalesce((old_s->>'speed_factor')::numeric,1)=coalesce((next_s->>'speed_factor')::numeric,1));
     if not pairing_unchanged then
       progressed:=true;
       changed:=changed||jsonb_build_array(jsonb_build_object('dimension','quality_frequency_or_dose',
         'to',2,'work_cap_seconds',work_cap,'first_step',pairing->'first_step',
         'second_family',pairing->'second_family',
         'entry_variant',coalesce(pairing->>'entry_variant','full_entry_v1')));
     end if;
   else
     rejected:=rejected||jsonb_build_array(jsonb_build_object('reason','second_quality_dose_or_calendar_does_not_fit','work_cap_seconds',work_cap));
   end if;
 end if;
 select sum((x->>'minutes')::int) into used from jsonb_array_elements(sessions) x;
 -- Progresar volumen fácil solo si no cambió la dosis/calidad ni el ancla.
 if outcome='progress' and not progressed and mode='normal' and not changed_anchor then
   for i in 0..jsonb_array_length(sessions)-1 loop
     session:=sessions->i; d:=extract(isodow from (session->>'date')::date)::integer;
     if session->>'family'='E' and (session->>'minutes')::integer+5<=least(60,(p_input->'availability'->>d::text)::integer)
       and (session->>'minutes')::integer+5<=coalesce((p_input->>'capacity_minutes')::integer,60) then
       candidate:=public.running_session_v1(session->>'family',(session->>'step')::integer,anchor,(session->>'minutes')::integer+5,coalesce((session->>'speed_factor')::numeric,1));
       if not need_control then
         sessions:=jsonb_set(sessions,array[i::text],candidate||jsonb_build_object('date',session->>'date'));
         used:=used+5; progressed:=true;
         changed:=changed||jsonb_build_array(jsonb_build_object('family',session->>'family','dimension','easy_minutes','delta',5));
       end if;
       exit;
     end if;
   end loop;
 end if;
 if can_quality and quality_count=0 then
   recommendations:=recommendations||jsonb_build_array(jsonb_build_object('code','quality_calendar',
     'message','No ha cabido una sesión de calidad completa con la separación necesaria. Revisa los días disponibles y las reservas de fuerza; mantenemos una pauta fácil mientras esas restricciones sigan activas.'));
 end if;
 return jsonb_build_object('policy_version','running_2k_v6','catalog_version','running_catalog_v2',
   'selection_version','running_selection_v6','selection_policy',selection_cfg,'recommendations',recommendations,
   'quality_entry',jsonb_build_object('exposures_42d',eligible_exposures,'weeks',eligible_weeks,
     'exposures_21d',exposures,'work_cap_seconds',work_cap,'eligible',reserve_second,'paired',added_second),
   'week_start',wk,'target_date',target,'anchor_seconds',anchor,'goal_seconds',goal_seconds,
   'goal',goal_info,'control_due',control_due,'control_review',tests,
   'rpe_review_required',bad>=2 and objective_bad=0,
   'data_review_required',unknown_count>0 or n<previous_count,
   'target_gap',case when goal_seconds>0 then anchor/goal_seconds-1 end,
   'phase',phase,'mode',mode,'basis',basis,'outcome',outcome,'reason',reason,
   'normal_budget',case when mode in ('global_deload','intensity_deload','taper') then last_budget else used end,
   'load_weeks',case when mode<>'normal' then 0 else block_count+1 end,
   'rotation',coalesce((prev->>'rotation')::integer,0)+case when quality_count>0 and not changed_anchor then 1 else 0 end,
   'priority',priority,'evidence',ev,'sessions',sessions,'changes',changed,'rejected',rejected,
   'needs_control',need_control,'calibration','provisional',
   'intense_work_seconds',(select coalesce(sum((s->>'work_seconds')::integer),0) from jsonb_array_elements(sessions) s where s->>'family' in ('T','V','S')),
   'input_snapshot',p_input-'history');
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
 where sw.user_id=u and sw.status not in ('cancelled') and wd.policy_version in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5','running_2k_v6') and not coalesce(rs.prescription,'{}'::jsonb) ? 'control'
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
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5','running_2k_v6') then
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
 -- La selección deportiva usa v6; la evidencia usa la realización real.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 result:=public.running_plan_v6(input);
 return result||jsonb_build_object('capacity_evidence',capacity_evidence,'evidence_policy_version','adaptive_evidence_v1','goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

revoke all on function public.running_plan_v6(jsonb) from public,anon,authenticated;

commit;
