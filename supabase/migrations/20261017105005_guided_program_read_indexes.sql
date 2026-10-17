begin;
-- El índice parcial de seguimientos activos no cubre el historial terminado
-- ni la FK de propietario al borrar una cuenta.
create index guided_program_follows_owner_history_idx
  on public.guided_program_follows(user_id,program_id,started_at desc);
drop policy guided_warmups_read on public.guided_warmups;
create policy guided_warmups_read on public.guided_warmups for select to authenticated
using ((select public.is_admin()) or status='published');
drop policy guided_programs_read on public.guided_programs;
create policy guided_programs_read on public.guided_programs for select to authenticated
using ((select public.is_admin()) or status='published' or exists(
  select 1 from public.guided_program_follows f
  where f.program_id=guided_programs.id and f.user_id=(select auth.uid())
));
commit;
