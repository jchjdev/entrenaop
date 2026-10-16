"""Corrige solo el adaptador: v6 y las migraciones registradas se conservan."""
from pathlib import Path
import re
import sys
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'supabase/migrations/20261016202528_running_format_progression_v6.sql').read_text(encoding='utf8')
adapter=re.search(r'create or replace function public\.calculate_running_week_constrained\(.*?\$\$;',source,re.S)[0]
assert adapter.count(' result:=public.running_plan_v6(input);')==1
adapter=adapter.replace(' result:=public.running_plan_v6(input);',
 " input:=jsonb_set(input,'{previous}',public.running_previous_evidence_v6(input->'previous'));\n result:=public.running_plan_v6(input);")
adapter=adapter.replace("return result||jsonb_build_object('capacity_evidence'", "return result||jsonb_build_object('coordination_evidence_policy_version','running_control_evidence_v1','capacity_evidence'")
path=ROOT/sys.argv[1]
assert path.exists(),'Crear primero mediante supabase migration new'
path.write_text('\n\n'.join(['begin;',
 (ROOT/'supabase/policies/running_control_rotation_evidence_v1.sql').read_text(encoding='utf8'),
 adapter,'commit;'])+'\n',encoding='utf8')
print(path)
