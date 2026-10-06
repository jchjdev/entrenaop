-- Motor 2 km v1. Funciones puras, sin reloj ni acceso a datos personales.
-- Los umbrales son criterios operativos provisionales, no umbrales fisiológicos.
begin;

create function public.running_policy_v1() returns jsonb
language sql immutable set search_path = '' as $$
 select '{"version":"running_2k_v1","catalog":"running_catalog_v1",
 "evidence":"running_evidence_v1","calibration":"provisional",
 "pace_fractions":{"E":[0.65,0.78],"T":[0.84,0.90],"V":[0.96,1.02],"S":[0.98,1.02]},
 "rpe_ceiling":{"E":5,"T":7,"V":8,"S":8,"R":6},
 "completion_min":0.90,"pace_tolerance":0.05,"fast_tolerance":0.03,"recovery_extension":0.25,"fade_max":0.05,
 "required_successes":2,"evidence_days":56,"goal_step_max":0.03,
 "weekly_increment_minutes":5,"global_reduction":0.75,"taper_fraction":0.60,
 "intensity_deload_fraction":0.60,"max_days":5,"max_quality":2}'::jsonb
$$;

-- Biblioteca pequeña: escalones expresos; las transiciones de longitud reducen
-- repeticiones para no aumentar simultáneamente volumen e intensidad.
create function public.running_catalog_v1() returns jsonb
language sql immutable set search_path = '' as $$
 select '[
 {"family":"E","name":"Carrera fácil","source_sessions":[1,9],"steps":[[1,0,0]]},
 {"family":"T","name":"Intervalos sostenidos controlados","source_sessions":[2,6],"steps":[[2,300,120],[2,360,120],[2,480,120],[2,600,120],[2,720,120]]},
 {"family":"V","name":"Intervalos aeróbicos","source_sessions":[3,7,10],"steps":[[4,120,120],[5,120,120],[6,120,120],[4,180,120],[5,180,120],[4,240,180]]},
 {"family":"S","name":"Específico de 2 km","source_sessions":[4,8,11,12],"distance":true,"steps":[[6,200,90],[8,200,90],[10,200,90],[5,400,90],[6,400,90],[4,600,120],[3,800,180],[4,500,90]]},
 {"family":"R","name":"Fácil con progresivos","source_sessions":[5],"steps":[[4,15,75],[6,15,75],[6,20,75]]}
 ]'::jsonb
$$;

create function public.running_session_v1(
 p_family text, p_step integer, p_seconds_2k numeric,
 p_minutes integer, p_speed_factor numeric default 1
) returns jsonb language plpgsql immutable set search_path = '' as $$
declare
 c jsonb; dose jsonb; segments jsonb := '[]'; seg jsonb; fractions jsonb;
 n integer; work integer; rest integer; warm integer := 600; cool integer := 360;
 work_total integer; used integer; pace_fast integer; pace_slow integer;
 work_est integer; is_distance boolean; i integer; step integer;
begin
 if p_seconds_2k not between 240 and 1800 or p_minutes not between 25 and 180
   or p_speed_factor not between 1 and 1.03 then
   raise exception 'Invalid running session input';
 end if;
 select value into c from jsonb_array_elements(public.running_catalog_v1())
 where value->>'family' = p_family;
 if c is null then raise exception 'Unknown running family'; end if;
 step := greatest(0,least(p_step,jsonb_array_length(c->'steps')-1));
 dose := c->'steps'->step;
 n := (dose->>0)::integer; work := (dose->>1)::integer; rest := (dose->>2)::integer;
 is_distance := coalesce((c->>'distance')::boolean,false);
 if p_family <> 'R' then
   fractions := public.running_policy_v1()->'pace_fractions'->p_family;
   pace_fast := floor(p_seconds_2k / (2*(fractions->>1)::numeric*p_speed_factor));
   pace_slow := ceil(p_seconds_2k / (2*(fractions->>0)::numeric*p_speed_factor));
 end if;
 if p_family = 'E' then
   segments := jsonb_build_array(jsonb_build_object('role','work','seconds',p_minutes*60,
     'pace_min',pace_fast,'pace_max',pace_slow));
   work_total := 0; used := p_minutes*60;
 else
   work_est := case when is_distance then ceil(work*pace_slow/1000.0)::integer else work end;
   work_total := n*work_est;
   used := warm + work_total + (n-1)*rest + cool;
   if used > p_minutes*60 then return null; end if;
   segments := jsonb_build_array(jsonb_build_object('role','warmup','seconds',warm));
   for i in 1..n loop
     seg := jsonb_build_object('role','work',
       'seconds',case when is_distance then null else work end,
       'meters',case when is_distance then work else null end,
       'pace_min',pace_fast,'pace_max',pace_slow,
       'recovery_seconds',case when i<n then rest else null end);
     segments := segments || jsonb_build_array(jsonb_strip_nulls(seg));
   end loop;
   segments := segments || jsonb_build_array(jsonb_build_object('role','cooldown',
     'seconds',p_minutes*60-warm-work_total-(n-1)*rest));
   used := p_minutes*60;
 end if;
 return jsonb_build_object('family',p_family,'step',step,
   'variant_code',p_family||'_'||step||'_v1','name',c->>'name',
   'kind',case when p_family in ('E','R') then 'easy' else 'controlled_quality' end,
   'minutes',p_minutes,'intention',p_family,'segments',segments,
   'work_seconds',work_total,'speed_factor',p_speed_factor,
   'anchor_seconds',p_seconds_2k,'pace_basis','estimated_from_2k',
   'pace_policy','running_2k_v1','rpe_ceiling',public.running_policy_v1()->'rpe_ceiling'->p_family,
   'description',case p_family
     when 'E' then 'Cómodo, puedes conversar. El rango de ritmo es orientativo; manda el esfuerzo fácil.'
     when 'R' then 'Rodaje fácil y progresivos breves, rápidos y relajados, sin esprintar al máximo. Recupera por completo.'
     when 'T' then 'Tramos sostenidos controlados. El ritmo es estimado, no un umbral medido.'
     when 'V' then 'Repeticiones vivas y regulares, sin terminar al máximo. No persigas el ritmo si pierdes el control.'
     else 'Repeticiones específicas de 2 km, regulares y controladas. Respeta las recuperaciones.' end);
end $$;

-- Compara SOLO los tramos de trabajo con su intención. Ausencia no equivale a cero.
create function public.running_evaluate_v1(p_session jsonb, p_execution jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
 cfg jsonb:=public.running_policy_v1();
 family text := p_session->>'family'; seg jsonb; actual jsonb; idx integer := 0;
 expected integer := 0; complete integer := 0; missing integer := 0;
 off_pace integer := 0; slow integer := 0; recovery_bad integer := 0;
 total_seconds numeric := 0; total_meters numeric := 0;
 first_pace numeric; last_pace numeric; pace numeric; fade numeric;
 effort numeric := (p_execution->>'rpe')::numeric;
 ceiling numeric := (public.running_policy_v1()->'rpe_ceiling'->>family)::numeric;
 status text := 'unknown'; reason text := 'missing_results';
begin
 if coalesce((p_execution->>'discomfort')::boolean,false) then
   return jsonb_build_object('status','pain','reason','reported_discomfort');
 end if;
 if p_execution->>'status' in ('skipped','planned','cancelled')
   or (p_execution->>'status'='abandoned' and p_execution->>'abandonment_reason'<>'too_difficult') then
   return jsonb_build_object('status','missing','reason','not_performed');
 end if;
 for seg in select value from jsonb_array_elements(coalesce(p_session->'segments','[]')) loop
   actual := p_execution->'sets'->idx; idx := idx+1;
   if seg->>'role' <> 'work' then continue; end if;
   effort := greatest(effort,(actual->>'rpe')::numeric);
   expected := expected+1;
   if actual is null or actual->>'status' is null then missing := missing+1; continue; end if;
   if actual->>'status' <> 'completed' then continue; end if;
   if (actual->>'seconds')::numeric is null or (actual->>'meters')::numeric is null
     or (actual->>'seconds')::numeric <= 0 or (actual->>'meters')::numeric <= 0 then
     missing := missing+1; continue;
   end if;
   if (seg ? 'meters' and (actual->>'meters')::numeric < (seg->>'meters')::numeric*(cfg->>'completion_min')::numeric)
     or (seg ? 'seconds' and (actual->>'seconds')::numeric < (seg->>'seconds')::numeric*(cfg->>'completion_min')::numeric) then
     continue;
   end if;
   complete := complete+1;
   total_seconds := total_seconds+(actual->>'seconds')::numeric;
   total_meters := total_meters+(actual->>'meters')::numeric;
   pace := (actual->>'seconds')::numeric*1000/(actual->>'meters')::numeric;
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
 fade := case when expected>1 and first_pace>0 then last_pace/first_pace-1 end;
 if p_execution->>'abandonment_reason' = 'too_difficult' then
   status := 'struggle'; reason := 'abandoned_too_difficult';
 elsif expected=0 or missing>0 or effort is null then
   status := 'unknown'; reason := 'incomplete_evidence';
 elsif off_pace>0 then
   status := 'off_intent'; reason := 'faster_than_prescribed';
 elsif complete < expected*(cfg->>'completion_min')::numeric or effort>ceiling or slow>expected/2.0
   or coalesce(fade,0)>(cfg->>'fade_max')::numeric or recovery_bad>0 then
   status := 'struggle'; reason := 'dose_or_effort_not_tolerated';
 elsif p_execution->>'status' = 'completed' then
   status := 'tolerated'; reason := 'work_pace_effort_tolerated';
 end if;
 return jsonb_build_object('status',status,'reason',reason,'family',family,
   'completed_work',complete,'expected_work',expected,'missing',missing,
   'pace_seconds_per_km',case when total_meters>0 then total_seconds*1000/total_meters end,
   'fade',fade,'rpe',effort,'work_seconds',total_seconds,
   'confidence',case when missing=0 and effort is not null and expected>0 then 'observed' else 'insufficient' end);
end $$;

create function public.running_walk_run_v1() returns jsonb
language plpgsql immutable set search_path = '' as $$
declare segments jsonb := '[{"role":"warmup","seconds":300}]'; i integer;
begin
 for i in 1..8 loop
   segments:=segments||jsonb_build_array(jsonb_build_object('role','work','seconds',60,
     'recovery_seconds',90,'recovery_type','walking'));
 end loop;
 return jsonb_build_object('family','E','kind','walk_run','variant_code','walk_run_8x1_v1',
   'name','Caminar y trotar','minutes',30,'step',0,'work_seconds',480,'rpe_ceiling',4,
   'pace_basis','effort_only','description','5 min andando, 8 × (1 min cómodo + 90 s andando), 5 min andando.',
   'segments',segments||'[{"role":"cooldown","seconds":300}]'::jsonb);
end $$;

-- Puesta a punto: mantener una exposición conocida, reduciendo repeticiones.
create function public.running_taper_session_v1(s jsonb,p_minutes integer)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare seg jsonb; a jsonb:='[{"role":"warmup","seconds":600}]'; n integer;
 i integer:=0; used integer:=600; intense integer:=0; duration integer;
begin
 select greatest(1,ceil(count(*)*0.5))::integer into n from jsonb_array_elements(s->'segments') x where x->>'role'='work';
 for seg in select value from jsonb_array_elements(s->'segments') where value->>'role'='work' loop
   exit when i=n; i:=i+1;
   if i=n then seg:=seg-'recovery_seconds'; end if;
   duration:=coalesce((seg->>'seconds')::integer,ceil((seg->>'meters')::numeric*(seg->>'pace_max')::numeric/1000)::integer);
   intense:=intense+duration;
   used:=used+duration+coalesce((seg->>'recovery_seconds')::integer,0);
   a:=a||jsonb_build_array(seg);
 end loop;
 if p_minutes*60-used<360 then return null; end if;
 return s||jsonb_build_object('name',(s->>'name')||' · puesta a punto','taper',true,
   'minutes',p_minutes,'work_seconds',intense,'segments',a||jsonb_build_array(jsonb_build_object('role','cooldown','seconds',p_minutes*60-used)));
end $$;

revoke all on function public.running_policy_v1(),public.running_catalog_v1(),
 public.running_session_v1(text,integer,numeric,integer,numeric),
 public.running_evaluate_v1(jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.running_walk_run_v1(),public.running_taper_session_v1(jsonb,integer) from public,anon,authenticated;
commit;
