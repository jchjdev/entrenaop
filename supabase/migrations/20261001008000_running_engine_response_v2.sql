-- Política v2: distinguir evidencia ausente de omisión y probar trayectorias.
-- Mantiene v1 reproducible; el adaptador es el único punto de publicación.
begin;
alter table public.running_intake_contexts
 add column goal_mode text not null default 'improve' check(goal_mode in ('improve','time','official_margin')),
 add column official_margin_seconds integer check(official_margin_seconds between 0 and 120);
update public.running_intake_contexts set goal_mode='time' where target_2k_seconds is not null;
alter table public.running_intake_contexts add constraint running_goal_contract check(
 (goal_mode='improve' and target_2k_seconds is null and official_margin_seconds is null) or
 (goal_mode='time' and target_2k_seconds is not null and official_margin_seconds is null) or
 (goal_mode='official_margin' and target_2k_seconds is null and official_margin_seconds is not null));

-- El límite oficial lo resuelve el adaptador, nunca lo envía el cliente al publicador.
create function public.running_goal_v2(p jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare mode text:=coalesce(p->>'goal_mode',case when p->>'goal_seconds' is null then 'improve' else 'time' end);
 seconds numeric; lim numeric; margin integer;
begin
 if mode='improve' then return jsonb_build_object('mode',mode); end if;
 if mode='time' then seconds:=(p->>'goal_seconds')::numeric;
 elsif mode='official_margin' then
   lim:=(p->'official_standard'->>'seconds')::numeric;
   margin:=(p->>'official_margin_seconds')::integer;
   if lim is null or margin is null or margin not between 0 and 120 then raise exception 'Official running standard or margin unavailable'; end if;
   seconds:=lim-margin;
 else raise exception 'Invalid running goal mode'; end if;
 if seconds is null or seconds not between 240 and 1800 then raise exception 'Invalid running goal'; end if;
 return jsonb_build_object('mode',mode,'seconds',seconds,'margin_seconds',margin,'standard',p->'official_standard');
end $$;

-- Tres controles del mismo protocolo, separados al menos 14 días. La tendencia
-- de marcas declaradas orienta el foco; no demuestra una causa fisiológica.
create function public.running_test_trend_v2(p jsonb, wk date) returns jsonb
language plpgsql immutable set search_path='' as $$
declare x jsonb; a jsonb:='[]'; protocol text; last_day date; first_seconds numeric; last_seconds numeric;
begin
 for x in select value from jsonb_array_elements(p) where (value->>'date')::date<=wk
   and (value->>'date')::date>=wk-120 and (value->>'seconds')::numeric between 240 and 1800
   order by value->>'date' desc loop
   protocol:=coalesce(protocol,x->>'protocol');
   if protocol is null or x->>'protocol' is distinct from protocol then continue; end if;
   if last_day is not null and last_day-(x->>'date')::date<14 then continue; end if;
   a:=a||jsonb_build_array(x); last_day:=(x->>'date')::date;
   exit when jsonb_array_length(a)=3;
 end loop;
 if jsonb_array_length(a)<3 then return jsonb_build_object('trend','unknown','samples',jsonb_array_length(a)); end if;
 first_seconds:=(a->2->>'seconds')::numeric; last_seconds:=(a->0->>'seconds')::numeric;
 return jsonb_build_object('trend',case when last_seconds<first_seconds*0.99 then 'improving'
   when last_seconds>first_seconds*1.01 then 'worsening' else 'stable' end,
   'samples',3,'controls',a,'confidence','declared_same_protocol','relative_change',last_seconds/first_seconds-1);
end $$;

create function public.running_evaluate_v2(p_session jsonb, p_execution jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
 cfg jsonb:=public.running_policy_v1();
 family text := p_session->>'family'; seg jsonb; actual jsonb; idx integer := 0;
 expected integer := 0; complete integer := 0; missing integer := 0;
 off_pace integer := 0; slow integer := 0; recovery_bad integer := 0;
 total_seconds numeric := 0; total_meters numeric := 0;
 paces numeric[] := '{}'; variability numeric; midpoint numeric;
 first_pace numeric; last_pace numeric; pace numeric; fade numeric;
 effort numeric := (p_execution->>'rpe')::numeric;
 ceiling numeric := (public.running_policy_v1()->'rpe_ceiling'->>family)::numeric;
 status text := 'unknown'; reason text := 'missing_results';
begin
 if coalesce((p_execution->>'discomfort')::boolean,false) then
   return jsonb_build_object('status','pain','reason','reported_discomfort');
 end if;
 if p_execution->>'status' = 'skipped' then
   return jsonb_build_object('status','missing','reason','not_performed');
 end if;
 if p_execution->>'status' in ('planned','in_progress','cancelled') then
   return jsonb_build_object('status','unknown','reason','unconfirmed_execution');
 end if;
 for seg in select value from jsonb_array_elements(coalesce(p_session->'segments','[]')) loop
   actual := p_execution->'sets'->idx; idx := idx+1;
   if seg->>'role' <> 'work' then continue; end if;
   effort := greatest(effort,(actual->>'rpe')::numeric);
   expected := expected+1;
   if actual is null or actual->>'status' is null then missing := missing+1; continue; end if;
   if actual->>'status' <> 'completed' then continue; end if;
   if (actual->>'seconds')::numeric is null or (actual->>'seconds')::numeric <= 0
     or ((seg ? 'meters' or seg ? 'pace_min') and coalesce((actual->>'meters')::numeric,0)<=0) then
     missing := missing+1; continue;
   end if;
   if (seg ? 'meters' and (actual->>'meters')::numeric < (seg->>'meters')::numeric*(cfg->>'completion_min')::numeric)
     or (seg ? 'seconds' and (actual->>'seconds')::numeric < (seg->>'seconds')::numeric*(cfg->>'completion_min')::numeric) then
     continue;
   end if;
   complete := complete+1;
   total_seconds := total_seconds+(actual->>'seconds')::numeric;
   total_meters := total_meters+coalesce((actual->>'meters')::numeric,0);
   pace := (actual->>'seconds')::numeric*1000/nullif((actual->>'meters')::numeric,0);
   if pace is not null then paces:=array_append(paces,pace); end if;
   first_pace := coalesce(first_pace,pace); last_pace := pace;
   if pace < (seg->>'pace_min')::numeric*(1-(cfg->>'fast_tolerance')::numeric) then off_pace := off_pace+1; end if;
   if pace > (seg->>'pace_max')::numeric*(1+(cfg->>'pace_tolerance')::numeric) then slow := slow+1; end if;
   if seg ? 'recovery_seconds' then
     if actual->>'recovery_seconds' is null then missing := missing+1;
     elsif (actual->>'recovery_seconds')::numeric > (seg->>'recovery_seconds')::numeric*(1+(cfg->>'recovery_extension')::numeric) then
       recovery_bad := recovery_bad+1;
     end if;
   end if;
 end loop;
 select percentile_cont(0.5) within group(order by x) into midpoint from unnest(paces) x;
 -- Regularidad de todos los tramos, no solo primero y último.
 select max(abs(x-midpoint))/nullif(midpoint,0) into variability from unnest(paces) x;
 fade := case when expected>1 and first_pace>0 then last_pace/first_pace-1 end;
 if p_execution->>'abandonment_reason' = 'too_difficult' then
   status := 'struggle'; reason := 'abandoned_too_difficult';
 elsif expected=0 or missing>0 or effort is null then
   status := 'unknown'; reason := 'incomplete_evidence';
 elsif off_pace>0 then
   status := 'off_intent'; reason := 'faster_than_prescribed';
 elsif family in ('T','V','S') and cardinality(paces)>=3 and variability>0.08 then
   status := 'struggle'; reason := 'irregular_work_intervals';
 elsif complete < expected*(cfg->>'completion_min')::numeric or effort>ceiling or slow>expected/2.0
   or coalesce(fade,0)>(cfg->>'fade_max')::numeric or recovery_bad>0 then
   status := 'struggle'; reason := 'dose_or_effort_not_tolerated';
 elsif p_execution->>'status' = 'completed' then
   status := 'tolerated'; reason := 'work_pace_effort_tolerated';
 end if;
 return jsonb_build_object('status',status,'reason',reason,'family',family,
   'objective_difficulty',complete<expected*(cfg->>'completion_min')::numeric or slow>expected/2.0 or recovery_bad>0 or coalesce(fade,0)>(cfg->>'fade_max')::numeric or (family in ('T','V','S') and coalesce(variability,0)>0.08),
   'effort_review',status='struggle' and effort>ceiling,
   'completed_work',complete,'expected_work',expected,'missing',missing,
   'pace_seconds_per_km',case when total_meters>0 then total_seconds*1000/total_meters end,
   'fade',fade,'max_deviation_from_median',variability,'rpe',effort,'work_seconds',total_seconds,
   'confidence',case when missing=0 and effort is not null and expected>0 then 'observed' else 'insufficient' end);
end $$;

create function public.running_evidence_v2(p_history jsonb, p_week date)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
 h jsonb; signal jsonb; observations jsonb := '[]'; families jsonb := '{}';
 f text; recent jsonb; old jsonb; trend text; samples integer;
begin
 for h in select value from jsonb_array_elements(coalesce(p_history,'[]'))
   where (value->>'date')::date < p_week and (value->>'date')::date >= p_week-56
   order by (value->>'date')::date loop
   signal := public.running_evaluate_v2(h->'session',h->'execution');
   observations := observations || jsonb_build_array(jsonb_build_object(
     'date',h->'date','session',h->'session','signal',signal,'execution_status',h->'execution'->'status'));
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
       and abs((o->'session'->>'anchor_seconds')::numeric/nullif((recent->'session'->>'anchor_seconds')::numeric,0)-1)<=0.03
       and o->'session'->>'speed_factor'=recent->'session'->>'speed_factor'
       and (f<>'E' or o->'session'->>'minutes'=recent->'session'->>'minutes')
       and not coalesce((o->'session'->>'taper')::boolean,false)
       and o->'signal'->>'pace_seconds_per_km' is not null
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

create function public.running_plan_v2(p_input jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
 cfg jsonb:=public.running_policy_v1();
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
   return jsonb_build_object('policy_version','running_2k_v2','catalog_version','running_catalog_v1',
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
 if cnt>=3 and budget>=120 and exposures>=4 and good>=previous_count and bad=0 and missing=0 and off_intent=0 then max_quality:=2; end if;
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
     if mode='normal' and not progressed and good>=2 and cnt>=3 and i=cnt and not need_control and minutes>=30
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
 return jsonb_build_object('policy_version','running_2k_v2','catalog_version','running_catalog_v1',
   'week_start',wk,'target_date',target,'anchor_seconds',anchor,'goal_seconds',goal_seconds,
   'goal',goal_info,'control_due',control_due,'control_review',tests,
   'rpe_review_required',bad>=2 and objective_bad=0,
   'data_review_required',unknown_count>0 or n<previous_count,
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

create or replace function public.calculate_fas_running_week_core(
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
   and status='active' and program_id='fas_periodic_assessment';
 if not found then raise exception 'Active FAS preparation not found'; end if;
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
 select s.reference_source,s.reference_record_id,s.continuity_confirmed_at,a.completed_at,m.value,a.catalog_version,a.category,a.age_band into ref
 from public.running_reference_selections s join public.fas_periodic_assessments a
   on a.id::text=s.reference_record_id and a.preparation_goal_id=p_goal_id and a.user_id=u
 join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
 where s.preparation_goal_id=p_goal_id and s.reference_source='fasPeriodicAssessment' and m.value>0;
 if not found then raise exception 'Choose a valid FAS 2 km mark'; end if;
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
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2') then
   previous:=previous||jsonb_build_object('normal_budget',
     (select sum(planned_minutes) from public.running_week_sessions where decision_id=prev.id),
     'load_weeks',0,'rotation',0);
 end if;
 select jsonb_build_object('seconds',s.threshold/1000.0,'catalog_version',s.catalog_version,
   'category',s.category,'age_band',s.age_band,'assessment_id',ref.reference_record_id,
   'scope','minimum_20_points_not_global_pass') into standard from public.fas_periodic_standards s
 where s.catalog_version=ref.catalog_version and s.category=ref.category and s.age_band=ref.age_band and s.test_id='run_2000_m';
 select coalesce(jsonb_agg(jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
   'protocol',a.catalog_version||':run_2000_m','record_id',a.id) order by a.completed_at),'[]') into controls
 from public.fas_periodic_assessments a join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
 where a.preparation_goal_id=p_goal_id and a.user_id=u and a.completed_at<=now()
   and a.completed_at<=ref.completed_at and a.completed_at::date>=ref.completed_at::date-120;
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'capacity_minutes',ctx.comfortable_continuous_minutes,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 result:=public.running_plan_v2(input);
 return result||jsonb_build_object('goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at);
end $$;


revoke all on function public.running_evaluate_v2(jsonb,jsonb),public.running_evidence_v2(jsonb,date),
 public.running_plan_v2(jsonb),public.running_goal_v2(jsonb),public.running_test_trend_v2(jsonb,date)
 from public,anon,authenticated;
commit;
