begin;
-- El límite de filas también acota los bytes conservados para reintentos.
alter table trainer_private.exercise_versions add constraint trainer_exercise_payload_size
 check(octet_length(payload::text)<=8192);
commit;
