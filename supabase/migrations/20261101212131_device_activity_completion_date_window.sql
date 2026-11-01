begin;

-- El margen acordado pertenece a la asociación, también cuando la persona
-- revisa las vueltas. No restringe conservar ni consultar la actividad suelta.
do $$declare definition text;anchor text;begin
 definition:=pg_get_functiondef('device_private.garmin_activity_received_v1(text,uuid,uuid,jsonb)'::regprocedure);
 anchor:='  v_mapping:=p_input->''mapping'';';
 if strpos(definition,anchor)=0 then raise exception 'Revisar confirmación manual Garmin';end if;
 execute replace(definition,anchor,$body$
  if not device_private.activity_in_completion_window((a.observation->>'startedAt')::timestamptz,offset_minutes,s.scheduled_date) then
   raise exception 'completion_window_required' using errcode='22023';end if;
$body$||anchor);
 definition:=pg_get_functiondef('device_private.apple_results_observed_v1(uuid,text,jsonb)'::regprocedure);
 anchor:=' mapping:=p_input->''mapping'';';
 if strpos(definition,anchor)=0 then raise exception 'Revisar confirmación manual Apple';end if;
 execute replace(definition,anchor,$body$
 if not device_private.activity_in_completion_window((r.observation->>'started_at')::timestamptz,offset_minutes,(src->'snapshot'->>'date')::date) then
  raise exception 'completion_window_required' using errcode='22023';end if;
$body$||anchor);
 definition:=pg_get_functiondef('device_private.garmin_automatic_result(text,uuid,jsonb)'::regprocedure);
 anchor:=' mapping:=p_input->''mapping'';';
 if strpos(definition,anchor)=0 then raise exception 'Revisar reloj de cierre Garmin';end if;
 execute replace(definition,anchor,$body$
 if (a.observation->>'startedAt')::timestamptz>clock_timestamp()+interval '5 minutes' or
  (a.observation->>'startedAt')::timestamptz<'2000-01-01'::timestamptz then
  raise exception 'invalid_activity_clock' using errcode='22023';end if;
$body$||anchor);
end $$;

commit;
