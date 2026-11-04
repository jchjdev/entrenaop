-- Los límites del objetivo sirven para orientar. La desaceleración solo
-- acredita dificultad por ritmo cuando el último parcial rebasa su margen.
begin;
do $$
declare
 wk date:='2026-11-02'; recipe jsonb:=public.running_session_v2('S',0,450,30);
 sample record; execution jsonb; history jsonb; signal jsonb; dose jsonb;
begin
 if recipe#>>'{segments,1,pace_min}' is distinct from '220'
   or recipe#>>'{segments,1,pace_max}' is distinct from '230' then
  raise exception 'La pauta de la prueba debe ser 3:40–3:50/km';
 end if;
 for sample in select * from (values
   ('leve ascendente',array[218,221,225,227,230,233],7,'tolerated'),
   ('leve descendente',array[233,230,227,225,221,218],7,'tolerated'),
   ('mismo ritmo con esfuerzo alto',array[218,221,225,227,230,233],9,'struggle'),
   ('exceso de velocidad',array[205,221,225,227,230,233],7,'off_intent'),
   ('caída real al final',array[218,221,225,227,230,242],7,'struggle'),
   ('irregularidad intermedia',array[225,225,249,225,225,225],7,'struggle')
 ) cases(label,paces,effort,expected) loop
  select jsonb_build_object('status','completed','rpe',sample.effort,'sets',
   jsonb_agg(jsonb_build_object('status','completed',
    'seconds',coalesce((seg->>'seconds')::numeric,(seg->>'meters')::numeric*sample.paces[(ord-1)::int]/1000),
    'meters',coalesce((seg->>'meters')::numeric,(seg->>'seconds')::numeric*1000/360),
    'recovery_seconds',seg->'recovery_seconds') order by ord))
  into execution from jsonb_array_elements(recipe->'segments') with ordinality a(seg,ord);
  history:=jsonb_build_array(jsonb_build_object('date',wk-7,'session',recipe,'execution',execution));
  signal:=public.running_evidence_v6(history,wk)#>'{observations,0,signal}';
  dose:=public.running_dose_evidence_v6(history,wk,'S',0,450,1);
  if signal->>'status' is distinct from sample.expected
    or (dose->>'compatible_successes')::int is distinct from (case when sample.expected='tolerated' then 1 else 0 end) then
   raise exception 'La sesión % debe ser %: señal %, dosis %',sample.label,sample.expected,signal,dose;
  end if;
 end loop;
end $$;
select 'Ajuste leve reconocido y señales de dificultad conservadas' as result;
rollback;
