begin;
-- Impide escribir como B si la cuenta cambia durante un envío iniciado por A.
create function editor_private.read_exercise_labels_for_owner(p_expected_owner uuid,p_context text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or p_expected_owner is distinct from auth.uid() then raise insufficient_privilege;end if;
 return editor_private.read_exercise_labels(p_context);
end $$;
create function editor_private.set_exercise_labels_for_owner(p_expected_owner uuid,p_context text,p_operation_id uuid,p_exercise_id uuid,p_labels text[],p_expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_expected_owner is distinct from auth.uid() then raise insufficient_privilege;end if;
 return editor_private.set_exercise_labels(p_context,p_operation_id,p_exercise_id,p_labels,p_expected_revision);
end $$;
create function public.get_editor_exercise_labels(p_expected_owner uuid,p_context text) returns jsonb
language sql stable security invoker set search_path='' as $$select editor_private.read_exercise_labels_for_owner(p_expected_owner,p_context)$$;
create function public.set_editor_exercise_labels(p_expected_owner uuid,p_context text,p_operation_id uuid,p_exercise_id uuid,p_labels text[],p_expected_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select editor_private.set_exercise_labels_for_owner(p_expected_owner,p_context,p_operation_id,p_exercise_id,p_labels,p_expected_revision)$$;
revoke all on function editor_private.read_exercise_labels(text),editor_private.set_exercise_labels(text,uuid,uuid,text[],bigint),
 public.get_editor_exercise_labels(text),public.set_editor_exercise_labels(text,uuid,uuid,text[],bigint) from public,anon,authenticated;
revoke all on function editor_private.read_exercise_labels_for_owner(uuid,text),editor_private.set_exercise_labels_for_owner(uuid,text,uuid,uuid,text[],bigint),
 public.get_editor_exercise_labels(uuid,text),public.set_editor_exercise_labels(uuid,text,uuid,uuid,text[],bigint) from public,anon,authenticated;
grant execute on function editor_private.read_exercise_labels_for_owner(uuid,text),editor_private.set_exercise_labels_for_owner(uuid,text,uuid,uuid,text[],bigint),
 public.get_editor_exercise_labels(uuid,text),public.set_editor_exercise_labels(uuid,text,uuid,uuid,text[],bigint) to authenticated;
commit;
