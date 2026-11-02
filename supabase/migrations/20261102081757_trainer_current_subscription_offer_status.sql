begin;
-- La referencia inicial de Checkout se conserva en orders.offer_id. La UI
-- debe identificar la cobertura vigente, igual que la proyección de cupos.
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('commerce_private.status(uuid)'::regprocedure);
 if strpos(definition,'''offer_id'',o.offer_id')=0 then raise exception 'Revisar oferta del estado comercial';end if;
 execute replace(definition,'''offer_id'',o.offer_id','''offer_id'',f.id');
 definition:=pg_get_functiondef('commerce_private.prepare_change(uuid,uuid)'::regprocedure);
 if strpos(definition,'(current_offer.directory_option and not target.directory_option)')=0 then raise exception 'Revisar elegibilidad del directorio';end if;
 -- Profesional/Completo incluyen directorio aunque no tengan el extra de Básico.
 execute replace(definition,'(current_offer.directory_option and not target.directory_option)',
  '((current_offer.directory_option or current_offer.plan_key in (''professional'',''complete'')) and not (target.directory_option or target.plan_key in (''professional'',''complete'')))');
end $migration$;
commit;
