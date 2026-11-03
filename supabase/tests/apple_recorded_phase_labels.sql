begin;
set local statement_timeout='30s';
do $$
declare snapshot jsonb;observation jsonb;answer jsonb;original jsonb;
begin
 snapshot:='{"blocks":[{"format":"running","items":[{"sets":[
  {"running_step":{"kind":"warmup"},"target_duration_seconds":100},
  {"target_distance_meters":400,"recovery_type":"passive","recovery_duration_seconds":10},
  {"running_step":{"kind":"cooldown"},"target_duration_seconds":100}
 ]}]}]}';
 observation:='{"intervals":[
  {"timer_seconds":80,"distance_meters":200,"id":"private"},
  {"timer_seconds":60,"distance_meters":300},
  {"timer_seconds":12,"distance_meters":2},
  {"timer_seconds":50,"distance_meters":100}]}';
 original:=observation;
 answer:=device_private.apple_recorded_phases(observation,snapshot);
 if answer->0->>'phase_kind'<>'warmup' or answer->1->>'phase_kind'<>'run' or answer->2->>'phase_kind'<>'recovery'
  or answer->3->>'phase_kind'<>'cooldown' or answer->2->>'pace_relevant'<>'false'
  or answer->1->>'pace_relevant'<>'true' or answer->0->>'phase_source'<>'prescription' then raise exception 'Pierde semántica de fase: %',answer;end if;
 if answer::text like '%private%' or observation is distinct from original then raise exception 'Expone identidad o altera observación';end if;
 if answer->2->'timer_seconds'<>'12'::jsonb or answer->2->'distance_meters'<>'2'::jsonb then raise exception 'Corrige la medida';end if;
 -- La fase por tiempo no puede sobrepasar la pauta en más de 2 s. No se
 -- clasifica por velocidad, distancia objetivo o cumplimiento del esfuerzo.
 answer:=device_private.apple_recorded_phases(jsonb_set(observation,'{intervals,2,timer_seconds}','12.01'),snapshot);
 if exists(select 1 from jsonb_array_elements(answer) x where x?'phase_kind') then raise exception 'Etiqueta fases incompatibles';end if;
 -- Una omisión inequívoca conserva las fases sin inventar la recuperación.
 observation:=jsonb_set(observation,'{intervals}',(observation->'intervals')-2);
 answer:=device_private.apple_recorded_phases(observation,snapshot);
 if answer->2->>'phase_kind'<>'cooldown' or jsonb_array_length(answer)<>3 then raise exception 'Desplaza enfriamiento';end if;
 -- Con duraciones cortas pueden faltar trabajo o recuperación: abstención.
 observation:='{"intervals":[{"timer_seconds":5},{"timer_seconds":5},{"timer_seconds":5}]}';
 answer:=device_private.apple_recorded_phases(observation,snapshot);
 if exists(select 1 from jsonb_array_elements(answer) x where x?'phase_kind') then raise exception 'Resuelve una ambigüedad inventando';end if;
 observation:='{"intervals":[{"timer_seconds":5},{"timer_seconds":5}]}';
 answer:=device_private.apple_recorded_phases(observation,snapshot);
 if exists(select 1 from jsonb_array_elements(answer) x where x?'phase_kind') then raise exception 'Admite varias omisiones';end if;
 observation:='{"intervals":[{"timer_seconds":5}]}';
 answer:=device_private.apple_recorded_phases(observation,snapshot);
 if answer->0?'phase_kind' then raise exception 'Convierte actividad global en fase';end if;
 -- Una recuperación independiente con objetivo de ritmo conserva su utilidad
 -- para fartlek; el descanso pasivo nunca se presenta como carrera.
 snapshot:='{"blocks":[{"format":"running","items":[{"sets":[
  {"running_step":{"kind":"recovery"},"target_duration_seconds":30,"target_pace_min_seconds_per_km":300},
  {"running_step":{"kind":"rest"},"target_duration_seconds":30}
 ]}]}]}';
 observation:='{"intervals":[{"timer_seconds":30,"distance_meters":100},{"timer_seconds":30,"distance_meters":1}]}';
 answer:=device_private.apple_recorded_phases(observation,snapshot);
 if answer->0->>'pace_relevant'<>'true' or answer->1->>'pace_relevant'<>'false' then raise exception 'Confunde recuperación pautada y descanso';end if;
 if has_function_privilege('authenticated','device_private.apple_recorded_phases(jsonb,jsonb)','execute')
  or has_function_privilege('anon','device_private.apple_recorded_phases(jsonb,jsonb)','execute') then raise exception 'Abre helper privado';end if;
end $$;
rollback;
