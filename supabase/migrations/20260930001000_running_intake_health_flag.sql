-- La revisión de salud se conserva como dato fechado junto al dolor declarado.
begin;
alter table public.running_intake_contexts
  add column requires_professional_review boolean not null default false;
commit;
