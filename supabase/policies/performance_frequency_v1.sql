-- Frecuencia observada: repartir trabajo conocido no acredita duplicar volumen.
create function public.performance_task_v4(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
 previous jsonb default '{}'::jsonb,started_on date default null) returns jsonb
language plpgsql immutable set search_path='' as $$
declare p jsonb; baseline jsonb; targets jsonb; e jsonb; dates date[]:='{}'; day date;
 freq int:=least(2,greatest(1,coalesce((previous->>'frequency')::int,(reference->>'frequency')::int,1)));
 n int; total int; per_set int; remainder int; seconds int; minimum int;
begin
 -- La frecuencia publicada continúa; la referencia del alta no la reinicia.
 p:=public.performance_task_v3(reference||jsonb_build_object('frequency',freq),profile,history,wk,target_date,previous,started_on);
 p:=p||jsonb_build_object('frequency_policy_version','performance_frequency_v1');
 if p->>'status'<>'ready' then return p; end if;
 if p->>'phase'='taper' then return p||'{"frequency_reason":"taper"}'::jsonb; end if;
 if freq=2 then return p||'{"frequency_reason":"continue_published"}'::jsonb; end if;
 -- Apoyos, práctica nueva y respuestas incompletas no habilitan otra exposición.
 if reference->>'role'='support' or target_date-wk<=14
   or p->>'outcome'='reduce' or previous->'dose' is null
   or previous->'dose'->'task'->>'stimulus_code' is distinct from p->'dose'->'task'->>'stimulus_code'
   then return p||'{"frequency_reason":"maintain"}'::jsonb; end if;
 baseline:=p->'comparison_dose';
 for e in select value from jsonb_array_elements(coalesce(history,'[]'))
   where (value->>'completed_on')::date between greatest((reference->>'observed_on')::date,wk-21) and wk-1
   order by value->>'completed_on' desc loop
   day:=(e->>'completed_on')::date;
   if day=any(dates) then continue; end if;
   if public.performance_exposure_signal_v2(e,baseline)='different_dose' then continue; end if;
   -- Deben ser las dos últimas respuestas comparables, no elegir solo éxitos.
   if public.performance_exposure_signal_v2(e,baseline)<>'tolerated' then return p||'{"frequency_reason":"insufficient_response"}'::jsonb; end if;
   dates:=array_append(dates,day); exit when cardinality(dates)=2;
 end loop;
 if cardinality(dates)<2 or dates[1]-dates[2]<7 or dates[1]<wk-7 then
   return p||'{"frequency_reason":"insufficient_response"}'::jsonb; end if;
 n:=jsonb_array_length(baseline->'targets');
 if p->>'model' in ('repetitions','load_repetitions','isometric','timed_repetitions') then
   -- Unidades semanales iguales o menores tras redondear; carga y esfuerzo intactos.
   select floor(sum(value::numeric)/2)::int into total from jsonb_array_elements_text(baseline->'targets');
   n:=ceil(n/2.0)::int; per_set:=total/n; remainder:=total%n;
   minimum:=case when p->>'model'='isometric' then 3
     when p->>'model'='load_repetitions' then coalesce((reference->>'rep_min')::int,4) else 1 end;
   if per_set<minimum then return p||'{"frequency_reason":"dose_not_divisible"}'::jsonb; end if;
   select jsonb_agg(per_set+case when i<=remainder then 1 else 0 end order by i) into targets from generate_series(1,n) i;
 elsif p->>'model'='course' and n>=2 and n%2=0 then
   -- Dividir intentos, NUNCA dividir el tiempo objetivo de un circuito.
   select jsonb_agg(value order by ordinality) into targets from jsonb_array_elements(baseline->'targets') with ordinality where ordinality<=n/2;
   -- Dos exposiciones iguales no deben aumentar intentos ni exigir otra velocidad.
   if exists(select 1 from jsonb_array_elements(baseline->'targets') v where v is distinct from baseline->'targets'->0) then
     return p||'{"frequency_reason":"dose_not_divisible"}'::jsonb; end if;
 else return p||'{"frequency_reason":"strategy_frequency_unchanged"}'::jsonb; end if;
 p:=p||jsonb_build_object('frequency',2,'outcome','redistribute','frequency_reason','two_tolerated_weekly_exposures',
   'frequency_fallback_dose',baseline,'reason','Repartimos el trabajo semanal tolerado en dos exposiciones separadas, sin subir también carga, repeticiones ni segundos. Si no caben, conservamos una exposición completa.');
 p:=jsonb_set(p,'{dose}',baseline||jsonb_build_object('targets',targets,'task',(baseline->'task')||jsonb_build_object('target_value',targets->0)));
 seconds:=public.performance_work_seconds_v2(p->'dose');
 return p||jsonb_build_object('work_seconds',seconds,'work_minutes',ceil(seconds/60.0));
end $$;
revoke all on function public.performance_task_v4(jsonb,jsonb,jsonb,date,date,jsonb,date) from public,anon,authenticated;

create function public.performance_frequency_candidate_v1(p jsonb,frequency_limit int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare seconds int;
begin
 if frequency_limit<2 and p ? 'frequency_fallback_dose' then
   p:=p||jsonb_build_object('dose',p->'frequency_fallback_dose','outcome','maintain','frequency_reason','keep_complete_exposure',
     'reason','Conservamos una exposición con la dosis tolerada: esta distribución no permite dos con tiempo y recuperación suficientes.');
 end if;
 if frequency_limit=0 then p:=public.performance_compact_proposal_v2(p); end if;
 seconds:=public.performance_work_seconds_v2(p->'dose');
 return p||jsonb_build_object('requested_frequency',p->'frequency','frequency',least(greatest(1,frequency_limit),(p->>'frequency')::int),
   'work_seconds',seconds,'work_minutes',ceil(seconds/60.0));
end $$;
revoke all on function public.performance_frequency_candidate_v1(jsonb,int) from public,anon,authenticated;
