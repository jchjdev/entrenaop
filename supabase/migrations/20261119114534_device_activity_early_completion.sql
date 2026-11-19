begin;

-- Adelantar la pauta un día conserva su fecha prevista y la realización real.
-- El mismo margen rige la revisión manual y los cierres de ambos dispositivos.
create or replace function device_private.activity_in_completion_window(p_started timestamptz,p_offset integer,p_date date)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_started is not null and p_offset between -840 and 840 and p_date is not null
  and ((p_started at time zone 'UTC')+make_interval(mins=>p_offset))::date-p_date between -1 and 7,false)
$$;
revoke all on function device_private.activity_in_completion_window(timestamptz,integer,date) from public,anon,authenticated,service_role;

-- La búsqueda debe incluir también las pautas adelantadas y sus versiones
-- retiradas: excluir mañana hacía parecer única una receta igual atrasada.
do $$declare definition text;anchor text:='between local_day-7 and local_day';begin
 definition:=pg_get_functiondef('device_private.garmin_automatic_result(text,uuid,jsonb)'::regprocedure);
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>2
  or strpos(definition,anchor||'+')>0 then
  raise exception 'Revisar las dos búsquedas de versiones Garmin antes de migrar';end if;
 execute replace(definition,anchor,anchor||'+1');
end $$;

commit;
