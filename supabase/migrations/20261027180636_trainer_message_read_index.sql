-- La FK de mensaje necesita índice para su limpieza en cascada, independientemente del preparador.
create index message_reads_message on trainer_private.message_reads(message_id);
