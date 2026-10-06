-- Un programa publicado continúa por sus resultados. La agenda no es un calculador.
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

create or replace function public.save_adaptive_program_preferences(p_goal_id uuid,p_target_date date,p_targets jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare setup jsonb; obj jsonb; item record; n numeric;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if auth.uid() is null or not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then
  raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 if p_target_date is null or p_target_date<current_date then
  raise exception 'Elige una fecha de prueba actual o futura.' using errcode='22023'; end if;
 if p_targets is null or jsonb_typeof(p_targets)<>'object' then raise exception 'Objetivos no válidos.'; end if;
 setup:=public.get_preparation_training_setup(p_goal_id);
 for item in select * from jsonb_each(p_targets) loop
  select value into obj from jsonb_array_elements(setup->'objectives') where value->>'objective_key'=item.key;
  n:=(item.value->>'value')::numeric;
  if obj is null or item.value->>'measurement' is distinct from obj->>'measurement' or n is null or n not between 0.01 and 100000
    or (obj->>'measurement' in ('REPS','REPS_IN_TIME') and n<>trunc(n)) then raise exception 'Revisa la marca objetivo y su unidad.' using errcode='22023'; end if;
 end loop;
 update public.preparation_goals set target_date=p_target_date where id=p_goal_id;
 insert into public.adaptive_program_states(preparation_goal_id,objective_targets) values(p_goal_id,p_targets)
 on conflict(preparation_goal_id) do update set objective_targets=excluded.objective_targets,updated_at=now();
end $$;
create or replace function public.advance_adaptive_program(p_goal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.adaptive_program_states%rowtype; g public.preparation_goals%rowtype; previous_week date; next_week date;
 plan jsonb; reason text; total int; completed int;
begin
 -- Mismo orden de candados que la publicación y la revisión de semanas.
 perform 1 from public.profiles where id=auth.uid() for update;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active';
 if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into a from public.adaptive_program_states where preparation_goal_id=p_goal_id for update;
 if not found or not a.auto_advance then return coalesce(to_jsonb(a),'{}'); end if;
 select max(week_start) into previous_week from (
      select week_start from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
      union select week_start from public.running_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null
    ) weeks;
 if previous_week is null then return to_jsonb(a); end if;
 if not public.preparation_week_closed(p_goal_id,previous_week) then
  update public.adaptive_program_states set status='training',continuation_code='waiting_results',next_generation_on=null,message='La siguiente semana se preparará al resolver las sesiones de esta semana.',last_error_code=null where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 next_week:=greatest(previous_week+7,current_date-extract(isodow from current_date)::int+1);
 if next_week>=g.target_date then
  update public.adaptive_program_states set status='complete',continuation_code='complete',next_generation_on=null,message='Has llegado al final de la preparación. Revisa tus resultados.',updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
  return to_jsonb(a);
 end if;
 select count(*),count(*) filter(where status='completed') into total,completed from public.scheduled_workouts
 where preparation_goal_id=p_goal_id and scheduled_date between previous_week and previous_week+6;
 if completed=0 then reason:='No hay entrenamientos completados esta semana. Revisa tu situación y disponibilidad antes de continuar.';
 else
  -- Solo una semana por delante. Un registro adelantado no encadena meses ficticios.
  if next_week>current_date-extract(isodow from current_date)::int+8 then
    update public.adaptive_program_states set status='training',continuation_code='waiting_date',
      next_generation_on=next_week-7,last_error_code=null,
      message='Esta semana está cerrada por adelantado. La siguiente se preparará automáticamente a partir del '||to_char(next_week-7,'DD/MM')||', con los resultados disponibles.',updated_at=now()
      where preparation_goal_id=p_goal_id returning * into a;
    return to_jsonb(a);
   end if;
  begin
   plan:=public.calculate_preparation_week(p_goal_id,next_week);
   if plan->>'status'='ready' then
    plan:=public.publish_preparation_week(p_goal_id,next_week,plan);
    update public.adaptive_program_states set status='training',continuation_code='week_ready',next_generation_on=null,message='Tu próxima semana está preparada con los resultados registrados.',last_generated_week=next_week,last_error_code=null,updated_at=now()
     where preparation_goal_id=p_goal_id returning * into a;
    return to_jsonb(a);
   end if;
   reason:=coalesce(plan->>'reason','Revisa los datos pendientes antes de continuar.');
   if jsonb_array_length(coalesce(plan->'pending','[]'))>0 then reason:=coalesce(plan->'pending'->0->>'reason',reason); end if;
  exception when others then
   update public.adaptive_program_states set last_error_code=sqlstate where preparation_goal_id=p_goal_id;
   reason:='Tus resultados están guardados. Revisa los datos del programa para preparar la siguiente semana.';
  end;
 end if;
 update public.adaptive_program_states set status='needs_review',continuation_code='needs_review',review_items=coalesce(plan->'pending',jsonb_build_array(jsonb_build_object('status',coalesce(plan->>'status','needs_context'),'reason',reason))),next_generation_on=null,message=reason,updated_at=now() where preparation_goal_id=p_goal_id returning * into a;
 return to_jsonb(a);
end $$;
create or replace function public.activate_adaptive_program(p_goal_id uuid,p_week_start date,p_expected_proposal jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p jsonb;
begin
 if not exists(select 1 from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and status='active') then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 if not exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id) then raise exception 'Guarda antes la fecha y los objetivos del programa.'; end if;
 p:=public.publish_preparation_week(p_goal_id,p_week_start,p_expected_proposal);
 update public.adaptive_program_states set auto_advance=true,status='training',continuation_code='waiting_results',next_generation_on=null,started_week=coalesce(started_week,p_week_start),last_generated_week=p_week_start,
 message='La siguiente semana se preparará al resolver las sesiones de esta semana.',updated_at=now() where preparation_goal_id=p_goal_id;
 return p;
end $$;
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

commit;
