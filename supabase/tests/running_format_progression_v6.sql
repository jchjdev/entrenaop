-- Comportamientos, límites y compatibilidad: sin datos ni funciones persistentes.
begin;
create function pg_temp.format_execution(s jsonb) returns jsonb language plpgsql as $$
declare sets jsonb:='[]'; seg jsonb; seconds int; meters numeric; pace numeric;
begin
 for seg in select value from jsonb_array_elements(s->'segments') loop
  pace:=coalesce((seg->>'pace_max')::numeric,400);
  seconds:=coalesce((seg->>'seconds')::int,ceil((seg->>'meters')::numeric*pace/1000)::int);
  meters:=coalesce((seg->>'meters')::numeric,seconds*1000/pace);
  sets:=sets||jsonb_build_array(jsonb_build_object('status','completed','seconds',seconds,
   'meters',meters,'recovery_seconds',seg->'recovery_seconds'));
 end loop;
 return jsonb_build_object('status','completed','rpe',6,'sets',sets);
end $$;

do $$ declare wk date:='2026-10-19'; a jsonb; s jsonb; e jsonb; h jsonb:='[]';
 info jsonb; input jsonb; p jsonb; previous jsonb; q jsonb; seed_step int; i int; normalized jsonb;
begin
 s:=public.running_session_v2('S',0,595,40);
 e:=pg_temp.format_execution(s);
 h:=jsonb_build_array(jsonb_build_object('date',wk-14,'session',s,'execution',e),
  jsonb_build_object('date',wk-7,'session',s,'execution',e));
 info:=public.running_dose_evidence_v6(h,wk,'S',0,577,1);
 if (info->>'compatible_successes')::int<>2 then raise exception 'La referencia nueva pierde parciales aún compatibles: %',info; end if;
 info:=public.running_dose_evidence_v6(h,wk,'S',0,400,1);
 if (info->>'compatible_successes')::int<>0 then raise exception 'Una marca mucho más rápida fabrica tolerancia'; end if;
 info:=public.running_dose_evidence_v6(h||jsonb_build_array(jsonb_build_object('date',wk-1,'session',s,
  'execution',jsonb_set(e,'{rpe}','9'))),wk,'S',0,577,1);
 if (info->>'compatible_successes')::int<>0 then raise exception 'La dificultad reciente no reinicia la evidencia'; end if;
 info:=public.running_dose_evidence_v6(h||jsonb_build_array(jsonb_build_object('date',wk-1,'session',s,
  'execution',e-'rpe')),wk,'S',0,577,1);
 if (info->>'compatible_successes')::int<>0 then raise exception 'Datos incompletos habilitan progreso'; end if;
 info:=public.running_dose_evidence_v6(jsonb_build_array(jsonb_build_object('date',wk,'session',s,'execution',e)),wk,'S',0,577,1);
 if (info->>'compatible_successes')::int<>0 then raise exception 'Se utiliza una ejecución futura'; end if;

 -- Una dosis conocida crece antes de acelerar las mismas series por la meta.
 a:=public.running_session_v2('E',0,577,30);
 h:=h||jsonb_build_array(jsonb_build_object('date',wk-5,'session',a,
  'execution',jsonb_set(pg_temp.format_execution(a),'{rpe}','4')),
  jsonb_build_object('date',wk-3,'session',a,'execution',jsonb_set(pg_temp.format_execution(a),'{rpe}','4')));
 previous:=jsonb_build_object('week_start',wk-7,'normal_budget',90,'anchor_seconds',577,
  'load_weeks',0,'rotation',1,'mode','normal','sessions',jsonb_build_array(s,a,a));
 input:=jsonb_build_object('week_start',wk,'target_date',wk+21,'anchor_seconds',577,
  'anchor_age_days',7,'goal_seconds',500,'recent_days',array[3,3,3,3],
  'recent_minutes',array[90,90,90,90],'capacity_minutes',60,
  'availability','{"1":60,"3":60,"6":60}'::jsonb,'previous',previous,'history',h);
 p:=public.running_plan_v6(input);
 select value into q from jsonb_array_elements(p->'sessions') where value->>'family'='S';
 if q is null or (q->>'step')::int<>1 or (q->>'speed_factor')::numeric<>1 then
  raise exception 'No progresa la dosis específica conocida: %',p; end if;
 if p->>'policy_version'<>'running_2k_v6' then raise exception 'Falta versión nueva'; end if;
 p:=public.running_plan_v6(jsonb_set(input,'{previous,anchor_seconds}','595'));
 if exists(select 1 from jsonb_array_elements(p->'changes') x where x->>'dimension' in ('dose_step','speed','easy_minutes')) then
  raise exception 'Ancla nueva y aumento de dosis simultáneos'; end if;

 -- Los formatos existentes de 400 y 800 son alcanzables con sus requisitos;
 -- no es necesario insertarlos a mano ni abrirlos a un principiante.
 foreach seed_step in array array[2,5] loop
  s:=public.running_session_v2('S',seed_step,577,50);h:='[]';
  for i in 1..4 loop
   h:=h||jsonb_build_array(jsonb_build_object('date',wk-35+i*7,'session',s,'execution',pg_temp.format_execution(s)));
  end loop;
  h:=h||jsonb_build_array(jsonb_build_object('date',wk-5,'session',a,'execution',jsonb_set(pg_temp.format_execution(a),'{rpe}','4')),
   jsonb_build_object('date',wk-3,'session',a,'execution',jsonb_set(pg_temp.format_execution(a),'{rpe}','4')));
  p:=public.running_plan_v6(input||jsonb_build_object('history',h,'previous',previous||'{"normal_budget":120}'::jsonb));
  select value into q from jsonb_array_elements(p->'sessions') where value->>'family'='S';
  if q is null or (q->>'step')::int<>seed_step+1 then raise exception 'Formato conocido inaccesible: %/%',seed_step,p; end if;
 end loop;

 -- Tres mínimos de 25 min no deben expulsar un T conocido que necesita 28.
 s:=public.running_session_v2('T',0,577,35);
 a:=public.running_session_v2('E',0,577,35);
 h:=jsonb_build_array(jsonb_build_object('date',wk-7,'session',s,'execution',pg_temp.format_execution(s)),
  jsonb_build_object('date',wk-4,'session',a,'execution',jsonb_set(pg_temp.format_execution(a),'{rpe}','4')));
 previous:=jsonb_build_object('week_start',wk-7,'normal_budget',75,'anchor_seconds',577,
  'load_weeks',0,'rotation',0,'mode','normal','sessions',jsonb_build_array(s,a));
 p:=public.running_plan_v6(input||jsonb_build_object('target_date',wk+120,'previous',previous,'history',h));
 if jsonb_array_length(p->'sessions')<>2 or not exists(select 1 from jsonb_array_elements(p->'sessions') x where x->>'family' in ('T','V','S')) then
  raise exception 'Aumentar días desplaza un estímulo conocido: %',p; end if;

 -- 6×2 necesita 38 min. El lunes solo deja 37; el sábado ya elegido sí cabe.
 s:=public.running_session_v2('V',1,555,40);
 a:=public.running_session_v2('E',0,555,30);
 h:=jsonb_build_array(jsonb_build_object('date',wk-14,'session',s,'execution',pg_temp.format_execution(s)),
  jsonb_build_object('date',wk-7,'session',s,'execution',pg_temp.format_execution(s)),
  jsonb_build_object('date',wk-2,'session',a,'execution',jsonb_set(pg_temp.format_execution(a),'{rpe}','4')));
 previous:=jsonb_build_object('week_start',wk-7,'normal_budget',63,'anchor_seconds',555,
  'load_weeks',0,'rotation',1,'mode','normal','sessions',jsonb_build_array(s,a));
 input:=input||jsonb_build_object('target_date',wk+120,'anchor_seconds',555,
  'availability','{"1":37,"6":75}'::jsonb,'previous',previous,'history',h);
 p:=public.running_plan_v6(input);
 select value into q from jsonb_array_elements(p->'sessions') where value->>'family'='V';
 if q is null or (q->>'step')::int<>2 or (q->>'date')::date<>wk+5
  or (select sum((x->>'minutes')::int) from jsonb_array_elements(p->'sessions') x)<>63 then
  raise exception 'El primer hueco oculta otro día compatible: %',p; end if;
 p:=public.running_plan_v6(input||'{"leg_load_days":[5]}'::jsonb);
 if exists(select 1 from jsonb_array_elements(p->'sessions') x where x->>'family' in ('T','V','S','R') and (x->>'date')::date=wk+5) then
  raise exception 'El traslado ignora fuerza de piernas próxima'; end if;

 -- El test no consume una práctica T que nunca se hizo. La normalización es
 -- idempotente y no reduce contadores que no habían avanzado por ancla nueva.
 previous:='{"rotation":4,"sessions":[{"family":"C","intention":"T","control":{"version":"adaptive_protocol_control_v1"}},{"family":"E"}],"changes":[]}'::jsonb;
 normalized:=public.running_previous_evidence_v6(previous);
 if normalized->>'rotation'<>'3' or public.running_previous_evidence_v6(normalized)<>normalized then
  raise exception 'El control cuenta como la familia sustituida o se descuenta dos veces'; end if;
 if public.running_previous_evidence_v6(previous||'{"changes":[{"dimension":"anchor_recalibration"}]}'::jsonb)<>previous||'{"changes":[{"dimension":"anchor_recalibration"}]}'::jsonb then
  raise exception 'Descuenta una rotación que nunca había avanzado'; end if;
 if public.running_previous_evidence_v6(previous||'{"sessions":[{"family":"C","intention":"E","control":{"version":"adaptive_protocol_control_v1"}}]}'::jsonb)->>'rotation'<>'4' then
  raise exception 'Un control en lugar de rodaje fácil cambia la rotación'; end if;

 if has_function_privilege('authenticated','public.running_plan_v6(jsonb)','execute')
  or has_function_privilege('anon','public.running_dose_evidence_v6(jsonb,date,text,int,numeric,numeric)','execute') then
  raise exception 'Motor puro expuesto al cliente'; end if;
end $$;
rollback;
