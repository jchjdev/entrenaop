begin;

-- Activa la prestación acordada en el catálogo de ensayo, sin modificar
-- precios, recibos, ofertas contratadas, Pro ni concesiones administrativas.
update commerce_private.offers
set directory_enabled = (plan_key in ('professional','complete')
  or (plan_key='basic' and directory_option))
where plan_key in ('basic','professional','complete');

create or replace function directory_private.commercial_eligible(p_trainer uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.trainer_access a
    where a.trainer_id=p_trainer and a.enabled
      and (a.valid_until is null or a.valid_until>statement_timestamp()))
  and exists(select 1 from commerce_private.orders o
    join commerce_private.offers f on f.id=coalesce(o.current_offer_id,o.offer_id)
    where o.owner_id=p_trainer and o.paid_until>statement_timestamp()
      and f.directory_enabled)
$$;
revoke all on function directory_private.commercial_eligible(uuid)
  from public,anon,authenticated,service_role;

-- La presentación informa de prestaciones habilitadas por el servidor.
-- La elegibilidad sigue resolviéndose en el directorio, con cobertura pagada.
do $migration$
declare definition text;
begin
  definition:=pg_get_functiondef('commerce_private.status(uuid)'::regprocedure);
  if strpos(definition,'''directory_option'',f.directory_option')=0 then
    raise exception 'Revisar los metadatos del catálogo profesional';
  end if;
  execute replace(definition,'''directory_option'',f.directory_option',
    '''directory_option'',f.directory_option,''directory_enabled'',f.directory_enabled');
end $migration$;

commit;
