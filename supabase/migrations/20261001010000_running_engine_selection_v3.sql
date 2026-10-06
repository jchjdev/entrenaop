-- Revisión del encaje y de la entrada a dos calidades. V1/v2 conservan su
-- comportamiento para reproducir decisiones históricas; el adaptador usa v3.
begin;

create function public.running_selection_policy_v3() returns jsonb
language sql immutable set search_path='' as $$ select '{
 "quality_history_days":42,"required_quality_exposures":4,
 "required_quality_weeks":3,"recent_quality_days":21,
 "required_recent_quality":2,"adverse_days":14,
 "two_quality_min_minutes":120,"two_quality_min_days":3,
 "work_growth_limit":1.20,"session_floor_minutes":25,
 "recommended_quality_slot_minutes":45
}'::jsonb $$;

-- Encajar la dosis COMPLETA. Solo se transfieren minutos fáciles, nunca se
-- recorta calentamiento, recuperación o una repetición para hacerla caber.
create function public.running_fit_slot_v3(
 p_family text,p_step int,p_anchor numeric,p_factor numeric,p_slot int,
 p_alloc int[],p_days int[],p_availability jsonb,p_sessions jsonb
) returns jsonb language plpgsql immutable set search_path='' as $$
declare s jsonb; probe jsonb; alloc int[]:=p_alloc; sessions jsonb:=p_sessions;
 needed int; extra int; take int; j int; floor_minutes int:=25;
begin
 probe:=public.running_session_v1(p_family,p_step,p_anchor,180,p_factor);
 needed:=ceil((180*60-(probe->'segments'->-1->>'seconds')::int+360)/60.0)::int;
 needed:=greatest(alloc[p_slot],needed);
 if needed>least(60,(p_availability->>p_days[p_slot]::text)::int) then return null; end if;
 extra:=needed-alloc[p_slot];
 for j in reverse cardinality(alloc)..1 loop
   exit when extra=0;
   if j=p_slot then continue; end if;
   -- Los días ya construidos solo donan si siguen siendo fáciles.
   if j<=jsonb_array_length(sessions) and sessions->(j-1)->>'family'<>'E' then continue; end if;
   take:=least(extra,greatest(0,alloc[j]-floor_minutes));
   if take=0 then continue; end if;
   alloc[j]:=alloc[j]-take; extra:=extra-take;
   if j<=jsonb_array_length(sessions) then
     s:=sessions->(j-1);
     sessions:=jsonb_set(sessions,array[(j-1)::text],
       public.running_session_v1('E',0,p_anchor,alloc[j])||jsonb_build_object('date',s->'date'));
   end if;
 end loop;
 if extra>0 then return null; end if;
 alloc[p_slot]:=needed;
 s:=public.running_session_v1(p_family,p_step,p_anchor,needed,p_factor);
 return jsonb_build_object('session',s,'allocations',alloc,'sessions',sessions,
   'redistributed_minutes',needed-p_alloc[p_slot]);
end $$;

-- La segunda calidad reparte una dosis semanal ya próxima a la tolerada.
-- Se prueban escalones conocidos de la primera y entrada de la segunda,
-- sin subir ritmo, volumen semanal ni frecuencia total simultáneamente.
create function public.running_second_quality_v3(
 p_sessions jsonb,p_observations jsonb,p_input jsonb,p_work_cap int
) returns jsonb language plpgsql immutable set search_path='' as $$
declare sessions jsonb:=p_sessions; first_s jsonb; second_s jsonb; fit jsonb;
 alloc int[]; days int[]; first_idx int; j int; k int; step int; d int;
 f text; secondary text; anchor numeric:=(p_input->>'anchor_seconds')::numeric;
begin
 select ord::int into first_idx from jsonb_array_elements(sessions) with ordinality x(s,ord)
 where s->>'family' in ('T','V','S') limit 1;
 if first_idx is null then return null; end if;
 first_s:=sessions->(first_idx-1); f:=first_s->>'family';
 secondary:=case when f='T' then 'V' else 'T' end;
 -- No se estrenan dos estímulos a la vez ni se usa una familia desconocida.
 if not exists(select 1 from jsonb_array_elements(p_observations) o
   where o->'session'->>'family'=f and o->'signal'->>'status'='tolerated')
   or not exists(select 1 from jsonb_array_elements(p_observations) o
   where o->'session'->>'family'=secondary and o->'signal'->>'status'='tolerated') then return null; end if;
 for j in 1..jsonb_array_length(sessions) loop
   if sessions->(j-1)->>'family'<>'E' then continue; end if;
   d:=extract(isodow from (sessions->(j-1)->>'date')::date)::int;
   if abs((sessions->(j-1)->>'date')::date-(p_sessions->(first_idx-1)->>'date')::date)<2
     or exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'strength_days','[]')) x where abs(x::int-d)<=1 or abs(x::int-d)=6)
     or exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::int-d)<=1)
     or exists(select 1 from jsonb_array_elements(p_observations) o where
       o->'session'->>'family' in ('T','V','S','R') and (o->>'date')::date=(sessions->(j-1)->>'date')::date-1)
     or exists(select 1 from jsonb_array_elements(sessions) s where s->>'family'='R'
       and abs((s->>'date')::date-(sessions->(j-1)->>'date')::date)<2) then continue; end if;
   for step in reverse (p_sessions->(first_idx-1)->>'step')::int..0 loop
     sessions:=p_sessions;
     -- El ritmo conocido se conserva al repartir trabajo; no se acelera.
     first_s:=public.running_session_v1(f,step,anchor,(p_sessions->(first_idx-1)->>'minutes')::int,
       coalesce((p_sessions->(first_idx-1)->>'speed_factor')::numeric,1));
     second_s:=public.running_session_v1(secondary,0,anchor,180);
     if (first_s->>'work_seconds')::int+(second_s->>'work_seconds')::int>p_work_cap then continue; end if;
     sessions:=jsonb_set(sessions,array[(first_idx-1)::text],first_s||jsonb_build_object('date',p_sessions->(first_idx-1)->'date'));
     select array_agg((s->>'minutes')::int order by ord),
       array_agg(extract(isodow from (s->>'date')::date)::int order by ord)
       into alloc,days from jsonb_array_elements(sessions) with ordinality x(s,ord);
     fit:=public.running_fit_slot_v3(secondary,0,anchor,1,j,alloc,days,p_input->'availability',sessions);
     if fit is null then continue; end if;
     sessions:=jsonb_set(fit->'sessions',array[(j-1)::text],fit->'session'||jsonb_build_object('date',p_sessions->(j-1)->'date'));
     return jsonb_build_object('sessions',sessions,'first_step',step,'second_family',secondary);
   end loop;
 end loop;
 return null;
end $$;

create function public.running_plan_v3(p_input jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
 cfg jsonb:=public.running_policy_v1();
 selection_cfg jsonb:=public.running_selection_policy_v3();
 allocations int[]; fit jsonb; pairing jsonb; requested_family text; choices text[];
 j int; spare int; assigned int; capacity int; prior_quality int;
 eligible_exposures int; eligible_weeks int; work_cap int; tolerated_work int;
 reserve_second boolean:=false; added_second boolean:=false;
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
   return jsonb_build_object('policy_version','running_2k_v3','catalog_version','running_catalog_v1',
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
 priority:=cycle[1+mod(coalesce((prev->>'rotation')::integer,0),3)];
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
 reserve_second:=reserve_second and mode='normal' and can_quality
   and work_cap>=(public.running_session_v1(priority,0,anchor,180)->>'work_seconds')::int
     +(public.running_session_v1(case when priority='T' then 'V' else 'T' end,0,anchor,180)->>'work_seconds')::int;
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
     select count(*) into same_good from jsonb_array_elements(obs) o
       where o->'session'->>'family'=f and (o->'session'->>'step')::integer=held_step
       and abs((o->'session'->>'anchor_seconds')::numeric/anchor-1)<=0.03
       and not coalesce((o->'session'->>'taper')::boolean,false)
       and coalesce((o->'session'->>'speed_factor')::numeric,1)=coalesce((last_session->>'speed_factor')::numeric,1)
       and o->'signal'->>'status'='tolerated';
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
     -- Objetivo cercano: primero tolerar dos exposiciones cortas actuales.
     -- Brechas grandes no se persiguen de golpe; como máximo +3 % de velocidad.
     if f='S' and goal_seconds is not null and goal_seconds<anchor and same_good>=2
       and held_step<=2 and outcome='progress' and not progressed and (not reserve_second or prior_quality>=2) and not changed_anchor and factor=1 then
       factor:=least(1+(cfg->>'goal_step_max')::numeric,anchor/goal_seconds); dose_step:=held_step;
     end if;
     fit:=public.running_fit_slot_v3(f,dose_step,anchor,factor,i,allocations,selected_days,p_input->'availability',sessions);
     if fit is null then
       rejected:=rejected||jsonb_build_array(jsonb_build_object('day',d,'family',f,'step',dose_step,'reason','does_not_fit'));
       dose_step:=held_step;
       factor:=case when changed_anchor then 1 else previous_factor end;
       fit:=public.running_fit_slot_v3(f,dose_step,anchor,factor,i,allocations,selected_days,p_input->'availability',sessions);
     end if;
     if fit is null then continue; end if;
     candidate:=fit->'session'; sessions:=fit->'sessions';
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
   pairing:=public.running_second_quality_v3(sessions,obs,p_input,work_cap);
   if pairing is not null then
     sessions:=pairing->'sessions'; progressed:=true; added_second:=true;
     changed:=changed||jsonb_build_array(jsonb_build_object('dimension',case when prior_quality>=2 then 'maintain_two_qualities' else 'quality_frequency' end,
       'to',2,'work_cap_seconds',work_cap,'first_step',pairing->'first_step',
       'second_family',pairing->'second_family'));
   else
     rejected:=rejected||jsonb_build_array(jsonb_build_object('reason','second_quality_dose_or_calendar_does_not_fit','work_cap_seconds',work_cap));
   end if;
 end if;
 select sum((x->>'minutes')::int) into used from jsonb_array_elements(sessions) x;
 -- Progresar volumen fácil solo si no cambió la dosis/calidad ni el ancla.
 if outcome='progress' and not progressed and mode='normal' and not changed_anchor then
   for i in 0..jsonb_array_length(sessions)-1 loop
     session:=sessions->i; d:=extract(isodow from (session->>'date')::date)::integer;
     if session->>'family' in ('E','T','V','S') and (session->>'minutes')::integer+5<=least(60,(p_input->'availability'->>d::text)::integer)
       and (session->>'family'<>'E' or (session->>'minutes')::integer+5<=coalesce((p_input->>'capacity_minutes')::integer,60)) then
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
 return jsonb_build_object('policy_version','running_2k_v3','catalog_version','running_catalog_v1',
   'selection_policy',selection_cfg,'recommendations',recommendations,
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


create or replace function public.calculate_running_week_core(
 p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 ctx public.running_intake_contexts%rowtype; ref record; age integer;
 last_sunday date:=current_date-extract(isodow from current_date)::integer;
 prev public.running_week_decisions%rowtype; existing public.running_week_decisions%rowtype;
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<last_sunday-6 or p_week_start>current_date+28 then
   raise exception 'Choose a current or upcoming complete week'; end if;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 if not p_replay_initial then
   select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start;
   if found then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
   select * into prev from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start order by week_start desc limit 1;
 end if;
 if prev.id is not null and current_date<p_week_start-1 and not p_preview_future then
   raise exception 'Close the previous week before adapting'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=p_goal_id;
 if not found or ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
   or (prev.id is null and ctx.recent_weeks_end_on<>last_sunday) then
   raise exception 'Update the current running context'; end if;
 if ctx.reports_pain or ctx.requires_professional_review then raise exception 'Health flag pauses the automatic proposal'; end if;
 select * into ref from jsonb_to_record(public.resolve_program_running_reference(p_goal_id))
   as x(reference_source text,reference_record_id text,continuity_confirmed_at timestamptz,completed_at timestamptz,value numeric,standard jsonb,controls jsonb);
 standard:=ref.standard; controls:=ref.controls;
 age:=current_date-ref.completed_at::date;
 if age<0 or ref.completed_at>now() then raise exception 'The selected 2 km mark is outside the reuse window'; end if;
 if age>30 and age<=45 and (ref.continuity_confirmed_at is null
   or ctx.recent_weeks_end_on<>last_sunday or 0=any(ctx.running_days_last_four_weeks)) then
   raise exception 'Confirm uninterrupted running before reuse'; end if;
 -- Fuera de ventana no se derivan ritmos. La semana fácil de mantenimiento
 -- solicita un control nuevo; no inventa una mejora ni perpetúa un ancla vieja.
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped')
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',sw.status,'rpe',e.final_rpe,'abandonment_reason',e.abandonment_reason,
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by sw.scheduled_date),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id) sets on true
 where wd.preparation_goal_id=p_goal_id and wd.week_start>=p_week_start-56
   and wd.week_start<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(sw.scheduled_date-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and exists(select 1 from public.workout_blocks b
     where b.template_id=sw.template_id and b.format not in ('running','warm_up','cool_down'));
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2','running_2k_v3') then
   previous:=previous||jsonb_build_object('normal_budget',
     (select sum(planned_minutes) from public.running_week_sessions where decision_id=prev.id),
     'load_weeks',0,'rotation',0);
 end if;
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'capacity_minutes',ctx.comfortable_continuous_minutes,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 result:=public.running_plan_v3(input);
 return result||jsonb_build_object('goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at);
end $$;



revoke all on function public.running_selection_policy_v3(),
 public.running_fit_slot_v3(text,int,numeric,numeric,int,int[],int[],jsonb,jsonb),
 public.running_second_quality_v3(jsonb,jsonb,jsonb,int),public.running_plan_v3(jsonb)
 from public,anon,authenticated;
commit;
