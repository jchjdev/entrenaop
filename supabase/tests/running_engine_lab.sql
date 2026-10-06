-- Oráculos de decisiones y trayectorias. No predicen adaptaciones humanas.
begin;
create function pg_temp.execution_for(s jsonb, effort numeric default null, speed numeric default 1)
returns jsonb language plpgsql as $$
declare a jsonb:='[]'; seg jsonb; seconds integer; meters numeric; pace numeric;
begin
 for seg in select value from jsonb_array_elements(s->'segments') loop
   pace:=coalesce(((seg->>'pace_min')::numeric+(seg->>'pace_max')::numeric)/2,330)/speed;
   seconds:=coalesce((seg->>'seconds')::integer,round((seg->>'meters')::numeric*pace/1000)::integer);
   meters:=coalesce((seg->>'meters')::numeric,seconds*1000/pace);
   a:=a||jsonb_build_array(jsonb_build_object('status','completed','seconds',seconds,'meters',meters,
     'recovery_seconds',seg->'recovery_seconds'));
 end loop;
 return jsonb_build_object('status','completed','rpe',coalesce(effort,(s->>'rpe_ceiling')::numeric-1),'sets',a);
end $$;

do $$
declare s jsonb; e jsonb; r jsonb;
begin
 s:=public.running_session_v1('V',0,478,35);
 e:=pg_temp.execution_for(s,8);
 if public.running_evaluate_v1(s,e)->>'status'<>'tolerated' then raise exception 'RPE8 de V no es fallo'; end if;
 s:=public.running_session_v1('E',0,478,30);
 if public.running_evaluate_v1(s,pg_temp.execution_for(s,8,1.3))->>'status'<>'off_intent' then
   raise exception 'Correr demasiado rápido no demuestra pérdida de forma'; end if;
 if public.running_evaluate_v1(s,pg_temp.execution_for(s,8))->>'status'<>'struggle' then
   raise exception 'E repetidamente dura necesita revisión'; end if;
 if public.running_evaluate_v1(s,'{"status":"completed","rpe":3,"sets":[]}')->>'status'<>'unknown' then
   raise exception 'Datos ausentes contados como fracaso'; end if;
 if public.running_evaluate_v1(s,'{"status":"skipped"}')->>'status'<>'missing' then raise exception 'Omisión mal clasificada'; end if;
 if public.running_evaluate_v1(s,'{"discomfort":true}')->>'status'<>'pain' then raise exception 'Dolor ignorado'; end if;
 s:=public.running_session_v1('S',6,660,30);
 if s is not null then raise exception '3x800 no cabe en 30 minutos para 11:00'; end if;
end $$;

create temporary table lab_weeks(scenario text,week integer,plan jsonb) on commit drop;
do $$
declare c record; wk date; i integer; p jsonb; inp jsonb; hist jsonb; s jsonb; ex jsonb;
 previous jsonb; availability jsonb; count_sessions integer; total integer;
begin
 for c in select * from (values
   ('A',660,null,13,'{"1":45,"3":45,"6":45}'::jsonb,3,100),
   ('B',480,450,26,'{"1":60,"3":60,"5":60,"7":60}'::jsonb,4,180),
   ('C',450,435,13,'{"1":45,"3":45,"6":45}'::jsonb,3,120),
   ('D',660,450,4,'{"1":30,"4":30}'::jsonb,2,50),
   ('7:58',478,465,12,'{"1":45,"4":45}'::jsonb,2,50),
   ('fatigue',478,465,13,'{"1":45,"3":45,"6":45}'::jsonb,3,110),
   ('missed',478,465,13,'{"1":45,"3":45,"6":45}'::jsonb,3,110),
   ('availability',480,450,26,'{"1":60,"3":60,"5":60,"7":60}'::jsonb,4,180),
   ('plateau',478,465,26,'{"1":45,"3":45,"6":45}'::jsonb,3,110),
   ('year',478,465,52,'{"1":60,"2":45,"3":60,"5":60,"7":45}'::jsonb,5,200)
 ) t(name,anchor,goal,weeks,days,frequency,volume) loop
   hist:='[]'; previous:='{}';
   for i in 0..c.weeks-1 loop
     wk:=date '2026-10-05'+i*7;
     availability:=case when c.name='availability' and i>=6 then '{"1":30,"4":30}'::jsonb else c.days end;
     inp:=jsonb_build_object('week_start',wk,'target_date',date '2026-10-05'+c.weeks*7-1,
       'anchor_seconds',c.anchor,'anchor_age_days',mod(i,4)*7,'goal_seconds',c.goal,
       'availability',availability,'recent_days',array[c.frequency,c.frequency,c.frequency,c.frequency],
       'recent_minutes',array[c.volume,c.volume,c.volume,c.volume],'capacity_minutes',75,
       'previous',previous,'history',hist);
     p:=public.running_plan_v1(inp);
     insert into lab_weeks values(c.name,i+1,p);
     count_sessions:=jsonb_array_length(p->'sessions');
     if count_sessions<1 or count_sessions>5 then raise exception 'Frecuencia inválida %, %',c.name,i; end if;
     if (select count(*) from jsonb_array_elements(p->'sessions') x where x->>'family' in ('T','V','S'))>2 then
       raise exception 'Demasiada calidad'; end if;
     total:=0;
     for s in select value from jsonb_array_elements(p->'sessions') loop
       if (s->>'minutes')::integer>(availability->>extract(isodow from (s->>'date')::date)::integer::text)::integer then
         raise exception 'No cabe en disponibilidad: %, %',c.name,i; end if;
       if (s->>'minutes')::integer<25 then raise exception 'Dosis menor al mínimo'; end if;
       if exists(select 1 from jsonb_array_elements(p->'sessions') x
         where s->>'family' in ('T','V','S','R') and x->>'family' in ('T','V','S','R')
           and abs((s->>'date')::date-(x->>'date')::date)=1) then raise exception 'Intensidad consecutiva'; end if;
       if s->>'family'='S' and (s->>'step')::integer>=6 and (select count(*)
         from jsonb_array_elements(p->'evidence'->'observations') o where o->'session'->>'family'='S'
           and (o->'session'->>'step')::integer>=4 and o->'signal'->>'status'='tolerated')<4 then
         raise exception '800 sin tolerancia'; end if;
       total:=total+(s->>'minutes')::integer;
       ex:=pg_temp.execution_for(s);
       if c.name='fatigue' and i in (3,4) then ex:=pg_temp.execution_for(s,9); end if;
       if c.name='missed' and i=4 then ex:='{"status":"skipped"}'; end if;
       hist:=hist||jsonb_build_array(jsonb_build_object('date',s->'date','session',s,'execution',ex));
     end loop;
     if (p->>'intense_work_seconds')::integer>=total*30 then raise exception 'Intensidad no predominio fácil'; end if;
     if i>0 and c.name='availability' and i>=6 and count_sessions>2 then raise exception 'No adapta días'; end if;
     previous:=p-'evidence'-'input_snapshot';
   end loop;
 end loop;
 if not exists(select 1 from lab_weeks where scenario='7:58' and plan::text like '%"family": "S"%') then
   raise exception '7:58 sin exposición específica en 3 meses'; end if;
 if not exists(select 1 from lab_weeks where scenario='fatigue' and plan->>'mode'='global_deload') then
   raise exception 'Fatiga sin descargar'; end if;
 if not exists(select 1 from lab_weeks where scenario='missed' and plan->>'mode'='reentry') then
   raise exception 'Semana perdida sin reentrada'; end if;
 if exists(select 1 from lab_weeks where (scenario,week) in (('A',13),('B',26),('C',13),('D',4),('7:58',12)) and plan->>'mode'<>'taper') then
   raise exception 'Sin puesta a punto'; end if;
end $$;
select scenario,count(*) weeks,string_agg(distinct plan->>'mode',', ') modes,
 max((plan->>'normal_budget')::integer) max_normal_minutes
from lab_weeks group by scenario order by scenario;

-- Decisiones críticas con evidencia construida, no resultados de usuario.
do $$
declare inp jsonb; p jsonb; s jsonb; hist jsonb:='[]'; f text; i integer; speed numeric;
 wk date:=date '2026-10-05'; previous jsonb;
begin
 inp:='{"week_start":"2026-10-05","target_date":"2026-12-28","anchor_seconds":478,"goal_seconds":465,
 "availability":{"1":45,"3":45,"6":45},"recent_days":[3,3,3,3],"recent_minutes":[120,120,120,120],"capacity_minutes":60}';
 foreach f in array array['E','T','S'] loop
   s:=public.running_session_v1(f,0,478,40);
   for i in 1..4 loop
     speed:=case when f in ('E','T') and i>=3 then 1.025 else 1 end;
     hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-35+i*7,'session',s,
       'execution',pg_temp.execution_for(s,null,speed)));
   end loop;
 end loop;
 p:=public.running_plan_v1(inp||jsonb_build_object('history',hist));
 if p->'evidence'->'families'->'T'->>'trend'<>'improving' or p->>'priority'<>'S' then
   raise exception 'Punto18: E/T mejoran y S estable no elige S: %',p->'evidence'->'families'; end if;
 -- Una sola sesión difícil conserva carga; no la confunde con fatiga repetida.
 previous:=public.running_plan_v1(inp||'{"week_start":"2026-09-28"}'::jsonb);
 hist:='[]'; i:=0;
 for s in select value from jsonb_array_elements(previous->'sessions') loop
   i:=i+1;
   hist:=hist||jsonb_build_array(jsonb_build_object('date',s->'date','session',s,
     'execution',pg_temp.execution_for(s,case when i=1 then 9 else null end)));
 end loop;
 p:=public.running_plan_v1(inp||jsonb_build_object('previous',previous,'history',hist));
 if p->>'outcome'<>'maintain' or p->>'mode'<>'normal' then raise exception 'Un mal día reduce'; end if;
 -- Cambio de ancla no permite además subir dosis.
 p:=public.running_plan_v1(inp||jsonb_build_object('previous',previous,'history','[]'::jsonb,'anchor_seconds',465));
 if p->>'outcome'='progress' or p->'changes'->0->>'dimension'<>'anchor_recalibration' then raise exception 'Recalibración no auditable'; end if;
 -- Sin referencia vigente no se publican ritmos ni calidad.
 p:=public.running_plan_v1(inp||'{"anchor_age_days":46}'::jsonb);
 if exists(select 1 from jsonb_array_elements(p->'sessions') row_session cross join lateral jsonb_array_elements(row_session->'segments') seg
   where seg ? 'pace_min' or row_session->>'family'<>'E') then raise exception 'Marca caducada pauta ritmos'; end if;
 -- Fuerza el domingo protege la calidad del lunes, también entre semanas.
 p:=public.running_plan_v1(inp||'{"strength_days":[7]}'::jsonb);
 if exists(select 1 from jsonb_array_elements(p->'sessions') row_session
   where extract(isodow from (row_session->>'date')::date) in (1,6) and row_session->>'family'<>'E') then raise exception 'Fuerza sin coordinar'; end if;
 -- Reentrada sin capacidad continua preserva el protocolo anterior de caminar/trotar.
 p:=public.running_plan_v1(inp||'{"capacity_minutes":10,"recent_days":[0,0,0,0],"recent_minutes":[0,0,0,0]}'::jsonb);
 if p->>'basis'<>'introductory' or exists(select 1 from jsonb_array_elements(p->'sessions') row_session where row_session->>'kind'<>'walk_run') then
   raise exception 'Principiante perdió protocolo'; end if;
 -- La brecha del caso D no permite saltar al ritmo deseado.
 if exists(select 1 from lab_weeks l cross join lateral jsonb_array_elements(l.plan->'sessions') row_session
   where l.scenario='D' and (row_session->>'speed_factor')::numeric>1.03) then raise exception 'Meta agresiva gobierna ritmo'; end if;
 -- Puerta positiva de 800: no basta con que la variante exista en catálogo.
 hist:='[]'; s:=public.running_session_v1('S',5,478,45);
 for i in 1..4 loop
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-35+i*7,'session',s,'execution',pg_temp.execution_for(s)));
 end loop;
 for i in 1..2 loop
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-6+i,'session',public.running_session_v1('E',0,478,45),
     'execution',pg_temp.execution_for(public.running_session_v1('E',0,478,45))));
 end loop;
 previous:=jsonb_build_object('week_start',wk-7,'normal_budget',135,'load_weeks',0,
   'rotation',0,'anchor_seconds',478,'sessions',jsonb_build_array(s,public.running_session_v1('E',0,478,45),public.running_session_v1('E',0,478,45)));
 p:=public.running_plan_v1(inp||jsonb_build_object('target_date',wk+21,'previous',previous,'history',hist));
 if not exists(select 1 from jsonb_array_elements(p->'sessions') x where x->>'family'='S' and (x->>'step')::integer=6) then
   raise exception 'No habilita 800 tras tolerancia específica suficiente: %',p->'sessions'; end if;
end $$;
rollback;
