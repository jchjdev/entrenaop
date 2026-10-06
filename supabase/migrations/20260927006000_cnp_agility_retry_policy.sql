begin;

update public.program_assessment_tests t
set max_attempts = 2, retry_policy = 'invalid_only'
from public.program_assessment_scoring_rules r
where r.program_id = t.program_id
  and r.scoring_version = 'boe_a_2026_15055_anexo_ii_v1'
  and t.code = 'agility_circuit'
  and exists (select 1 from public.preparation_programs p
    where p.id = t.program_id and not p.enabled);

commit;
