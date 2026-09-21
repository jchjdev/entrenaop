-- Un usuario puede seguir varias preparaciones simultáneas.
-- Se impide únicamente duplicar el mismo programa mientras siga activo.

begin;

drop index public.preparation_goals_one_active_per_user_idx;

create unique index preparation_goals_one_active_program_per_user_idx
on public.preparation_goals (user_id, program_id)
where status = 'active';

commit;
