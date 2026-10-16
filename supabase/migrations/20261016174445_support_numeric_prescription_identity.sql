-- Flutter serializa magnitudes como double. 8 y 8.0 son la misma pauta;
-- compararlas como texto impedía reutilizar una instantánea compatible.
begin;
create or replace function public.is_support_familiarization_v1(p jsonb) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(p->>'policy_version'='support_familiarization_v1' and p->>'intent'='work'
  and p->>'protocol_key'='support_work_v1:'||(p->>'exercise_code') and p->'protocol_version'='1'::jsonb
  and p->>'setup_key'='standard:support_v1:'||(p->>'exercise_code')
  and p->>'stimulus_code'='SUPPORT-F01' and p->'target_value'='8'::jsonb
  and p->>'effort_mode'='rir' and p->'target_rir'='3'::jsonb
  and exists(select 1 from jsonb_array_elements(public.performance_support_recipes_v1()) recipe
   where recipe->>'work'=p->>'exercise_code' and recipe->>'measurement'=p->>'measurement'
    and recipe->>'load_mode'=p->>'load_mode'),false)
$$;
commit;
