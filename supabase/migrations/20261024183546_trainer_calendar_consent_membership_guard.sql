begin;
-- Compartir y finalizar el último vínculo también compiten entre sí. El mismo
-- contador obliga a reintentar una habilitación con snapshot anterior a la baja.
do $migration$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('trainer_private.set_my_calendar_sharing(uuid,boolean,bigint)'::regprocedure);
 anchor:='select * into v from trainer_private.calendar_sharing where client_id=auth.uid() for update;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar el contrato de consentimiento antes de ampliar su serialización.'; end if;
 execute replace(definition,anchor,
  'insert into trainer_private.calendar_revisions(user_id,revision) values(auth.uid(),1)
    on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision+1;
   '||anchor);
end $migration$;
commit;
