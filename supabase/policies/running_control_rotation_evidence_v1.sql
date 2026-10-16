-- Un control sustituye trabajo, pero no acredita la familia sustituida.
create function public.running_previous_evidence_v6(previous jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
begin
 if coalesce((previous->>'rotation_after_control_normalized')::boolean,false)
  or coalesce((previous->>'rotation')::int,0)=0 then return previous; end if;
 if exists(select 1 from jsonb_array_elements(coalesce(previous->'sessions','[]')) s
   where s->>'family'='C' and s->'control'->>'version'='adaptive_protocol_control_v1'
    and s->>'intention' in ('T','V','S'))
  and not exists(select 1 from jsonb_array_elements(previous->'sessions') s where s->>'family' in ('T','V','S'))
  and not exists(select 1 from jsonb_array_elements(coalesce(previous->'changes','[]')) x where x->>'dimension'='anchor_recalibration') then
  return previous||jsonb_build_object('rotation',(previous->>'rotation')::int-1,
   'rotation_after_control_normalized',true,'rotation_evidence_policy','running_control_evidence_v1');
 end if;
 return previous;
end $$;
revoke all on function public.running_previous_evidence_v6(jsonb) from public,anon,authenticated;
