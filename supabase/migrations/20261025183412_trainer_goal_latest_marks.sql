begin;
-- Añade actualidad y evolución sin cambiar la mejor marca histórica consultada,
-- las guardas de propietario/MFA ni los permisos del RPC público existente.
create or replace function trainer_private.get_trainer_client_goal(p_expected_owner uuid,p_client_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare goal trainer_private.client_goal_versions; result jsonb; can_edit boolean;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 perform trainer_private.require_client_portfolio(p_client_id);
 can_edit:=exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled and (valid_until is null or valid_until>statement_timestamp()))
  and exists(select 1 from public.trainer_client_relations where trainer_id=auth.uid() and client_id=p_client_id and ended_at is null)
  and exists(select 1 from public.trainer_clients where trainer_id=auth.uid() and client_id=p_client_id and archived_at is null);
 select * into goal from trainer_private.client_goal_versions where trainer_id=auth.uid() and client_id=p_client_id order by revision desc limit 1;
 if not found then return jsonb_build_object('revision',0,'title','','target_date',null,'targets','[]'::jsonb,'history_complete',true,'evaluations_considered',0,'can_edit',can_edit);end if;
 -- Un máximo explícito evita presentar una muestra reciente como récord de
 -- toda la vida. Solo pruebas completadas propias y protocolos idénticos.
 with candidates as materialized (
  select d.id,d.assessment_id,d.answers,d.completed_at from trainer_private.assessment_deliveries d
   where d.trainer_id=auth.uid() and d.client_id=p_client_id and d.status='completed' and d.completed_at is not null
   order by d.completed_at desc,d.id desc limit 201
 ), recent as materialized (select * from candidates order by completed_at desc,id desc limit 200),
 target_rows as materialized (
  select t.ordinality,t.value from jsonb_array_elements(goal.content->'targets') with ordinality t(value,ordinality)
 ), marks as materialized (
  -- La evaluación más reciente se conserva también cuando todos sus intentos
  -- son nulos: una marca antigua no sustituye una medición actual ausente.
  select t.ordinality,d.id,d.completed_at,
   case when t.value->'protocol'->>'direction'='higher' then max((a.value->>'value')::numeric)
    else min((a.value->>'value')::numeric) end as mark
  from target_rows t cross join recent d join trainer_private.assessments b on b.id=d.assessment_id
  cross join lateral jsonb_array_elements(b.content->'tests') test
  left join lateral jsonb_array_elements(coalesce(d.answers->(test->>'id'),'[]'::jsonb)) a(value)
   on a.value->'valid'='true'::jsonb and jsonb_typeof(a.value->'value')='number'
  where test->>'protocol_fingerprint'=t.value->'protocol'->>'protocol_fingerprint'
   and test->>'unit'=t.value->'protocol'->>'unit' and test->>'direction'=t.value->'protocol'->>'direction'
   and test->'resolution'=t.value->'protocol'->'resolution'
  group by t.ordinality,d.id,d.completed_at,t.value->'protocol'->>'direction'
 ), ranked as materialized (
  select m.*,row_number() over(partition by ordinality order by completed_at desc,id desc) as position from marks m
 ), enriched as (
  select t.ordinality,t.value||jsonb_build_object('best',best.mark,'recorded_at',best.completed_at,
   'latest',latest.mark,'latest_at',latest.completed_at,'previous',latest.previous_mark,'previous_at',latest.previous_at) as target
  from target_rows t
  left join lateral (
   select m.mark,m.completed_at from marks m where m.ordinality=t.ordinality and m.mark is not null
   order by case when t.value->'protocol'->>'direction'='higher' then m.mark end desc nulls last,
    case when t.value->'protocol'->>'direction'='lower' then m.mark end asc nulls last,m.completed_at desc,m.id desc limit 1
  ) best on true
  left join lateral (
   select max(mark) filter(where position=1) as mark,max(completed_at) filter(where position=1) as completed_at,
    max(mark) filter(where position=2) as previous_mark,max(completed_at) filter(where position=2) as previous_at
   from ranked where ordinality=t.ordinality and position<=2
  ) latest on true
 )
 select goal.content||jsonb_build_object('revision',goal.revision,'can_edit',can_edit,'targets',coalesce((select jsonb_agg(target order by ordinality) from enriched),'[]'),
  'history_complete',(select count(*)<=200 from candidates),'evaluations_considered',(select count(*) from recent)) into result;
 return result;
end $$;

commit;
