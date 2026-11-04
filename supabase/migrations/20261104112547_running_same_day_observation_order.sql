begin;

-- El día local delimita las ventanas. En un mismo día, el instante observado
-- desempata. La agenda y el contenido deportivo dan estabilidad al histórico
-- sin hora; no se interpreta la recepción o el UUID como orden de realización.
create function public.running_history_sequence_v1(p_history jsonb)
returns table(value jsonb, ordinal bigint)
language sql immutable set search_path='' as $$
 select h.value,row_number() over(order by
   (h.value->>'date')::date,
   (h.value#>>'{execution,performed_at_epoch}')::numeric nulls first,
   h.value->>'scheduled_date' nulls first,
   h.value->'session' nulls first,
   (h.value->'execution')-array['id','completed_at','performed_at_epoch'] nulls first)
 from jsonb_array_elements(coalesce(p_history,'[]')) h(value);
$$;

-- V2–V5 siguen usando su lector histórico. En V6 se conserva la misma
-- comparación, con un orden común para seleccionar y agrupar sus muestras.
create function public.running_evidence_v6(p_history jsonb,p_week date) returns jsonb
language plpgsql immutable set search_path='' as $$
declare
 h jsonb; ordinal bigint; signal jsonb; observations jsonb:='[]'; families jsonb:='{}';
 f text; recent jsonb; old jsonb; trend text; samples integer;
begin
 for h,ordinal in select s.value,s.ordinal from public.running_history_sequence_v1(p_history) s
   where (s.value->>'date')::date<p_week and (s.value->>'date')::date>=p_week-56
   order by s.ordinal loop
   signal:=public.running_evaluate_v2(h->'session',h->'execution');
   observations:=observations||jsonb_build_array(jsonb_build_object(
     'date',h->'date','ordinal',ordinal,'session',h->'session','signal',signal,
     'execution_status',h->'execution'->'status'));
 end loop;
 foreach f in array array['E','T','V','S','R'] loop
   select value into recent from jsonb_array_elements(observations)
   where value->'session'->>'family'=f and value->'signal'->>'status' in ('tolerated','struggle')
   order by (value->>'ordinal')::bigint desc limit 1;
   select count(*),jsonb_build_object(
     'first',avg(pace) filter(where rn in (3,4)),
     'last',avg(pace) filter(where rn in (1,2))) into samples,old
   from (
     select (o->'signal'->>'pace_seconds_per_km')::numeric pace,
       row_number() over(order by (o->>'ordinal')::bigint desc) rn
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
   trend:=case when samples<4 then 'unknown'
     when (old->>'last')::numeric<(old->>'first')::numeric*0.98 then 'improving'
     when (old->>'last')::numeric>(old->>'first')::numeric*1.02 then 'worsening'
     else 'stable' end;
   families:=families||jsonb_build_object(f,jsonb_build_object('trend',trend,'samples',samples));
 end loop;
 return jsonb_build_object('observations',observations,'families',families,
   'order_policy_version','running_history_sequence_v1');
end $$;

revoke all on function public.running_history_sequence_v1(jsonb),public.running_evidence_v6(jsonb,date)
 from public,anon,authenticated;

do $migration$
declare
 change record;
 definition text;
begin
 for change in select * from (values
   ('public.calculate_running_week_constrained(uuid,date,boolean,boolean,jsonb)'::regprocedure,1,
     $old$'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,$old$,
     $new$'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'performed_at_epoch',extract(epoch from e.performed_at),$new$),
   ('public.running_dose_evidence_v6(jsonb,date,text,integer,numeric,numeric)'::regprocedure,1,
     $old$for h in select value from jsonb_array_elements(coalesce(history,'[]'))$old$,
     $new$for h in select value from public.running_history_sequence_v1(history)$new$),
   ('public.running_dose_evidence_v6(jsonb,date,text,integer,numeric,numeric)'::regprocedure,1,
     $old$order by (value->>'date')::date desc loop$old$,
     $new$order by ordinal desc loop$new$),
   ('public.running_plan_v6(jsonb)'::regprocedure,1,$old$public.running_evidence_v2($old$,$new$public.running_evidence_v6($new$),
   ('public.running_plan_v6(jsonb)'::regprocedure,5,$old$order by o->>'date' desc limit 1$old$,
     $new$order by (o->>'ordinal')::bigint desc limit 1$new$)
 ) as changes(signature,expected_matches,old_sql,new_sql) loop
   definition:=pg_get_functiondef(change.signature);
   if length(definition)-length(replace(definition,change.old_sql,''))<>length(change.old_sql)*change.expected_matches then
     raise exception 'Revisar el contrato de % antes de corregir el orden del historial.',change.signature;
   end if;
   execute replace(definition,change.old_sql,change.new_sql);
 end loop;
end;
$migration$;

commit;
