-- Escenarios hipotéticos de respuesta, NO predicciones de rendimiento.
-- Cada decisión la toma el mismo running_plan_v4 que publica la app.
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
create temporary table trajectories(profile text,months int,week_no int,plan jsonb,response text) on commit drop;
do $$
declare c record; h int; weeks int; i int; wk date; target date; anchor int; last_control date;
 previous jsonb; history jsonb; controls jsonb; inp jsonb; p jsonb; s jsonb; availability jsonb;
 count_sessions int; quality int; total int; intense int; duration int; seg jsonb;
begin
 foreach h in array array[1,2,3,4,6,12] loop
 weeks:=case h when 1 then 4 when 2 then 9 when 3 then 13 when 4 then 17 when 6 then 26 else 52 end;
 for c in select * from (values
   ('7:58',478,465,2,50,'{"1":45,"4":45}'::jsonb,'fulfills',3,'[]'::jsonb),
   ('iniciacion_11',660,630,3,90,'{"1":45,"3":45,"6":45}'::jsonb,'fulfills',5,'[]'::jsonb),
   ('intermedio_8',480,450,4,160,'{"1":60,"3":60,"5":60,"7":60}'::jsonb,'fulfills',3,'[]'::jsonb),
   ('avanzado_7_30',450,435,3,120,'{"1":45,"3":45,"6":45}'::jsonb,'fulfills',2,'[]'::jsonb),
   ('meseta',478,465,3,110,'{"1":45,"3":45,"6":45}'::jsonb,'plateau',0,'[]'::jsonb),
   ('se_excede',478,465,3,110,'{"1":45,"3":45,"6":45}'::jsonb,'overdoes',0,'[]'::jsonb),
   ('fatiga',478,465,3,110,'{"1":45,"3":45,"6":45}'::jsonb,'fatigue',1,'[]'::jsonb),
   ('un_mal_dia',478,465,3,110,'{"1":45,"3":45,"6":45}'::jsonb,'bad_day',2,'[]'::jsonb),
   ('no_entrena',660,600,2,50,'{"1":45,"4":45}'::jsonb,'inactive',0,'[]'::jsonb),
   ('intermitente',540,510,3,100,'{"1":45,"3":45,"6":45}'::jsonb,'intermittent',0,'[]'::jsonb),
   ('datos_incompletos',478,465,2,50,'{"1":45,"4":45}'::jsonb,'incomplete',0,'[]'::jsonb),
   ('cambia_agenda',480,450,4,160,'{"1":60,"3":60,"5":60,"7":60}'::jsonb,'availability',2,'[]'::jsonb),
   ('fuerza_concurrente',478,465,3,110,'{"1":45,"2":45,"4":45,"6":45}'::jsonb,'fulfills',2,'[2]'::jsonb)
 ) t(name,initial_anchor,goal,frequency,volume,days,behavior,seconds_per_control,strength) loop
   previous:='{}'; history:='[]'; controls:='[]'; anchor:=c.initial_anchor;
   target:=date '2026-10-05'+weeks*7-1;
   for i in 0..weeks-1 loop
     wk:=date '2026-10-05'+i*7;
     -- Guion de pruebas externas: mejora pequeña con techo, nunca calculada
     -- como recompensa por lo que acaba de prescribir el motor.
     if i=0 or (mod(i,4)=0 and target-wk>14) then
       anchor:=c.initial_anchor-least(round(c.initial_anchor*0.06)::int,(i/4)*c.seconds_per_control);
       if c.behavior='inactive' then anchor:=c.initial_anchor+least(30,i/4*3); end if;
       if c.behavior='fatigue' and i=4 then anchor:=c.initial_anchor+4; end if;
       last_control:=wk-1;
       controls:=controls||jsonb_build_array(jsonb_build_object('date',last_control,'seconds',anchor,'protocol','track_2k_v1'));
     end if;
     availability:=case when c.behavior='availability' and i>=6 then '{"1":30,"4":30}'::jsonb else c.days end;
     inp:=jsonb_build_object('week_start',wk,'target_date',target,'anchor_seconds',anchor,
       'anchor_age_days',wk-last_control,'goal_seconds',c.goal,'controls',controls,
       'availability',availability,'strength_days',c.strength,'recent_days',array[c.frequency,c.frequency,c.frequency,c.frequency],
       'recent_minutes',array[c.volume,c.volume,c.volume,c.volume],'capacity_minutes',60,
       'previous',previous,'history',history);
     p:=public.running_plan_v4(inp);
     count_sessions:=jsonb_array_length(p->'sessions');
     quality:=0; total:=0; intense:=0;
     for s in select value from jsonb_array_elements(p->'sessions') loop
       if (s->>'minutes')::int>(availability->>extract(isodow from (s->>'date')::date)::int::text)::int then
         raise exception 'No cabe: %/%/%',c.name,h,i; end if;
       if s->>'family' in ('T','V','S') then quality:=quality+1; intense:=intense+(s->>'work_seconds')::int; end if;
       if s->>'family' in ('T','V','S','R') and exists(select 1 from jsonb_array_elements(p->'sessions') x
         where x->>'family' in ('T','V','S','R') and abs((s->>'date')::date-(x->>'date')::date)=1) then
         raise exception 'Días intensos contiguos %/%/%',c.name,h,i; end if;
       if s->>'family' in ('T','V','S','R') and exists(select 1 from jsonb_array_elements(history) x
         where x->'session'->>'family' in ('T','V','S','R') and (x->>'date')::date=(s->>'date')::date-1) then
         raise exception 'Calidad contigua entre semanas %/%/%',c.name,h,i; end if;
       duration:=0;
       for seg in select value from jsonb_array_elements(s->'segments') loop
         duration:=duration+coalesce((seg->>'seconds')::int,ceil((seg->>'meters')::numeric*(seg->>'pace_max')::numeric/1000)::int)
           +coalesce((seg->>'recovery_seconds')::int,0);
       end loop;
       if duration<>(s->>'minutes')::int*60 then raise exception 'Duración no suma %/%/%',c.name,h,i; end if;
       total:=total+(s->>'minutes')::int;
       history:=history||jsonb_build_array(jsonb_build_object('date',s->'date','session',s,
         'execution',pg_temp.lab_execution(s,c.behavior,i+1)));
     end loop;
     if quality>2 or count_sessions>5 or intense>total*30 then raise exception 'Distribución inválida %/%/%',c.name,h,i; end if;
     if c.name in ('7:58','iniciacion_11','intermedio_8','avanzado_7_30','meseta')
       and p->>'mode'='normal' and quality=0 then
       raise exception 'Se pierde toda calidad sin motivo en trayectoria tolerada: %/%/%',c.name,h,i; end if;
     if p->'quality_entry'->>'paired'='true' and intense>(p->'quality_entry'->>'work_cap_seconds')::int then
       raise exception 'Segunda calidad supera dosis tolerada: %/%/%',c.name,h,i; end if;
     if previous->>'mode'='global_deload' and p->>'mode'='reentry' and
       total>(select sum((prior_session->>'minutes')::int) from jsonb_array_elements(previous->'sessions') prior_session) then
       raise exception 'Recupera de golpe volumen previo a la fatiga'; end if;
     if c.behavior='incomplete' and i>0 and p->>'mode' not in ('normal','taper') then raise exception 'Incompleto no es inactivo'; end if;
     if c.behavior='inactive' and i>0 and quality>0 then raise exception 'Inactivo obtiene calidad'; end if;
     if c.behavior='overdoes' and i>0 and p->>'outcome'='progress' then raise exception 'Premia excederse'; end if;
     if c.behavior='fatigue' and i=4 and weeks>5 and p->>'mode'<>'global_deload' then raise exception 'Dificultad corroborada no descarga'; end if;
     if c.behavior='bad_day' and i=4 and p->>'mode'='global_deload' then raise exception 'Un mal día descarga todo'; end if;
     if i=weeks-1 and p->>'mode'<>'taper' then raise exception 'Sin taper'; end if;
     insert into trajectories values(c.name,h,i+1,p-'evidence'-'input_snapshot',c.behavior);
     previous:=p-'evidence'-'input_snapshot';
   end loop;
 end loop;
 end loop;
end $$;
-- Fronteras y transferencia: casos independientes de las curvas de mejora.
do $$
declare inp jsonb; p jsonb; s jsonb; ex jsonb; hist jsonb:='[]'; i int; seg jsonb;
 a jsonb; pace numeric; seconds int;
begin
 inp:='{"week_start":"2026-10-05","target_date":"2026-12-28","anchor_seconds":478,
 "availability":{"1":45,"3":45,"6":45},"recent_days":[3,3,3,3],"recent_minutes":[120,120,120,120],"capacity_minutes":60}';
 s:=public.running_session_v1('V',0,478,40);
 for i in 1..4 loop
   a:='[]';
   for seg in select value from jsonb_array_elements(s->'segments') loop
     seconds:=(seg->>'seconds')::int;
     pace:=case when i<=2 then 246 else 239 end;
     a:=a||jsonb_build_array(jsonb_build_object('status','completed','seconds',seconds,'meters',seconds*1000/pace,'recovery_seconds',seg->'recovery_seconds'));
   end loop;
   ex:=jsonb_build_object('status','completed','rpe',7,'sets',a);
   hist:=hist||jsonb_build_array(jsonb_build_object('date',date '2026-09-01'+i*7,'session',s,'execution',ex));
 end loop;
 p:=public.running_plan_v4(inp||jsonb_build_object('history',hist,'controls',
   '[{"date":"2026-08-01","seconds":478,"protocol":"2k"},{"date":"2026-08-29","seconds":479,"protocol":"2k"},{"date":"2026-09-26","seconds":478,"protocol":"2k"}]'::jsonb));
 if p->'evidence'->'families'->'V'->>'trend'<>'improving' or p->>'priority'<>'T' or p->'control_review'->>'trend'<>'stable' then
   raise exception 'Series mejoran y 2k estancado no revisa el foco'; end if;
 p:=public.running_plan_v4(inp||'{"target_date":"2026-10-15"}'::jsonb);
 if p->>'phase'<>'specific' then raise exception 'Diez días no entra en fase específica'; end if;
 if exists(select 1 from jsonb_array_elements(p->'sessions') x where x->>'family'='S' and (x->>'step')::int>=6) then raise exception 'Prisa autoriza 800'; end if;
 p:=public.running_plan_v4(inp||'{"target_date":"2027-10-05"}'::jsonb);
 if p->>'phase'<>'general' then raise exception 'Ampliar objetivo no recalcula fase'; end if;
 p:=public.running_plan_v4(inp||'{"anchor_age_days":46}'::jsonb);
 if (p->>'needs_control')::boolean is not true or exists(select 1 from jsonb_array_elements(p->'sessions') x where x->>'family'<>'E') then
   raise exception 'Sin control vigente pauta intensidad'; end if;
 begin
   perform public.running_plan_v4(inp||'{"pain":true}'::jsonb);
   raise exception 'Ignora molestias';
 exception when others then if sqlerrm<>'Health flag pauses proposal' then raise; end if; end;
end $$;
-- Exportación pequeña: cada fila deja visibles entrada, pauta, razones y cambios.
do $$
declare profile_name text;
begin
 foreach profile_name in array array['avanzado_7_30','intermedio_8'] loop
   if not exists(select 1 from trajectories t where t.profile=profile_name and months=6
     and (select count(*) from jsonb_array_elements(plan->'sessions') s where s->>'family' in ('T','V','S'))=2) then
     raise exception 'La trayectoria tolerada nunca accede a segunda calidad: %',profile_name; end if;
 end loop;
end $$;
select profile,months,count(*) weeks,
 count(*) filter(where (select count(*) from jsonb_array_elements(plan->'sessions') s where s->>'family' in ('T','V','S'))=2) two_quality_weeks,
 count(*) filter(where plan->>'mode'='normal' and not exists(select 1 from jsonb_array_elements(plan->'sessions') s where s->>'family' in ('T','V','S'))) no_quality_normal
 from trajectories group by profile,months order by profile,months;
rollback;
