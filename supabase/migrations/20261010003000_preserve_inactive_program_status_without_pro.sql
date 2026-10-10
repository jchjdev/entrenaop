-- El acceso comercial solo pausa visualmente la continuidad automática.
-- Un programa terminado o pausado por el usuario conserva su estado y motivo.
begin;
create or replace function public.refresh_adaptive_programs() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  result := public.refresh_adaptive_programs_pro_base();
  if public.has_pro_access(auth.uid()) then return result; end if;
  select coalesce(jsonb_agg(case when exists(
    select 1 from public.adaptive_program_states a
      where a.preparation_goal_id = (item->>'goal_id')::uuid
        and a.user_id = auth.uid() and a.auto_advance
  ) then item || jsonb_build_object('status', 'paused', 'continuation_code', 'pro_required',
      'message', 'Tu programa se conserva. Necesitas Pro para generar y adaptar nuevas semanas.',
      'next_generation_on', null)
    else item end order by position), '[]'::jsonb)
  into result from jsonb_array_elements(result) with ordinality items(item, position);
  return result;
end $$;
commit;
