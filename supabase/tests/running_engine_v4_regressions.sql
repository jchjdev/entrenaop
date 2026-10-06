-- Regresiones de selección: transaccionales, sin datos persistentes.
begin;
create function pg_temp.lab_execution(s jsonb, behavior text, week_no int)
returns jsonb language plpgsql as $$
declare a jsonb:='[]'; seg jsonb; seconds int; meters numeric; pace numeric;
 effort int:=(s->>'rpe_ceiling')::int-1; speed numeric:=1+mod(week_no,4)*0.003;
begin
 if behavior='inactive' or (behavior='intermittent' and mod(week_no,3)=0) then return '{"status":"skipped"}'; end if;
 if behavior='incomplete' then return '{"status":"completed","sets":[]}'; end if;
 if behavior='overdoes' then speed:=1.18; effort:=9; end if;
 if behavior='fatigue' and week_no in (4,5) then effort:=9; speed:=0.88; end if;
 if behavior='bad_day' and week_no=4 and extract(isodow from (s->>'date')::date)=1 then effort:=9; end if;
 if behavior='plateau' then speed:=1; end if;
 for seg in select value from jsonb_array_elements(s->'segments') loop
   pace:=coalesce(((seg->>'pace_min')::numeric+(seg->>'pace_max')::numeric)/2,360)/speed;
   seconds:=coalesce((seg->>'seconds')::int,round((seg->>'meters')::numeric*pace/1000)::int);
   meters:=coalesce((seg->>'meters')::numeric,seconds*1000/pace);
   if behavior='fatigue' and week_no in (4,5) and seg->>'role'='work' then
     seconds:=round(seconds*0.8); meters:=meters*0.8;
   end if;
   a:=a||jsonb_build_array(jsonb_build_object('status','completed','seconds',seconds,'meters',meters,
     'recovery_seconds',seg->'recovery_seconds'));
 end loop;
 return jsonb_build_object('status','completed','rpe',effort,'sets',a);
end $$;
do $$
declare inp jsonb; p jsonb; prev jsonb; hist jsonb:='[]'; sample jsonb;
 split_input jsonb; old_plan jsonb; workout jsonb; part jsonb;
 wk date:='2026-10-05'; i int; q int; total int; seconds int;
begin
 if jsonb_array_length(public.running_catalog_v2())<>5
   or public.running_catalog_v2()->1->'paired_entry'<>jsonb_build_array(2,240,120)
   or public.running_catalog_v2()->2->'paired_entry'<>jsonb_build_array(3,120,120) then
   raise exception 'Catálogo v2 desordenado o incompleto'; end if;
 inp:=jsonb_build_object('week_start',wk,'target_date','2026-12-28','anchor_seconds',660,
   'availability','{"1":45,"3":45,"6":45}'::jsonb,'recent_days',array[3,3,3,3],
   'recent_minutes',array[90,90,90,90],'capacity_minutes',60);
 for i in 1..2 loop
   sample:=public.running_session_v1(case when i=1 then 'T' else 'V' end,0,660,30);
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-(4-i)*7,'session',sample,
     'execution',pg_temp.lab_execution(sample,'fulfills',1)));
 end loop;
 prev:=jsonb_build_object('week_start',wk-7,'normal_budget',90,'rotation',2,'load_weeks',0,'sessions','[]'::jsonb);
 for i in 0..2 loop
   sample:=public.running_session_v1('E',0,660,30);
   prev:=jsonb_set(prev,'{sessions}',prev->'sessions'||jsonb_build_array(sample));
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-7+i*2,'session',sample,
     'execution',pg_temp.lab_execution(sample,'fulfills',1)));
 end loop;
 inp:=inp||jsonb_build_object('history',hist,'previous',prev);
 p:=public.running_plan_v4(inp);
 if not exists(select 1 from jsonb_array_elements(p->'sessions') s where s->>'family'='S' and (s->>'minutes')::int=31)
   or (select sum((s->>'minutes')::int) from jsonb_array_elements(p->'sessions') s)<>90 then
   raise exception 'Se pierde S por 18 segundos en vez de redistribuir: %',p; end if;
 p:=public.running_plan_v4(inp||'{"availability":{"1":30,"3":30,"6":30}}'::jsonb);
 if not exists(select 1 from jsonb_array_elements(p->'sessions') s where s->>'family' in ('T','V'))
   or jsonb_array_length(p->'recommendations')=0 then
   raise exception 'Sin alternativa completa o sin recomendación: %',p; end if;
 if exists(select 1 from jsonb_array_elements(p->'sessions') s where (s->>'minutes')::int>30) then
   raise exception 'La recomendación sobrescribe la disponibilidad'; end if;

 -- Cuatro exposiciones distribuidas con recuperación sí permiten una puerta
 -- alcanzable, sin necesidad de haber hecho previamente dos por semana.
 hist:='[]';
 for i in 1..4 loop
   sample:=public.running_session_v1(case when mod(i,2)=0 then 'T' else 'V' end,0,478,40);
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-(6-i)*7,'session',sample,
     'execution',pg_temp.lab_execution(sample,'fulfills',1)));
 end loop;
 prev:=jsonb_build_object('week_start',wk-7,'normal_budget',120,'rotation',1,'load_weeks',0,'anchor_seconds',478,'sessions','[]'::jsonb);
 for i in 0..2 loop
   sample:=public.running_session_v1(case when i=0 then 'T' else 'E' end,case when i=0 then 2 else 0 end,478,40);
   prev:=jsonb_set(prev,'{sessions}',prev->'sessions'||jsonb_build_array(sample));
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-7+i*2,'session',sample,
     'execution',pg_temp.lab_execution(sample,'fulfills',1)));
 end loop;
 inp:=inp||jsonb_build_object('anchor_seconds',478,'history',hist,'previous',prev,
   'recent_minutes',array[120,120,120,120]);
 p:=public.running_plan_v4(inp);
 select count(*) into q from jsonb_array_elements(p->'sessions') s where s->>'family' in ('T','V','S');
 if q<>2 or (p->>'intense_work_seconds')::int>1152
   or (select sum((s->>'minutes')::int) from jsonb_array_elements(p->'sessions') s)<>120 then
   raise exception 'Segunda calidad inaccesible o duplicación de carga: %',p; end if;
 if exists(select 1 from jsonb_array_elements(p->'changes') x where x->>'dimension' in ('easy_minutes','dose_step','speed')) then
   raise exception 'Progresa otras variables al introducir segunda calidad'; end if;

 -- Una dosis semanal tolerada de 12 min puede repartirse en 8+6 min.
 -- La v3 exige 10+8 min y aún mantiene una sola calidad.
 hist:='[]';
 for i in 1..4 loop
   sample:=public.running_session_v1(case when mod(i,2)=0 then 'T' else 'V' end,0,478,40);
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-(6-i)*7,'session',sample,
     'execution',pg_temp.lab_execution(sample,'fulfills',1)));
 end loop;
 prev:=jsonb_build_object('week_start',wk-7,'normal_budget',120,'rotation',1,
   'load_weeks',0,'anchor_seconds',478,'sessions','[]'::jsonb);
 for i in 0..2 loop
   sample:=public.running_session_v1(case when i=0 then 'T' else 'E' end,
     case when i=0 then 1 else 0 end,478,40);
   prev:=jsonb_set(prev,'{sessions}',prev->'sessions'||jsonb_build_array(sample));
   hist:=hist||jsonb_build_array(jsonb_build_object('date',wk-7+i*2,'session',sample,
     'execution',pg_temp.lab_execution(sample,'fulfills',1)));
 end loop;
 split_input:=inp||jsonb_build_object('history',hist,'previous',prev);
 old_plan:=public.running_plan_v3(split_input);
 p:=public.running_plan_v4(split_input);
 if (select count(*) from jsonb_array_elements(old_plan->'sessions') x
       where x->>'family' in ('T','V','S'))<>1
   or (select count(*) from jsonb_array_elements(p->'sessions') x
       where x->>'family' in ('T','V','S'))<>2
   or p->'quality_entry'->>'paired'<>'true'
   or (p->>'intense_work_seconds')::int>864 then
   raise exception 'No reparte la dosis tolerada en dos calidades: %',p; end if;
 for workout in select value from jsonb_array_elements(p->'sessions') loop
   seconds:=0;
   for part in select value from jsonb_array_elements(workout->'segments') loop
     seconds:=seconds+coalesce((part->>'seconds')::int,
       ceil((part->>'meters')::numeric*(part->>'pace_max')::numeric/1000)::int)
       +coalesce((part->>'recovery_seconds')::int,0);
   end loop;
   if seconds<>(workout->>'minutes')::int*60 then
     raise exception 'Sesión repartida incompleta: %',workout; end if;
 end loop;
 if exists(select 1 from jsonb_array_elements(p->'changes') x
     where x->>'dimension' in ('easy_minutes','dose_step','speed')) then
   raise exception 'Añade una segunda calidad y otra progresión simultánea'; end if;

 -- Una marca nueva no justifica aumentar a la vez la frecuencia de calidad.
 p:=public.running_plan_v4(inp||'{"anchor_seconds":475}'::jsonb);
 if (select count(*) from jsonb_array_elements(p->'sessions') s where s->>'family' in ('T','V','S'))>1 then
   raise exception 'Nueva marca introduce también segunda calidad'; end if;
 -- Ventana fresca y dos sesiones no bastan: tampoco basta ampliar agenda.
 p:=public.running_plan_v4(inp-'previous'-'history');
 if (select count(*) from jsonb_array_elements(p->'sessions') s where s->>'family' in ('T','V','S'))>1 then
   raise exception 'Dos calidades sin historial'; end if;
 p:=public.running_plan_v4(inp||'{"availability":{"1":45,"4":45}}'::jsonb);
 if (select count(*) from jsonb_array_elements(p->'sessions') s where s->>'family' in ('T','V','S'))>1 then
   raise exception 'Dos calidades en dos días'; end if;
 hist:=jsonb_set(hist,array[(jsonb_array_length(hist)-1)::text,'execution'],'{"status":"completed","sets":[]}');
 p:=public.running_plan_v4(inp||jsonb_build_object('history',hist));
 if (select count(*) from jsonb_array_elements(p->'sessions') s where s->>'family' in ('T','V','S'))>1 then
   raise exception 'Datos ausentes desbloquean segunda calidad'; end if;
 if has_function_privilege('authenticated','public.running_plan_v4(jsonb)','execute')
   or has_function_privilege('anon','public.running_second_quality_v4(jsonb,jsonb,jsonb,int)','execute') then
   raise exception 'Auxiliares internos expuestos'; end if;
end $$;
select 'V4: cabida, alternativa, recomendación, tolerancia, dosis y permisos OK' as result;
rollback;
