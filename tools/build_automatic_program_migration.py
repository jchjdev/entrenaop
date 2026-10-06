"""Genera la corrección de continuidad sin reescribir migraciones aplicadas."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
old = (root / 'supabase/migrations/20261004008000_adaptive_program_lifecycle.sql').read_text(encoding='utf-8-sig')

def function(name):
    match = re.search(r'create (?:or replace )?function public\.' + name + r'\([\s\S]*?end\s*;?\s*\$\$;', old)
    assert match, name
    return match.group().replace('create function', 'create or replace function', 1)

preferences = function('save_adaptive_program_preferences').replace(
    " or p_target_date>(current_date+interval '1 year')::date", ''
).replace('Elige la fecha de la prueba dentro de los próximos doce meses.', 'Elige una fecha de prueba actual o futura.')

advance = function('advance_adaptive_program')
advance = advance.replace(
    'select max(week_start) into previous_week from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;',
    '''select max(week_start) into previous_week from (
      select week_start from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
      union select week_start from public.running_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
    ) weeks;'''
)
advance = advance.replace("status='training',message='La siguiente semana", "status='training',continuation_code='waiting_results',next_generation_on=null,message='La siguiente semana")
advance = advance.replace("status='complete',message=", "status='complete',continuation_code='complete',next_generation_on=null,message=")
advance = advance.replace(
    'if next_week>current_date-extract(isodow from current_date)::int+8 then return to_jsonb(a); end if;',
    '''if next_week>current_date-extract(isodow from current_date)::int+8 then
    update public.adaptive_program_states set status='training',continuation_code='waiting_date',
      next_generation_on=next_week-7,last_error_code=null,
      message='Esta semana está cerrada por adelantado. La siguiente se preparará automáticamente a partir del '||to_char(next_week-7,'DD/MM')||', con los resultados disponibles.',updated_at=now()
      where preparation_goal_id=p_goal_id returning * into a;
    return to_jsonb(a);
   end if;'''
)
advance = advance.replace("status='training',message='Tu próxima", "status='training',continuation_code='week_ready',next_generation_on=null,message='Tu próxima")
advance = advance.replace("status='needs_review',message=reason", "status='needs_review',continuation_code='needs_review',next_generation_on=null,message=reason")
advance = advance.replace("status='needs_review',continuation_code='needs_review',next_generation_on=null,message=reason", "status='needs_review',continuation_code='needs_review',review_items=coalesce(plan->'pending',jsonb_build_array(jsonb_build_object('status',coalesce(plan->>'status','needs_context'),'reason',reason))),next_generation_on=null,message=reason")

activation = function('activate_adaptive_program').replace("auto_advance=true,status='training',", "auto_advance=true,status='training',continuation_code='waiting_results',next_generation_on=null,")

header = '''-- Un programa publicado continúa por sus resultados. La agenda no es un calculador.
begin;
alter table public.adaptive_program_states
 add column continuation_code text not null default 'setup'
   check(continuation_code in ('setup','waiting_results','waiting_date','week_ready','needs_review','complete')),
 add column next_generation_on date,
 add column review_items jsonb not null default '[]';
alter table public.adaptive_program_states alter column policy_version set default 'adaptive_program_v1_1';
update public.adaptive_program_states set policy_version='adaptive_program_v1_1';

-- Incorpora preparaciones ya publicadas al recorrido único, conservando decisiones y resultados.
insert into public.adaptive_program_states(preparation_goal_id,auto_advance,status,started_week,last_generated_week,continuation_code)
select g.id,true,'training',min(d.week_start),max(d.week_start),'waiting_results'
from public.preparation_goals g join (
 select preparation_goal_id,week_start from public.preparation_week_decisions where superseded_at is null
 union select preparation_goal_id,week_start from public.running_week_decisions where superseded_at is null
) d on d.preparation_goal_id=g.id
where g.status='active'
group by g.id
on conflict(preparation_goal_id) do update set auto_advance=true,
 status=case when adaptive_program_states.status='draft' then 'training' else adaptive_program_states.status end,
 started_week=coalesce(adaptive_program_states.started_week,excluded.started_week),
 last_generated_week=excluded.last_generated_week,updated_at=now();
'''

refresh = '''
-- Recuperación idempotente al abrir la agenda. Solo programas del usuario autenticado.
create function public.refresh_adaptive_programs() returns jsonb
language plpgsql security definer set search_path='' as $$
declare candidate record; result jsonb;
begin
 if auth.uid() is null then raise exception 'Inicia sesión para consultar tu programa.' using errcode='42501'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 for candidate in select pg.id from public.preparation_goals pg join public.adaptive_program_states a on a.preparation_goal_id=pg.id
   where pg.user_id=auth.uid() and pg.status='active' and a.auto_advance order by pg.id loop
  begin
   perform public.advance_adaptive_program(candidate.id);
  exception when others then
   update public.adaptive_program_states set status='needs_review',continuation_code='needs_review',last_error_code=sqlstate,
    message='Tus entrenamientos están guardados. No hemos podido actualizar el programa; vuelve a intentarlo.',updated_at=now()
   where preparation_goal_id=candidate.id;
  end;
 end loop;
 select coalesce(jsonb_agg(jsonb_build_object(
   'goal_id',g.id,'name',p.name,'target_date',g.target_date,
   'status',coalesce(a.status,'draft'),'continuation_code',coalesce(a.continuation_code,'setup'),
   'message',coalesce(a.message,'Completa los datos iniciales para empezar tu programa.'),
   'current_week',a.last_generated_week,'next_generation_on',a.next_generation_on
 ) order by g.created_at),'[]') into result
 from public.preparation_goals g join public.preparation_programs p on p.id=g.program_id
 left join public.adaptive_program_states a on a.preparation_goal_id=g.id
 where g.user_id=auth.uid() and g.status='active';
 return result;
end $$;
revoke all on function public.refresh_adaptive_programs() from public,anon;
grant execute on function public.refresh_adaptive_programs() to authenticated;
'''
(root / 'supabase/migrations/20261004010000_automatic_program_follow_through.sql').write_text(
    header + '\n' + preferences + '\n' + advance + '\n' + activation + refresh + '\ncommit;\n', encoding='utf-8'
)
