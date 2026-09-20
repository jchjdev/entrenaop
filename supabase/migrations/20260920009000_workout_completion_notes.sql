begin;

alter table public.workout_executions
  add constraint workout_executions_notes_length
  check (notes is null or char_length(notes) <= 1000);

commit;
