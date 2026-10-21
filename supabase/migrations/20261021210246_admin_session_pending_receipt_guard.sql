begin;

-- Un recibo confirmado todavía necesita su receta hasta enlazarla al programa.
create or replace function admin_work_private.guard_pending_source() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if TG_TABLE_NAME='workout_templates' then
    if TG_OP='UPDATE' and new.trashed_at is null then return new; end if;
    if exists(select 1 from admin_work_private.session_work w
      where not w.discarded and (
        (w.result_id is null and w.origin->>'baseId'=old.id::text)
        or (w.result_id=old.id and exists(
          select 1 from public.admin_guided_work_drafts p,
            jsonb_array_elements(p.state->'phases') phase
          where p.owner_id=w.owner_id and p.id=(w.origin->>'parentWorkId')::uuid
            and phase->'sessionWorks' ? w.id::text
        ))
      )) then
      raise exception 'Hay un trabajo abierto o un enlace al programa pendiente. Retómalo antes de retirar la sesión.' using errcode='22023';
    end if;
  else
    if exists(select 1 from admin_work_private.session_work where not discarded
      and origin->>'parentWorkId'=old.id::text and old.state::text like '%'||id::text||'%') then
      raise exception 'El programa conserva una sesión incompleta. Retómala o descártala antes del borrado definitivo.' using errcode='22023'; end if;
  end if;
  if TG_OP='DELETE' then return old; end if;
  return new;
end $$;

commit;
