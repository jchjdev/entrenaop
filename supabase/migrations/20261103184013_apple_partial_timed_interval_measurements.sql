begin;

-- El contrato canónico de carrera exige distancia observada también cuando
-- la pauta termina por tiempo. Si falta, conservamos el registro parcial.
-- Una recuperación subsegundo o de cero metros tampoco debe provocar que
-- falle todo el cierre al proyectarla en los campos canónicos de recuperación.
create or replace function device_private.apple_can_map_details(p_observation jsonb,p_snapshot jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare mapping jsonb:=device_private.apple_automatic_mapping(p_observation,p_snapshot);begin
 if mapping is null then return false;end if;
 return not exists(
  select 1 from jsonb_array_elements(mapping) m,
   jsonb_array_elements(p_snapshot->'blocks') b,jsonb_array_elements(b->'items') i,jsonb_array_elements(i->'sets') w
  where m->>'block_order'=b->>'order_index' and m->>'item_order'=i->>'order_index' and m->>'set_order'=w->>'order_index'
   and (exists(
    select 1 from jsonb_array_elements(m->'lap_indices') ix
    where p_observation->'intervals'->(ix::text::integer)->>'distance_meters' is null)
   or exists(
    select 1 from jsonb_array_elements(m->'recovery_lap_indices') ix
    where round((p_observation->'intervals'->(ix::text::integer)->>'timer_seconds')::numeric)<=0
     or (p_observation->'intervals'->(ix::text::integer)->>'distance_meters')::numeric<=0
     or (w->>'recovery_distance_meters' is not null and p_observation->'intervals'->(ix::text::integer)->>'distance_meters' is null))));
end $$;

commit;
