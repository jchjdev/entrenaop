-- Política por estímulo. Las separaciones son guardas conservadoras de producto,
-- no tiempos biológicos universales ni un máximo de sesiones por movimiento.
create function public.performance_frequency_strategy_v2(p jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_object('version','performance_frequency_v2',
  'recovery_days',case when p->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') then 1 else 2 end,
  'recovery_basis',case when p->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') then 'controlled_course_practice' else 'regional_work_or_quality' end,
  'allocation',case when p->>'model' in ('repetitions','load_repetitions','isometric','timed_repetitions')
    or (p->>'model'='carry' and p->'dose'->'task'->>'measurement' in ('DURATION','DISTANCE')) then 'quantity' else 'attempts' end,
  'minimum_quantity',coalesce((p->>'minimum_quantity_from_reference')::int,case when p->>'model'='load_repetitions' then coalesce((p->>'rep_min')::int,4)
    when p->'dose'->'task'->>'measurement'='DURATION' then 3 else 1 end,
    1),
  'parameter_status','operational_requires_outcome_monitoring')
$$;

-- Distribuir un presupuesto acreditado; no convertirlo en más kilos o velocidad.
create function public.performance_redistribute_v2(p jsonb,doses jsonb,new_frequency int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare cfg jsonb:=public.performance_frequency_strategy_v2(p); baseline jsonb:=doses->0;
 n int; total int; per_exposure int; per_set int; remainder int; i int; targets jsonb; result jsonb:='[]'; all_targets jsonb;
begin
 if new_frequency<1 or jsonb_array_length(doses)<1 then return null; end if;
 if cfg->>'allocation'='quantity' then
   select floor(sum(v::numeric))::int into total from jsonb_array_elements(doses) d,
     jsonb_array_elements_text(d->'targets') v;
   n:=greatest(1,ceil((select sum(jsonb_array_length(d->'targets')) from jsonb_array_elements(doses) d)::numeric/new_frequency)::int);
   per_exposure:=total/new_frequency; per_set:=per_exposure/n; remainder:=per_exposure%n;
   if per_set<(cfg->>'minimum_quantity')::int then return null; end if;
   select jsonb_agg(per_set+case when j<=remainder then 1 else 0 end order by j) into targets from generate_series(1,n) j;
   for i in 1..new_frequency loop
     result:=result||jsonb_build_array(baseline||jsonb_build_object('targets',targets,
       'task',(baseline->'task')||jsonb_build_object('target_value',targets->0)));
   end loop;
 else
   select jsonb_agg(v order by ord,idx) into all_targets from jsonb_array_elements(doses) with ordinality x(d,ord),
     jsonb_array_elements(d->'targets') with ordinality y(v,idx);
   total:=jsonb_array_length(all_targets);
   if total<new_frequency then return null; end if;
   -- Los intentos indivisibles se reparten sin perder ninguno (p. ej. 2+1).
   for i in 1..new_frequency loop
     n:=total/new_frequency+case when i<=total%new_frequency then 1 else 0 end;
     select jsonb_agg(v order by ord) into targets from jsonb_array_elements(all_targets) with ordinality x(v,ord)
       where ord> (i-1)*(total/new_frequency)+least(i-1,total%new_frequency)
       and ord<=i*(total/new_frequency)+least(i,total%new_frequency);
     result:=result||jsonb_build_array(baseline||jsonb_build_object('targets',targets,
       'task',(baseline->'task')||jsonb_build_object('target_value',targets->0)));
   end loop;
 end if;
 return result;
end $$;

create function public.performance_task_v5(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
 previous jsonb default '{}'::jsonb,started_on date default null) returns jsonb
language plpgsql immutable set search_path='' as $$
declare p jsonb; cfg jsonb; baseline jsonb; doses jsonb; comparison jsonb; redistributed jsonb;
 h jsonb; signal text; dates date[]:='{}'; good int:=0; bad int:=0; last_week int:=0;
 freq int:=greatest(1,coalesce((previous->>'frequency')::int,(reference->>'frequency')::int,1));
 known_frequency int; n int; d jsonb; changed boolean; qualified boolean:=true; difficult_exposure jsonb;
 capacity numeric; fraction numeric; minimum_quantity int;
begin
 p:=public.performance_task_v3(reference,profile,history,wk,target_date,previous,started_on);
 p:=p||jsonb_build_object('frequency_policy_version','performance_frequency_v2','rep_min',coalesce((reference->>'rep_min')::int,4));
 if p->>'status'<>'ready' then return p; end if;
 select min(v::numeric) into capacity from jsonb_array_elements_text(reference->'targets') v;
 -- Conservar una magnitud practicable de la entrada calibrada. No convertir
 -- una serie útil en repeticiones o segundos testimoniales para llenar días.
 fraction:=case when reference->>'reference_kind'='repeated_work' then
   case when p->>'model'='isometric' and (reference->>'reported_rpe')::numeric<=7 then 0.80
     when p->>'model' in ('repetitions','load_repetitions') and (reference->>'reported_rir')::numeric>=3 then 0.85
     when p->>'model' in ('repetitions','load_repetitions') then 0.70 else 0.50 end else 0.50 end;
 minimum_quantity:=case when p->>'model'='load_repetitions' then coalesce((reference->>'rep_min')::int,4)
   when p->>'model'='timed_repetitions' then greatest(1,floor(capacity*(p->'dose'->'task'->>'fixed_duration_seconds')::numeric/(reference->'task'->>'fixed_duration_seconds')::numeric*0.80)::int)
   when p->>'model'='isometric' then greatest(3,floor(capacity*fraction)::int)
   when p->>'model'='repetitions' then greatest(1,floor(capacity*fraction)::int)
   when p->>'model'='carry' then greatest(1,floor(capacity*0.70)::int) end;
 p:=p||jsonb_build_object('minimum_quantity_from_reference',minimum_quantity);
 baseline:=p->'comparison_dose'; cfg:=public.performance_frequency_strategy_v2(p);
 changed:=previous->'dose' is not null and ((previous->'dose'->'task')-array['target_value','instructions','policy_version'])
   is distinct from ((baseline->'task')-array['target_value','instructions','policy_version']);
 -- Una tarea nueva vuelve a su entrada calibrada, sin heredar práctica de otra.
 if changed then freq:=greatest(1,coalesce((reference->>'frequency')::int,1)); end if;
 known_frequency:=freq;
 if cfg->>'allocation'='attempts' and not changed and jsonb_array_length(coalesce(previous->'exposure_doses','[]'))=freq then
   -- Conservar la distribución irregular conocida al mantener la frecuencia.
   for d in select value from jsonb_array_elements(previous->'exposure_doses') loop
     select jsonb_agg(v order by ord) into doses from jsonb_array_elements(p->'dose'->'targets') with ordinality x(v,ord)
       where ord<=least(jsonb_array_length(d->'targets'),jsonb_array_length(p->'dose'->'targets'));
     comparison:=coalesce(comparison,'[]')||jsonb_build_array(d);
     redistributed:=coalesce(redistributed,'[]')||jsonb_build_array((p->'dose')||jsonb_build_object('targets',doses,
       'task',(p->'dose'->'task')||jsonb_build_object('target_value',doses->0)));
   end loop;
   doses:=redistributed;
 else
   select jsonb_agg(p->'dose'),jsonb_agg(baseline) into doses,comparison from generate_series(1,freq);
 end if;
 if p->>'phase'='taper' then
   freq:=case when previous->>'phase'='taper' then freq else greatest(1,ceil(freq/2.0)::int) end;
   select jsonb_agg(value order by ord) into doses from jsonb_array_elements(doses) with ordinality x(value,ord) where ord<=freq;
   p:=p||jsonb_build_object('frequency_reason','taper_from_known_frequency');
 else
   -- Cada exposición se evalúa contra SU prescripción; 2+1 no equivale a 2+2.
   for h in select value from jsonb_array_elements(coalesce(history,'[]'))
     where (value->>'completed_on')::date between greatest((reference->>'observed_on')::date,wk-21) and wk-1
       and ((value->'dose'->'task')-array['target_value','instructions','policy_version'])=((baseline->'task')-array['target_value','instructions','policy_version'])
     order by value->>'completed_on' desc loop
     if (h->>'completed_on')::date=any(dates) then continue; end if;
     dates:=array_append(dates,(h->>'completed_on')::date);
     signal:=public.performance_exposure_signal_v2(h,h->'dose');
     if signal='pain' then return p||jsonb_build_object('status','blocked','reason','Confirma tu situación después de las molestias registradas.'); end if;
     if signal='difficulty' then bad:=bad+1; difficult_exposure:=coalesce(difficult_exposure,h); end if;
     if signal<>'tolerated' then qualified:=false;
     else
       good:=good+1;
       if (h->>'completed_on')::date>=wk-7 then last_week:=last_week+1; end if;
     end if;
     exit when cardinality(dates)>=greatest(2,freq);
   end loop;
   if bad>0 then
     -- Una dificultad de una exposición corta tampoco puede ocultarse detrás
     -- de otra dosis distinta de la misma semana.
     if p->>'outcome'<>'reduce' then
       p:=public.performance_task_v3(reference,profile,history,wk,target_date,
         previous||jsonb_build_object('dose',difficult_exposure->'dose'),started_on)||jsonb_build_object('frequency_policy_version','performance_frequency_v2','rep_min',coalesce((reference->>'rep_min')::int,4));
       if p->>'status'<>'ready' then return p; end if;
       select jsonb_agg(p->'dose') into doses from generate_series(1,freq);
     end if;
     if bad>=2 and freq>1 then
       freq:=freq-1;
       select jsonb_agg(value order by ord) into doses from jsonb_array_elements(doses) with ordinality x(value,ord) where ord<=freq;
     end if;
     p:=p||jsonb_build_object('frequency_reason','recent_difficulty');
   elsif qualified and not changed and previous->'dose' is not null and target_date-wk>14
     and p->>'phase' in ('development','specific') and p->>'outcome'<>'reduce'
     and good>=greatest(2,freq) and last_week>=freq
     and (freq>1 or dates[1]-dates[2]>=7)
     and freq<(select count(*) from generate_series(wk,wk+6,interval '1 day')) then
     -- Acreditar la semana entregada completa antes de añadir otra exposición.
     -- Repartimos la comparación tolerada, no la dosis ya incrementada por v3.
     redistributed:=public.performance_redistribute_v2(p,comparison,freq+1);
     if redistributed is not null then
       p:=p||jsonb_build_object('frequency_fallback_dose',p->'dose','frequency_fallback_outcome',p->'outcome',
         'frequency_fallback_reason',p->>'reason','frequency_fallback_exposures',doses,
         'outcome','redistribute','frequency_reason','complete_tolerated_week',
         'reason','Repartimos el trabajo semanal acreditado en otra exposición, sin aumentar también su volumen, carga o velocidad.');
       doses:=redistributed; freq:=freq+1;
     else p:=p||jsonb_build_object('frequency_reason','minimum_useful_dose'); end if;
   else p:=p||jsonb_build_object('frequency_reason','consolidate_current_distribution'); end if;
 end if;
 p:=p||jsonb_build_object('frequency',freq,'frequency_reference_count',known_frequency,
   'exposure_doses',doses,'comparison_exposure_doses',comparison,'dose',doses->0,'frequency_strategy',cfg,
   'recovery_days',cfg->'recovery_days');
 return p||jsonb_build_object('work_seconds',public.performance_work_seconds_v2(p->'dose'),
   'work_minutes',ceil(public.performance_work_seconds_v2(p->'dose')/60.0));
end $$;

create function public.performance_frequency_candidate_v2(p jsonb,frequency_limit int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare freq int; doses jsonb;
begin
 if p->>'status'<>'ready' then return p; end if;
 freq:=least(greatest(1,frequency_limit),(p->>'frequency')::int);
 if freq<(p->>'frequency')::int and p->>'outcome'='redistribute' then
   p:=p||jsonb_build_object('dose',p->'frequency_fallback_dose','exposure_doses',p->'frequency_fallback_exposures',
     'outcome',p->'frequency_fallback_outcome','reason',p->>'frequency_fallback_reason'||' Conservamos la frecuencia conocida porque otra exposición no cabe.');
 end if;
 select jsonb_agg(d order by ord) into doses from jsonb_array_elements(p->'exposure_doses') with ordinality x(d,ord) where ord<=freq;
 if frequency_limit=0 then
   p:=public.performance_compact_proposal_v2(p); doses:=jsonb_build_array(p->'dose');
 end if;
 return p||jsonb_build_object('requested_frequency',p->'frequency','frequency',freq,'exposure_doses',doses,'dose',doses->0);
end $$;

create function public.performance_exposure_v2(p jsonb,exposure int) returns jsonb
language plpgsql immutable set search_path='' as $$
declare dose jsonb:=coalesce(p->'exposure_doses'->exposure,p->'dose'); comparison jsonb; seconds int; reserved int;
begin
 comparison:=coalesce(p->'comparison_exposure_doses'->exposure,p->'comparison_dose');
 seconds:=public.performance_work_seconds_v2(dose); reserved:=seconds;
 -- Volver de un escalón de carga a su dosis anterior puede requerir más reps.
 if p->>'outcome'='progress' then reserved:=greatest(seconds,public.performance_work_seconds_v2(comparison)); end if;
 return p||jsonb_build_object('dose',dose,'exposure_index',exposure,'work_seconds',seconds,
   'work_minutes',ceil(seconds/60.0),'reservation_minutes',ceil(reserved/60.0));
end $$;

create function public.performance_reconcile_exposures_v2(p jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
begin
 if p->>'outcome'='maintain' and p->'dose'=p->'comparison_dose'
   and p->'exposure_doses'->0 is distinct from p->'dose' then
   p:=p||jsonb_build_object('exposure_doses',p->'comparison_exposure_doses');
 end if;
 return p;
end $$;

revoke all on function public.performance_frequency_strategy_v2(jsonb),public.performance_redistribute_v2(jsonb,jsonb,int),
 public.performance_task_v5(jsonb,jsonb,jsonb,date,date,jsonb,date),public.performance_frequency_candidate_v2(jsonb,int),
 public.performance_exposure_v2(jsonb,int),public.performance_reconcile_exposures_v2(jsonb) from public,anon,authenticated;
