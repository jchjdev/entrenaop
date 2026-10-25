begin;
-- Un lease caducado no autoriza trabajo remoto ni debe bloquear para siempre
-- una retirada confirmada y terminada. Una pareja de lease incompleta es incierta.
do $$declare definition text;anchor text:='lease_id is not null or lease_until is not null';begin
 definition:=pg_get_functiondef('trainer_private.assignment_delete_block(uuid)'::regprocedure);
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>2 then raise exception 'Revisar leases del borrado profesional';end if;
 definition:=replace(definition,anchor,'(lease_until>statement_timestamp() or ((lease_id is null)<>(lease_until is null)))');
 execute definition;
end $$;
commit;
