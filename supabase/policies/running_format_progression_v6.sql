-- Reutilizar datos realizados, no la etiqueta de una referencia antigua.
-- La tolerancia se vuelve a comprobar con los parciales y el esfuerzo reales.
create function public.running_dose_evidence_v6(
 history jsonb,wk date,family text,step int,anchor numeric,factor numeric
) returns jsonb language plpgsql immutable set search_path='' as $$
declare h jsonb; original jsonb; compatible jsonb; prescription jsonb;
 samples jsonb:='[]'; checked int:=0;
begin
 prescription:=public.running_session_v2(family,step,anchor,180,factor);
 for h in select value from jsonb_array_elements(coalesce(history,'[]'))
  where (value->>'date')::date<wk and (value->>'date')::date>=wk-56
   and value->'session'->>'family'=family
   and not coalesce((value->'session'->>'taper')::boolean,false)
  order by (value->>'date')::date desc loop
  original:=public.running_evaluate_v2(h->'session',h->'execution');
  -- Una incidencia posterior invalida el permiso de progresar que daban
  -- éxitos anteriores. Se vuelve a reunir evidencia, sin borrar el historial.
  exit when original->>'status'<>'tolerated';
  if (h->'session'->>'step')::int is distinct from step then continue; end if;
  checked:=checked+1;
  compatible:=public.running_evaluate_v2(prescription,h->'execution');
  if compatible->>'status'='tolerated' then
   samples:=samples||jsonb_build_array(jsonb_build_object('date',h->'date',
    'original_anchor_seconds',h->'session'->'anchor_seconds',
    'pace_seconds_per_km',compatible->'pace_seconds_per_km','rpe',compatible->'rpe'));
  end if;
 end loop;
 return jsonb_build_object('policy','running_dose_evidence_v6','family',family,
  'step',step,'anchor_seconds',anchor,'speed_factor',factor,
  'checked',checked,'compatible_successes',jsonb_array_length(samples),'samples',samples);
end $$;

revoke all on function public.running_dose_evidence_v6(jsonb,date,text,int,numeric,numeric)
 from public,anon,authenticated;
