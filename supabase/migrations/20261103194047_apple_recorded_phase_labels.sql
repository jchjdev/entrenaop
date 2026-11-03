begin;

-- Solo presentación. No crea mapas de series, no cambia medidas ni habilita
-- cierres. Salud no identifica públicamente trabajo/recuperación de WorkoutKit.
create function device_private.apple_recorded_phases(p_observation jsonb,p_snapshot jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare
 phases jsonb:='[]'; recorded jsonb:=device_private.apple_recorded_intervals(p_observation);
 b jsonb;i jsonb;w jsonb;kind text;phase jsonb;candidate jsonb;consensus jsonb;
 n integer;m integer;omission integer;idx integer;pos integer;valid boolean;matches integer:=0;
begin
 for b in select value from jsonb_array_elements(coalesce(p_snapshot->'blocks','[]')) loop
  if b->>'format' not in ('running','warm_up','cool_down') then return recorded;end if;
  for i in select value from jsonb_array_elements(b->'items') loop
   for w in select value from jsonb_array_elements(i->'sets') loop
    kind:=coalesce(w->'running_step'->>'kind',case b->>'format' when 'warm_up' then 'warmup' when 'cool_down' then 'cooldown' else 'run' end);
    if kind not in ('warmup','run','recovery','rest','cooldown','walking','jogging') then return recorded;end if;
    phases:=phases||jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('phase_kind',kind,
     'seconds',w->'target_duration_seconds','pace_relevant',kind<>'rest' and
      (kind in ('warmup','run','cooldown') or w->>'target_pace_min_seconds_per_km' is not null))));
    if w->>'recovery_type' is not null then
     phases:=phases||jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('phase_kind','recovery',
      'seconds',w->'recovery_duration_seconds','pace_relevant',false)));
    end if;
   end loop;
  end loop;
 end loop;
 n:=jsonb_array_length(phases);m:=jsonb_array_length(recorded);
 -- Una actividad global o varias fases ausentes no permiten etiquetar el
 -- desglose. Una única omisión admite consenso de tipo, nunca de serie concreta.
 if n<1 or n>100 or m<2 or n-m not in (0,1) then return recorded;end if;
 for omission in 0..case when n=m then 0 else n-1 end loop
  candidate:='[]';valid:=true;
  for idx in 0..m-1 loop
   pos:=idx+case when n>m and idx>=omission then 1 else 0 end;
   phase:=phases->pos;
   -- Se permite adelantar cualquier fase con Lap. El límite superior de una
   -- fase por tiempo admite 2 s de frontera, sin redondear o corregir el dato.
   if phase->>'seconds' is not null and (recorded->idx->>'timer_seconds')::numeric>(phase->>'seconds')::numeric+2 then
    valid:=false;exit;
   end if;
   candidate:=candidate||jsonb_build_array((phase-'seconds')||jsonb_build_object('phase_source','prescription'));
  end loop;
  if valid then
   if matches=0 then consensus:=candidate;
   else
    for idx in 0..m-1 loop
     if consensus->idx is distinct from candidate->idx then consensus:=jsonb_set(consensus,array[idx::text],'{}');end if;
    end loop;
   end if;
   matches:=matches+1;
  end if;
 end loop;
 if matches=0 then return recorded;end if;
 for idx in 0..m-1 loop
  recorded:=jsonb_set(recorded,array[idx::text],(recorded->idx)||(consensus->idx));
 end loop;
 return recorded;
end $$;
revoke all on function device_private.apple_recorded_phases(jsonb,jsonb) from public,anon,authenticated,service_role;

do $migration$ declare definition text;anchor text:='device_private.apple_recorded_intervals(r.observation)';begin
 definition:=pg_get_functiondef('device_private.apple_result_json(device_private.apple_activity_results)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar proyección de fases Apple';end if;
 execute replace(definition,anchor,$body$case when r.needs_review then device_private.apple_recorded_intervals(r.observation)
  else device_private.apple_recorded_phases(r.observation,r.source_snapshot) end$body$);
end $migration$;

commit;
