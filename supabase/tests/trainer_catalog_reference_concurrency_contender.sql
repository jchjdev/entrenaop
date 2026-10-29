-- Conexión B mientras _writer mantiene abierta su transacción en A.
-- No se modifica una receta real: se comprueba la exclusión por recurso.
begin;
set local statement_timeout='10s';
set local lock_timeout='700ms';
do $$
declare started timestamptz:=clock_timestamp();
begin
 perform trainer_private.catalog_lock_ids(array['b3ea38d3-7d58-4491-a7bf-9c90a7fba3f7'::uuid],true);
 if clock_timestamp()-started>interval '1 second' then raise exception 'Un recurso ajeno queda bloqueado por la otra familia';end if;
 begin
  perform trainer_private.catalog_lock_ids(array['2b64f34c-e1c8-4826-8fd9-c58b16a2d8c5'::uuid],true);
  raise exception 'La escritura concurrente no protege la receta que acaba de asignar';
 exception when lock_not_available then null;
 end;
end $$;
rollback;
