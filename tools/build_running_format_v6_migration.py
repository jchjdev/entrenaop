"""Nueva política pura y adaptación mínima; conserva las definiciones v1–v5."""
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]

def definition(filename,name):
    source=(ROOT/'supabase/migrations'/filename).read_text(encoding='utf-8-sig')
    found=re.search(r'create (?:or replace )?function public\.'+name+r'\(.*?as \$\$.*?\$\$;',source,re.S)
    assert found,name
    return found[0]

def change(source,old,new,count=1):
    assert source.count(old)==count,(old[:90],source.count(old))
    return source.replace(old,new)

policy=definition('20261001012000_running_engine_easy_volume_v5.sql','running_plan_v5')
policy=change(policy,'function public.running_plan_v5(', 'function public.running_plan_v6(')
policy=change(policy,"'running_2k_v5'","'running_2k_v6'",2)
policy=change(policy," j int; spare int;", " dose_evidence jsonb; frequency_probe jsonb; future_fit jsonb; minimum_quality_minutes int; future_day int; defer_quality boolean;\n j int; spare int;")
policy=change(policy," if previous_count>0 and cnt<>previous_count then", """ -- No comprar otro día a costa de perder una calidad conocida. Primero
 -- debe caber completa junto al suelo de las otras salidas, con igual volumen.
 if cnt>previous_count and previous_count>0 and not need_control then
   select o->'session' into last_session from jsonb_array_elements(obs) o
    where o->'session'->>'family' in ('T','V','S') and o->'signal'->>'status'='tolerated'
     and not coalesce((o->'session'->>'taper')::boolean,false)
    order by o->>'date' desc limit 1;
   if last_session is not null then
    frequency_probe:=public.running_session_v2(last_session->>'family',
      (last_session->>'step')::int,anchor,180,case when changed_anchor then 1 else coalesce((last_session->>'speed_factor')::numeric,1) end);
    minimum_quality_minutes:=ceil((10800-(frequency_probe->'segments'->-1->>'seconds')::int+360)/60.0)::int;
    if budget<minimum_quality_minutes+(cnt-1)*25 then
     cnt:=previous_count;
     recommendations:=recommendations||jsonb_build_array(jsonb_build_object(
      'code','frequency_preserves_known_quality','message',
      'Conservamos las salidas actuales para que el trabajo conocido quepa completo; ampliar días aún lo desplazaría.'));
    end if;
   end if;
 end if;
 if previous_count>0 and cnt<>previous_count then""")
policy=change(policy," priority:=cycle[1+mod(coalesce((prev->>'rotation')::integer,0),3)];", """ priority:=case when phase in ('build','specific') then 'S'
   else cycle[1+mod(coalesce((prev->>'rotation')::integer,0),3)] end;
 -- El formato del examen gana prioridad al acercarse la prueba. Conserva
 -- puertas de entrada, tendencias, recuperación y alternativas completas.""")
policy=change(policy," reserve_second:=reserve_second and mode='normal' and can_quality", """ -- La reserva no debe retener una progresión si la pareja aún usa una
 -- familia desconocida y el colocador necesariamente la rechazará.
 reserve_second:=reserve_second
   and exists(select 1 from jsonb_array_elements(obs) o where o->'session'->>'family'=priority and o->'signal'->>'status'='tolerated')
   and exists(select 1 from jsonb_array_elements(obs) o where o->'session'->>'family'=case when priority='T' then 'V' else 'T' end and o->'signal'->>'status'='tolerated')
   and mode='normal' and can_quality""")
start=policy.index('     select count(*) into same_good from jsonb_array_elements(obs) o')
end=policy.index('     select jsonb_array_length(value',start)
policy=policy[:start]+"""     previous_factor:=coalesce((last_session->>'speed_factor')::numeric,1);
     factor:=case when changed_anchor then 1 else previous_factor end;
     dose_evidence:=public.running_dose_evidence_v6(p_input->'history',wk,f,held_step,anchor,factor);
     same_good:=(dose_evidence->>'compatible_successes')::int;
"""+policy[end:]
start=policy.index('     -- Objetivo cercano:')
end=policy.index('     fit:=public.running_fit_slot_v4',start)
policy=policy[:start]+"""     -- La meta no acredita un ritmo de entrenamiento. Se progresa la dosis
     -- compatible; las marcas reales siguen recalibrando ritmos por separado.
"""+policy[end:]
policy=change(policy,"       dose_step:=held_step;\n       factor:=case when changed_anchor then 1 else previous_factor end;", """       -- Antes de reducir al formato anterior, intentar otro día ya elegido.
       -- No añade días, minutos ni calidad junto a piernas u otra calidad.
       defer_quality:=false;
       if f=requested_family and dose_step>held_step then
        for j in i+1..cnt loop
         future_day:=selected_days[j];
         if exists(select 1 from unnest(strength) x where abs(x-future_day)<=1 or abs(x-future_day)=6)
          or exists(select 1 from jsonb_array_elements_text(coalesce(p_input->'leg_load_days','[]')) x where abs(x::int-future_day)<=1)
          or exists(select 1 from unnest(quality_days) x where abs(x-future_day)<=1)
          or exists(select 1 from jsonb_array_elements(obs) o where (o->>'date')::date=wk+future_day-2 and o->'session'->>'family' in ('T','V','S','R')) then continue; end if;
         future_fit:=public.running_fit_slot_v4(f,dose_step,anchor,factor,j,allocations,selected_days,p_input->'availability',sessions);
         if future_fit is not null then defer_quality:=true; exit; end if;
        end loop;
       end if;
       if defer_quality then
        recommendations:=recommendations||jsonb_build_array(jsonb_build_object('code','quality_later_slot',
         'message','El formato que ya puedes probar cabe completo en otro día previsto; hoy conservamos carrera fácil.'));
        exit;
       end if;
       dose_step:=held_step;
       factor:=case when changed_anchor then 1 else previous_factor end;""")
policy=change(policy,"     candidate:=fit->'session'; sessions:=fit->'sessions';", "     candidate:=(fit->'session')||jsonb_build_object('progression_evidence',dose_evidence); sessions:=fit->'sessions';")
policy=change(policy,"   'selection_policy',selection_cfg,", "   'selection_version','running_selection_v6','selection_policy',selection_cfg,")

adapter=definition('20261016191546_adaptive_protocol_controls.sql','calculate_running_week_constrained')
versions="'running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5'"
adapter=change(adapter,versions,versions+",'running_2k_v6'",2)
adapter=change(adapter,'result:=public.running_plan_v5(input);','result:=public.running_plan_v6(input);')
adapter=change(adapter,'La selección deportiva sigue en v5;', 'La selección deportiva usa v6;')
target=ROOT/sys.argv[1]
assert target.exists(),'Crear antes con supabase migration new'
target.write_text('\n\n'.join(['begin;',
 (ROOT/'supabase/policies/running_format_progression_v6.sql').read_text(encoding='utf8'),
 policy,adapter,
 'revoke all on function public.running_plan_v6(jsonb) from public,anon,authenticated;',
 'commit;'])+'\n',encoding='utf8')
print(target)
