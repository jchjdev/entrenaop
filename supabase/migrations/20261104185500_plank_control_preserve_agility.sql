begin;

do $migration$
declare
 definition text:=replace(pg_get_functiondef('public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb,uuid,date)'::regprocedure),E'\r\n',E'\n');
 change record;
begin
 for change in select * from (values
  ($old$affected_references text[]:='{}';$old$,
   $new$affected_references text[]:='{}'; plank_would_remove_agility boolean;$new$),
  ($old$chosen:=null; m:=c->>'measurement';$old$,
   $new$chosen:=null; m:=c->>'measurement'; plank_would_remove_agility:=false;$new$),
  ($old$    if total+greatest(0,newcost-oldcost)+share_undo>coalesce((plan->'availability'->>extract(isodow from day)::int::text)::int,0) then continue; end if;
    chosen:=day; exit;$old$,
   $new$    if total+greatest(0,newcost-oldcost)+share_undo>coalesce((plan->'availability'->>extract(isodow from day)::int::text)::int,0) then continue; end if;
    -- La práctica esencial incluye los ejercicios técnicos que preparan el circuito.
    -- Probar otro día si la misma regla de recuperación del test los retiraría todos.
    if c->>'profile'='front_plank_forearms' and exists(
     select 1
     from jsonb_array_elements(plan->'sessions') session,
      jsonb_array_elements(session->'work') item
     where item->>'optional' is distinct from 'true'
      and (item->>'objective_key'='legacy:agility_speed_circuit'
       or item->'covered_objective_keys' ? 'legacy:agility_speed_circuit')
     having count(*)>0 and bool_and(coalesce(
      item->>'objective_key'=c->>'objective_key' or (
       abs((session->>'date')::date-day)<2 and exists(
        select 1 from jsonb_array_elements_text(item->'body_regions') region
        where c->'body_regions' ? region)),false))
    ) then
     plank_would_remove_agility:=true;
     continue;
    end if;
    chosen:=day; exit;$new$),
  ($old$  if chosen is null then continue; end if;$old$,
   $new$  if chosen is null then
   -- Conservar la semana ordinaria: otro máximo podría retirar esa misma práctica.
   if plank_would_remove_agility then exit; end if;
   continue;
  end if;$new$)
 ) as changes(previous,replacement) loop
  if length(definition)-length(replace(definition,change.previous,''))<>length(change.previous) then
   raise exception 'Revisar la colocación del control de plancha antes de proteger la práctica de agilidad.';
  end if;
  definition:=replace(definition,change.previous,change.replacement);
 end loop;
 execute definition;
end;
$migration$;

commit;
