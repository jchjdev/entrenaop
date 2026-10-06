"""Nueva migración: cobertura explícita; no modifica la v2 ya aplicada."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
source=(root/'supabase/migrations/20261004003000_performance_stimulus_bank_v2.sql').read_text(encoding='utf-8')
def fn(name):
    return re.search(r'create (?:or replace )?function public\.'+name+r'\([\s\S]*?end\s*;?\s*\$\$;',source).group()
place=fn('performance_place_v2').replace('performance_place_v2(', 'performance_place_v2_1(',1)
place=place.replace("case when value->>'role'='support' then 1 else 0 end", "case when value->>'required_for_objective'='true' then 0 else 1 end")
place=place.replace("case when rounds=1 and p->>'role'<>'support' then 1000 when p->>'role'='support' then 10 else 100 end", "case when rounds=1 and p->>'required_for_objective'='true' then 1000 when p->>'required_for_objective'='true' then 100 else 10 end")
place=place.replace("wanted:=(p->>'frequency')::int;\n  if assigned<wanted", "wanted:=coalesce((p->>'requested_frequency')::int,(p->>'frequency')::int);\n  if assigned<wanted")
place=place.replace("'objective_key',p->>'objective_key','name'", "'required_for_objective',p->'required_for_objective','objective_key',p->>'objective_key','name'")
compact="""create function public.performance_compact_proposal_v2(p jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare targets jsonb; dose jsonb; seconds int;
begin
 if p->>'status'<>'ready' then return p; end if;
 select jsonb_agg(value order by ordinality) into targets from jsonb_array_elements(p->'dose'->'targets') with ordinality
 where ordinality<=case when p->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') then 2 else 1 end;
 dose:=jsonb_set(p->'dose','{targets}',targets); seconds:=public.performance_work_seconds_v2(dose);
 return p||jsonb_build_object('dose',dose,'outcome','reduce','compact',true,'work_seconds',seconds,'work_minutes',ceil(seconds/60.0),
  'reason',p->>'reason'||' Formato corto por disponibilidad: menos series, misma técnica y margen. No aumentes la intensidad para compensarlo.');
end $$;"""
responsive="""-- Dos exposiciones muy fáciles permiten recuperar margen sin estimar un máximo.
create function public.performance_task_v2_1(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,previous jsonb default '{}'::jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare p jsonb:=public.performance_task_v2(reference,profile,history,wk,target_date,previous); baseline jsonb; targets jsonb; e jsonb;
 good int:=0; easy int:=0; budget int; idx int; initial numeric; current_value numeric; count_sets int; n int; seconds int;
begin
 if p->>'outcome'<>'progress' or p->>'model' not in ('repetitions','isometric') then return p; end if;
 for e in select value from jsonb_array_elements(p->'evidence') where value->>'signal'='tolerated' loop
  good:=good+1;
  if not exists(select 1 from jsonb_array_elements(e->'exposure'->'sets') s where
    case when p->>'model'='repetitions' then coalesce((s->'result'->>'rir')::numeric,0)<6
    else coalesce((s->'result'->>'rpe')::numeric,10)>4 end) then easy:=easy+1; end if;
 end loop;
 if good<2 or easy<2 then return p; end if;
 baseline:=p->'comparison_dose'->'targets'; targets:=baseline; count_sets:=jsonb_array_length(targets);
 select greatest(1,floor(sum(value::numeric)*0.10))::int into budget from jsonb_array_elements_text(targets);
 -- Cota operativa: hasta 10% de volumen, como máximo tres unidades por serie.
 budget:=least(budget,count_sets*3);
 for n in 1..budget loop
  select ordinality::int-1 into idx from jsonb_array_elements_text(targets) with ordinality
   where value::numeric<(baseline->>(ordinality::int-1))::numeric+3 order by value::numeric,ordinality limit 1;
  if idx is null then exit; end if;
  targets:=jsonb_set(targets,array[idx::text],to_jsonb((targets->>idx)::numeric+1));
 end loop;
 p:=jsonb_set(p,'{dose,targets}',targets); p:=jsonb_set(p,'{dose,task,target_value}',targets->0);
 seconds:=public.performance_work_seconds_v2(p->'dose');
 return p||jsonb_build_object('work_seconds',seconds,'work_minutes',ceil(seconds/60.0),'adaptation_rule','repeated_very_easy_bounded_volume_v1',
  'reason',p->>'reason'||' Ambas exposiciones dejaron mucho margen: ajuste limitado del volumen, sin estimar un máximo ni cambiar la variante.');
end $$;"""
core=fn('calculate_preparation_week_core')
core=core.replace('public.performance_task_v2(', 'public.performance_task_v2_1(')
core=core.replace('  rotation int;', "  frequency_limit int; candidates jsonb; expected_running jsonb; minimum_runs int:=1; expected_runs int:=0; actual_runs int:=0;\n  rotation int;")
core=core.replace(' for rotation in 0..6 loop', """ -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and q->>'objective_key'=p->>'objective_key'
   and (case q->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
        q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,p->>'reference_id')))),'[]') into proposals
 from jsonb_array_elements(proposals) p;
 if has_running then
  begin
   expected_running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
    jsonb_build_object('revise_week',p_revision,'availability',ctx.availability,'strength_days','[]'::jsonb,'leg_load_days','[]'::jsonb));
   expected_runs:=jsonb_array_length(coalesce(expected_running->'sessions','[]')); minimum_runs:=least(2,greatest(1,expected_runs));
  exception when others then expected_running:=null; end;
 end if;
 for frequency_limit in reverse 2..0 loop
 select coalesce(jsonb_agg((case when frequency_limit=0 then public.performance_compact_proposal_v2(p) else p end)||jsonb_build_object('requested_frequency',p->'frequency','frequency',least(greatest(1,frequency_limit),(p->>'frequency')::int))),'[]') into candidates from jsonb_array_elements(proposals) p;
 for rotation in 0..6 loop""")
core=core.replace('public.performance_place_v2(proposals,', 'public.performance_place_v2_1(candidates,')
core=core.replace("where q->>'role'<>'support' and (q->>'scheduled')::int=0", "where q->>'required_for_objective'='true' and (q->>'scheduled')::int=0")
core=core.replace("   if score>best_score", """   if frequency_limit=0 then score:=score-50; end if;
   if has_running and jsonb_array_length(coalesce(running->'sessions','[]'))<minimum_runs then score:=score-10000; end if;
   if score>best_score""")
core=core.replace(" end loop;\n -- El trabajo descartado", " end loop;\n end loop;\n -- El trabajo descartado")
core=core.replace(" select coalesce(jsonb_agg(p),'[]') into coordinated from jsonb_array_elements(proposals) p\n where exists(select 1 from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w where w->>'reference_id'=p->>'reference_id');", " select coalesce(jsonb_agg(w),'[]') into coordinated from (select distinct w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w) chosen;")
core=core.replace("'policy_version','preparation_coordinator_v2'", "'policy_version','preparation_coordinator_v2_1'")
core=core.replace(" required_missing:=", """ -- Un apoyo puede ser la única entrada de un objetivo; no debe desaparecer sin aviso.
 select coalesce(jsonb_agg(case when p->>'objective_key' is not null and exists(
   select 1 from jsonb_array_elements(sessions) ses,jsonb_array_elements(ses->'work') w
   where w->>'objective_key'=p->>'objective_key' or exists(select 1 from public.performance_training_references r
     where w->'covered_reference_ids' ? r.id::text and r.objective_key=p->>'objective_key'))
   then p||'{"role":"support"}'::jsonb else p||'{"role":"specific"}'::jsonb end),'[]') into pending from jsonb_array_elements(pending) p;
 actual_runs:=jsonb_array_length(coalesce(best_running->'sessions','[]'));
 if actual_runs>0 and actual_runs<expected_runs then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','reduced_running_coverage','name','Frecuencia de carrera',
   'role','support','scheduled',actual_runs,'requested',expected_runs,
   'reason','La semana conjunta conserva '||actual_runs||' de las '||expected_runs||' salidas que cabrían dedicando esos días solo a carrera. Para conservar ambas frecuencias, añade otro día o más tiempo.'));
 end if;
 if has_running and actual_runs<minimum_runs then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_running_frequency','name','Cobertura de carrera','role','specific',
   'reason','La distribución deja menos de '||minimum_runs||' salidas de carrera. Añade tiempo u otro día para cubrir la preparación conjunta.'));
 end if;
 if has_running and actual_runs=0 and not exists(select 1 from jsonb_each(ctx.availability) a where (a.value::text)::int>=25) then
  pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_running_time','name','Tiempo para carrera','role','specific',
   'reason','Carrera v5 necesita al menos 25 minutos para una sesión completa. Ninguno de tus días alcanza ese tiempo. Aumenta al menos un día y vuelve a revisar la semana.'));
 end if;
 required_missing:=""")
core=core.replace("required_missing:=(jsonb_array_length(sessions)=0", "required_missing:=(has_running and actual_runs<minimum_runs) or (jsonb_array_length(sessions)=0")
core=core.replace("'context_observed_at',ctx.observed_at", "'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at")
output=root/'supabase/migrations/20261004004000_preparation_objective_coverage.sql'
output.write_text('-- Cobertura deportiva antes de segunda exposición o apoyos.\nbegin;\n'+compact+'\n'+responsive+'\n'+place+'\n'+core+"\nrevoke all on function public.performance_place_v2_1(jsonb,jsonb,jsonb,jsonb,int,date,date), public.performance_compact_proposal_v2(jsonb), public.performance_task_v2_1(jsonb,jsonb,jsonb,date,date,jsonb) from public,anon,authenticated;\ncommit;\n",encoding='utf-8')
print(output.name)
