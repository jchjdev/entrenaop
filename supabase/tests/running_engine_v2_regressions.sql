-- La política anterior se mantiene reproducible; estas pruebas cubren v2.
begin;
do $$
declare p jsonb; inp jsonb; prev jsonb; hist jsonb; s jsonb; e jsonb;
begin
 inp:='{"week_start":"2026-10-12","anchor_seconds":478,"anchor_age_days":12,"target_date":"2026-12-28",
 "availability":{"1":45,"4":45},"recent_days":[2,2,2,2],"recent_minutes":[50,50,50,50],"capacity_minutes":60}';
 s:=public.running_session_v1('E',0,478,30);
 prev:=jsonb_build_object('week_start','2026-10-05','normal_budget',60,'sessions',jsonb_build_array(s,s));
 -- Dos ejecuciones completadas pero imposibles de interpretar NO son abandono.
 hist:=jsonb_build_array(
   jsonb_build_object('date','2026-10-05','session',s,'execution','{"status":"completed","sets":[]}'::jsonb),
   jsonb_build_object('date','2026-10-08','session',s,'execution','{"status":"completed","sets":[]}'::jsonb));
 p:=public.running_plan_v2(inp||jsonb_build_object('previous',prev,'history',hist));
 if p->>'mode'<>'normal' or p->>'outcome'<>'maintain' or jsonb_array_length(p->'sessions')<>2
   or (p->>'normal_budget')::integer<>60 then raise exception 'Confunde datos incompletos con inactividad: %',p; end if;
 -- La misma carga con omisiones explícitas permite reentrada, preservando dos salidas.
 hist:=jsonb_set(hist,'{0,execution}','{"status":"skipped"}') ;
 hist:=jsonb_set(hist,'{1,execution}','{"status":"skipped"}');
 p:=public.running_plan_v2(inp||jsonb_build_object('previous',prev,'history',hist));
 if p->>'mode'<>'reentry' or jsonb_array_length(p->'sessions')<>2
   or (p->>'normal_budget')::integer<>50 then raise exception 'Reentrada concentrada en una sesión'; end if;
 -- Reconstrucción honesta de la pauta fácil antigua: no inventa ritmos pasados.
 s:='{"family":"E","segments":[{"role":"work","seconds":1800}]}';
 e:='{"status":"completed","rpe":4,"sets":[{"status":"completed","seconds":1800}]}';
 if public.running_evaluate_v2(s,e)->>'status'<>'tolerated' then raise exception 'Fácil antigua sin GPS no interpretable'; end if;
 if public.running_evaluate_v2(s,'{"status":"planned"}')->>'status'<>'unknown' then raise exception 'Pendiente equivale a omitida'; end if;
 -- RPE alto sin fallo objetivo: revisar la escala, no recortar automáticamente.
 hist:=jsonb_build_array(
   jsonb_build_object('date','2026-10-05','session',s,'execution',e||'{"rpe":8}'::jsonb),
   jsonb_build_object('date','2026-10-08','session',s,'execution',e||'{"rpe":7}'::jsonb));
 p:=public.running_plan_v2(inp||jsonb_build_object('previous',prev,'history',hist));
 if p->>'outcome'<>'maintain' or (p->>'normal_budget')::int<>60
   or p->>'mode'<>'normal' or not (p->>'rpe_review_required')::boolean then
   raise exception 'El RPE aislado recorta o aumenta carga: %',p; end if;
 -- El mismo esfuerzo con dosis objetivamente incompleta sí justifica reducción.
 hist:=jsonb_set(hist,'{0,execution,sets,0,seconds}','1200');
 hist:=jsonb_set(hist,'{1,execution,sets,0,seconds}','1200');
 p:=public.running_plan_v2(inp||jsonb_build_object('previous',prev,'history',hist));
 if p->>'mode'<>'global_deload' or
   (select sum((x->>'minutes')::int) from jsonb_array_elements(p->'sessions') x)<>50 then
   raise exception 'Ignora dificultad corroborada: %',p; end if;
 -- Marcadores intermedios irregulares: primero y último iguales no bastan.
 s:=public.running_session_v1('V',0,478,35);
 e:='{"status":"completed","rpe":7,"sets":[{},
 {"status":"completed","seconds":120,"meters":500,"recovery_seconds":120},
 {"status":"completed","seconds":120,"meters":400,"recovery_seconds":120},
 {"status":"completed","seconds":120,"meters":500,"recovery_seconds":120},
 {"status":"completed","seconds":120,"meters":500},{}]}';
 if public.running_evaluate_v2(s,e)->>'reason'<>'irregular_work_intervals' then raise exception 'No analiza intervalos interiores'; end if;
 p:=public.running_goal_v2('{"goal_mode":"official_margin","official_margin_seconds":10,"official_standard":{"seconds":475,"version":"test"}}');
 if (p->>'seconds')::integer<>465 then raise exception 'Margen no resuelto'; end if;
 p:=public.running_test_trend_v2('[{"date":"2026-08-01","seconds":478,"protocol":"2k"},
 {"date":"2026-08-29","seconds":479,"protocol":"2k"},{"date":"2026-09-26","seconds":478,"protocol":"2k"}]','2026-10-05');
 if p->>'trend'<>'stable' then raise exception 'Estabilidad del test mal interpretada'; end if;
end $$;
select 'Regresiones v2 OK: desconocido, omisión, registro antiguo, regularidad, objetivo y controles' as result;
rollback;
