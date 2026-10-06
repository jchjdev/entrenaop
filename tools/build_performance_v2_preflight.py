"""Preflight transaccional de la migración y sus fronteras. No conecta ni publica."""
from pathlib import Path
import re
import tempfile
import argparse

root = Path(__file__).resolve().parents[1]
files = [
    'performance_stimulus_bank_v2', 'performance_execution_contract',
    'performance_policy', 'performance_quality_feedback', 'performance_horizons_and_catalog',
    'performance_applicable_tests', 'preparation_training_security',
    'preparation_week_integration', 'preparation_week_revisions',
    'session_guidance_and_protocol_fields', 'strength_exercise_library_smoke',
    'running_engine_v5_regressions', 'running_engine_v5_horizons',
    'running_prior_quality_context_smoke', 'running_program_integration',
    'running_plan_reset_integration',
    'performance_v2_acceptance_examples',
    'performance_observed_load_reference',
]
parser=argparse.ArgumentParser()
parser.add_argument('--stage',choices=['full','coverage','installed'],default='installed')
stage=parser.parse_args().stage
parts=['begin;']
for migration_name in (['20261004003000_performance_stimulus_bank_v2.sql','20261004004000_preparation_objective_coverage.sql','20261004005000_separate_observed_reps_from_work_range.sql','20261004006000_technical_practice_guidance.sql'] if stage=='full' else ['20261004004000_preparation_objective_coverage.sql','20261004005000_separate_observed_reps_from_work_range.sql','20261004006000_technical_practice_guidance.sql'] if stage=='coverage' else []):
    migration=(root/'supabase/migrations'/migration_name).read_text(encoding='utf-8-sig')
    migration=re.sub(r'(?im)^begin;\s*','',migration,count=1)
    parts.append(re.sub(r'commit;\s*$','',migration))
parts.append('create temp table verification_results(test text);')
for name in files:
    source = (root/f'supabase/tests/{name}.sql').read_text(encoding='utf-8-sig')
    source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
    if not re.search(r'rollback;\s*$', source, re.I):
        raise ValueError(f'Prueba sin rollback: {name}')
    source = re.sub(r'rollback;\s*$', '', source, flags=re.I)
    parts.extend(['savepoint fixture;', source, 'rollback to savepoint fixture;',
                  f"insert into verification_results values ('{name}');"])
parts.extend(['select test from verification_results order by test;', 'rollback;'])
target = Path(tempfile.gettempdir())/'entrenaop-v2-complete-preflight.sql'
target.write_text('\n'.join(parts), encoding='utf-8')
print(target)
