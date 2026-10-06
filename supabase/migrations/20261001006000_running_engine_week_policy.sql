begin;

-- Historial normalizado: misma variante, ancla y ritmo para comparar respuestas.
create function public.running_evidence_v1(p_history jsonb, p_week date)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
 h jsonb; signal jsonb; observations jsonb := '[]'; families jsonb := '{}';
 f text; recent jsonb; old jsonb; trend text; samples integer;
begin
 for h in select value from jsonb_array_elements(coalesce(p_history,'[]'))
   where (value->>'date')::date < p_week and (value->>'date')::date >= p_week-56
   order by (value->>'date')::date loop
   signal := public.running_evaluate_v1(h->'session',h->'execution');
   observations := observations || jsonb_build_array(jsonb_build_object(
     'date',h->'date','session',h->'session','signal',signal));
 end loop;
 foreach f in array array['E','T','V','S','R'] loop
   select value into recent from jsonb_array_elements(observations)
   where value->'session'->>'family'=f
     and value->'signal'->>'status' in ('tolerated','struggle')
   order by value->>'date' desc limit 1;
   -- Cuatro exposiciones con igual dosis, ancla y RPE cercano. No diagnostica
   -- fisiología: informa una tendencia operativa de velocidad a esfuerzo similar.
   select count(*),jsonb_build_object(
     'first',avg(pace) filter(where rn in (3,4)),
     'last',avg(pace) filter(where rn in (1,2))) into samples,old
   from (
     select (o->'signal'->>'pace_seconds_per_km')::numeric pace,
       row_number() over(order by o->>'date' desc) rn
     from jsonb_array_elements(observations) o
     where o->'session'->>'family'=f
       and o->'session'->>'variant_code'=recent->'session'->>'variant_code'
       and o->'session'->>'anchor_seconds'=recent->'session'->>'anchor_seconds'
       and o->'session'->>'speed_factor'=recent->'session'->>'speed_factor'
       and o->'session'->>'minutes'=recent->'session'->>'minutes'
       and o->'signal'->>'status' in ('tolerated','struggle')
       and abs((o->'signal'->>'rpe')::numeric-(recent->'signal'->>'rpe')::numeric)<=1
   ) q where rn<=4;
   trend := case when samples<4 then 'unknown'
     when (old->>'last')::numeric < (old->>'first')::numeric*0.98 then 'improving'
     when (old->>'last')::numeric > (old->>'first')::numeric*1.02 then 'worsening'
     else 'stable' end;
   families := families || jsonb_build_object(f,jsonb_build_object('trend',trend,'samples',samples));
 end loop;
 return jsonb_build_object('observations',observations,'families',families);
end $$;

-- Entrada sin dependencias de FAS ni del reloj: el adaptador obtiene los datos
-- autorizados; el laboratorio llama a esta MISMA función semana tras semana.
create function public.running_plan_v1(p_input jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
 cfg jsonb:=public.running_policy_v1();
 wk date := (p_input->>'week_start')::date;
 target date := (p_input->>'target_date')::date;
 anchor numeric := (p_input->>'anchor_seconds')::numeric;
 goal_seconds numeric := (p_input->>'goal_seconds')::numeric;
 prev jsonb := coalesce(p_input->'previous','{}');
 ev jsonb; obs jsonb; session jsonb; candidate jsonb; last_session jsonb;
 days integer[] := '{}'; selected_days integer[] := '{}'; quality_days integer[] := '{}';
 strength integer[]; d integer; i integer; cnt integer; budget integer; used integer := 0;
 baseline integer; last_budget integer; recent_days integer; latest_minutes integer;
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
 need_control := coalesce((p_input->>'anchor_age_days')::integer,0)>45;
 ev := public.running_evidence_v1(coalesce(p_input->'history','[]'),wk);
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
   return jsonb_build_object('policy_version','running_2k_v1','catalog_version','running_catalog_v1',
     'week_start',wk,'target_date',target,'anchor_seconds',anchor,'basis','introductory','outcome','maintain',
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
   count(*) filter(where o->'signal'->>'status'='pain')
 into n,good,bad,missing,off_intent,pain
 from jsonb_array_elements(obs) o where (o->>'date')::date>=wk-7;
 if pain>0 then raise exception 'Update health status after discomfort'; end if;
 previous_count := coalesce(jsonb_array_length(prev->'sessions'),0);
 changed_anchor := prev ? 'anchor_seconds' and (prev->>'anchor_seconds')::numeric<>anchor;
 if changed_anchor then
   changed:=jsonb_build_array(jsonb_build_object('dimension','anchor_recalibration',
     'from_seconds',prev->'anchor_seconds','to_seconds',anchor));
 end if;
 missed := prev ? 'week_start' and (prev->>'week_start')::date<wk-7;
 last_budget := coalesce((prev->>'normal_budget')::integer,baseline);
 block_count := coalesce((prev->>'load_weeks')::integer,0);
 if previous_count>0 then
   outcome := 'maintain'; reason := 'Consolidar con las ejecuciones disponibles';
   budget := greatest(25,last_budget);
   if missed or (n>0 and good=0 and bad=0 and missing=n) then
     budget:=greatest(25,floor(budget*0.75)::integer); mode:='reentry'; outcome:='reduce';
     reason:='Semana sin continuidad: reentrada sin recuperar sesiones perdidas';
   elsif bad>=2 or (bad>0 and (select count(*) from jsonb_array_elements(obs) o
     where (o->>'date')::date>=wk-14 and o->'signal'->>'status'='struggle')>=2) then
     mode:='global_deload'; outcome:='reduce'; reason:='Dificultad repetida: reducción global';
   elsif off_intent>=2 then
     mode:='intensity_deload'; reason:='Varias sesiones demasiado rápidas: recuperar la intención fácil';
   elsif bad=0 and missing=0 and off_intent=0 and good>=previous_count and not changed_anchor then
     outcome:='progress'; reason:='Respuesta repetible: progresar una variable si cabe';
   elsif changed_anchor then reason:='Nueva referencia: recalibrar ritmos y consolidar dosis';
   elsif bad=1 then reason:='Un día difícil: consolidar, sin concluir pérdida de forma';
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
 if cnt>=4 and budget>=140 and exposures>=2 then max_quality:=2; end if;
 cycle:=case phase when 'general' then array['T','V','S'] else array['S','T','V'] end;
 priority:=cycle[1+mod(coalesce((prev->>'rotation')::integer,0),3)];
 if ev->'families'->'T'->>'trend'='improving' and ev->'families'->'E'->>'trend'='improving'
   and ev->'families'->'S'->>'trend' in ('stable','worsening') then
   priority:='S'; reason:=reason||'; mejora sostenida con especificidad rezagada';
 elsif ev->'families'->'S'->>'trend'='improving' and ev->'families'->'T'->>'trend' in ('stable','worsening') then
   priority:='T'; reason:=reason||'; reforzar trabajo sostenido';
 end if;
 if (select count(*) from jsonb_each(ev->'families') where value->>'trend'='worsening')>=2
   and bad>0 then
   mode:='global_deload'; outcome:='reduce'; can_quality:=false;
   budget:=greatest(cnt*25,floor(budget*0.75)::integer);
   reason:='Empeoramiento comparable de varias familias y esfuerzo alto';
 end if;
 for i in 1..cnt loop
   d:=selected_days[i];
   available:=least(60,(p_input->'availability'->>d::text)::integer);
   minutes:=least(available,greatest(25,(budget-used)/(cnt-i+1)));
   chosen:='E'; dose_step:=0; factor:=1;
   if can_quality and quality_count<max_quality
     and not exists(select 1 from unnest(strength) x where abs(x-d)<=1 or abs(x-d)=6)
     and not exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::integer-d)<=1)
     and not exists(select 1 from unnest(quality_days) x where abs(x-d)<=1)
     and not exists(select 1 from jsonb_array_elements(obs) o
       where (o->>'date')::date=wk+d-2 and o->'session'->>'family' in ('T','V','S','R')) then
     f:=case when quality_count=1 then case when priority='T' then 'V' else 'T' end else priority end;
     if f='T' and exists(select 1 from jsonb_array_elements(sessions) x where x->>'family'='T') then f:='V'; end if;
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
       and (o->'session'->>'anchor_seconds')::numeric=anchor
       and coalesce((o->'session'->>'speed_factor')::numeric,1)=coalesce((last_session->>'speed_factor')::numeric,1)
       and o->'signal'->>'status'='tolerated';
     select jsonb_array_length(value->'steps')-1 into max_step
       from jsonb_array_elements(public.running_catalog_v1()) where value->>'family'=f;
     if same_good>=(cfg->>'required_successes')::integer and outcome='progress' and not progressed then dose_step:=least(max_step,held_step+1); end if;
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
       and held_step<=2 and outcome='progress' and not progressed and factor=1 then
       factor:=least(1+(cfg->>'goal_step_max')::numeric,anchor/goal_seconds); dose_step:=held_step;
     end if;
     candidate:=public.running_session_v1(f,dose_step,anchor,minutes,factor);
     if candidate is null then
       rejected:=rejected||jsonb_build_array(jsonb_build_object('day',d,'family',f,'step',dose_step,'reason','does_not_fit'));
       dose_step:=held_step; factor:=previous_factor;
       candidate:=public.running_session_v1(f,dose_step,anchor,minutes,factor);
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
   end if;
   if chosen='E' then
     -- Una exposición R breve es opcional, después de E tolerada, separada
     -- también de piernas/familias intensas. Nunca convierte R en esprint máximo.
     if mode='normal' and good>=2 and cnt>=3 and i=cnt and not need_control and minutes>=30
       and mod(coalesce((prev->>'rotation')::integer,0),2)=0
       and not exists(select 1 from unnest(strength) x where abs(x-d)<=1 or abs(x-d)=6)
       and not exists(select 1 from unnest(quality_days) x where abs(x-d)<=1)
       and not exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::integer-d)<=1) then
       chosen:='R';
     end if;
     if chosen='E' and p_input->>'capacity_minutes' is not null then
       minutes:=least(minutes,greatest(25,(p_input->>'capacity_minutes')::integer)); end if;
     candidate:=public.running_session_v1(chosen,0,anchor,minutes);
   end if;
   if candidate is null then candidate:=public.running_session_v1('E',0,anchor,minutes); end if;
   if mode='taper' and i=1 and not need_control and target-wk>=4
     and not exists(select 1 from unnest(strength) x where abs(x-d)<=1 or abs(x-d)=6)
     and not exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::integer-d)<=1) then
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
 -- Progresar volumen fácil solo si no cambió la dosis/calidad ni el ancla.
 if outcome='progress' and not progressed and mode='normal' and not changed_anchor then
   for i in 0..jsonb_array_length(sessions)-1 loop
     session:=sessions->i; d:=extract(isodow from (session->>'date')::date)::integer;
     if session->>'family'='E' and (session->>'minutes')::integer+5<=least(60,(p_input->'availability'->>d::text)::integer)
       and (session->>'minutes')::integer+5<=coalesce((p_input->>'capacity_minutes')::integer,60) then
       candidate:=public.running_session_v1('E',0,anchor,(session->>'minutes')::integer+5);
       if not need_control then
         sessions:=jsonb_set(sessions,array[i::text],candidate||jsonb_build_object('date',session->>'date'));
         used:=used+5; progressed:=true;
         changed:=changed||jsonb_build_array(jsonb_build_object('family','E','dimension','minutes','delta',5));
       end if;
       exit;
     end if;
   end loop;
 end if;
 return jsonb_build_object('policy_version','running_2k_v1','catalog_version','running_catalog_v1',
   'week_start',wk,'target_date',target,'anchor_seconds',anchor,'goal_seconds',goal_seconds,
   'target_gap',case when goal_seconds>0 then anchor/goal_seconds-1 end,
   'phase',phase,'mode',mode,'basis',basis,'outcome',outcome,'reason',reason,
   'normal_budget',case when mode in ('global_deload','intensity_deload','taper') then last_budget else used end,
   'load_weeks',case when mode<>'normal' then 0 else block_count+1 end,
   'rotation',coalesce((prev->>'rotation')::integer,0)+case when quality_count>0 then 1 else 0 end,
   'priority',priority,'evidence',ev,'sessions',sessions,'changes',changed,'rejected',rejected,
   'needs_control',need_control,'calibration','provisional',
   'intense_work_seconds',(select coalesce(sum((s->>'work_seconds')::integer),0) from jsonb_array_elements(sessions) s where s->>'family' in ('T','V','S')),
   'input_snapshot',p_input-'history');
end $$;

revoke all on function public.running_evidence_v1(jsonb,date),public.running_plan_v1(jsonb)
 from public,anon,authenticated;
commit;
