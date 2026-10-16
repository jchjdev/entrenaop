"""Cotejo de desarrollo: cuerpos instalados, procedencia, permisos y limpieza."""
import hashlib
from pathlib import Path
import re
from simulate_fas_six_month_case import connect

ROOT=Path(__file__).resolve().parents[1]
sources=[ROOT/'supabase/migrations'/name for name in (
 '20261016191546_adaptive_protocol_controls.sql',
 '20261016195705_adaptive_control_shared_recovery_guard.sql',
 '20261016200843_adaptive_control_external_load_recovery.sql',
 '20261016202528_running_format_progression_v6.sql',
 '20261016205040_running_control_rotation_evidence.sql')]
pattern=r'create (?:or replace )?function public\.(\w+)\(.*?as \$\$(.*?)\$\$'
expected={name:body.replace('\r','') for p in sources for name,body in re.findall(pattern,p.read_text(encoding='utf8'),re.S)}
for filename,names in (
 ('20261001005000_running_engine_catalog_and_evidence.sql',('running_catalog_v1','running_session_v1')),
 ('20261001011000_running_engine_split_quality_v4.sql',('running_catalog_v2','running_session_v2')),
 ('20261001012000_running_engine_easy_volume_v5.sql',('running_plan_v5',))):
    found=dict(re.findall(pattern,(ROOT/'supabase/migrations'/filename).read_text(encoding='utf-8-sig'),re.S))
    for name in names:expected[name]=found[name].replace('\r','')
c=connect('C:/Users/JVR/scoop/shims/supabase.exe')
try:
    c.execute('set local role postgres')
    for name,body in expected.items():
        actual=c.execute("select p.prosrc from pg_proc p where p.pronamespace='public'::regnamespace and p.proname=%s",(name,)).fetchall()
        assert len(actual)==1 and actual[0][0].replace('\r','')==body,name
    for path in sources:
        version=path.name[:14]
        recorded=c.execute('select statements from supabase_migrations.schema_migrations where version=%s',(version,)).fetchone()[0]
        local=dict(re.findall(pattern,path.read_text(encoding='utf8'),re.S))
        remote={name:body.replace('\r','') for s in recorded for name,body in re.findall(pattern,s,re.S)}
        assert {n:b.replace('\r','') for n,b in local.items()}==remote,version
    for signature in ('apply_adaptive_protocol_controls_v1(uuid,date,jsonb)','sync_automatic_running_controls_v1(uuid)',
                      'adaptive_control_candidates_v1(uuid,date,jsonb)','adaptive_control_prior_load_conflict_v1(date,date)',
                      'running_previous_evidence_v6(jsonb)','running_plan_v6(jsonb)'):
        assert not c.execute("select has_function_privilege('authenticated',%s,'execute')",('public.'+signature,)).fetchone()[0],signature
    assert c.execute("select confdeltype='c' from pg_constraint where conrelid='public.preparation_running_tests'::regclass and contype='f' and pg_get_constraintdef(oid) like '%source_execution_set_id%'").fetchone()[0]
    assert c.execute("select count(*) from auth.users where email in ('fas-six-month-request@example.invalid','adaptive-regression@example.invalid')").fetchone()[0]==0
    assert c.execute("select count(*) from pg_proc p where p.pronamespace='public'::regnamespace and p.prosrc like '%pg_temp.program_%'").fetchone()[0]==0
    print(f'{len(expected)} cuerpos instalados coinciden; motor v5, catálogos y constructores originales intactos. {len(sources)} migraciones registradas coinciden; permisos, origen y limpieza correctos.')
finally:
    c.rollback();c.close()
