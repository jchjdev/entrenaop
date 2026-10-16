-- Agenda, realización local y recepción son hechos distintos. Los históricos
-- sin reloj de realización conservan su fecha de recepción, sin backfill.
alter table public.workout_executions
 add column performed_at timestamptz,
 add column performed_utc_offset_minutes integer,
 add column abandoned_block_order integer,
 add constraint workout_performed_clock check (
   (performed_at is null and performed_utc_offset_minutes is null) or
   (performed_at is not null and performed_utc_offset_minutes is not null and isfinite(performed_at)
    and performed_utc_offset_minutes between -840 and 840)),
 add constraint workout_abandoned_block check (
   abandoned_block_order is null or (status='abandoned' and abandoned_block_order>=0));

create function public.workout_performed_on_v1(e public.workout_executions) returns date
language sql immutable set search_path='' as $$
 select ((coalesce(e.performed_at,e.completed_at) at time zone 'UTC')
   +make_interval(mins=>coalesce(e.performed_utc_offset_minutes,0)))::date
$$;

-- Una cita pendiente ocupa su fecha de agenda; un entrenamiento realizado
-- aporta carga y recuperación en su fecha real, aunque se haya desplazado.
create function public.workout_load_on_v1(s public.scheduled_workouts) returns date
language sql stable set search_path='' as $$
 select coalesce((select public.workout_performed_on_v1(e) from public.workout_executions e
   where e.id=s.execution_id),s.scheduled_date)
$$;

-- Se proyecta cada bloque sin reescribir el resultado global. Un bloque
-- terminado puede ser tolerado aunque se abandone otro después. Las molestias
-- conservan el bloqueo global; lo no intentado no acredita dificultad.
create function public.workout_block_outcome_v1(p_execution uuid,p_block integer default null)
returns jsonb language sql stable set search_path='' as $$
 with outcome as (
 select e.status,e.abandonment_reason,
   count(s.id)>0 and bool_and(s.status='completed') all_recorded,
   coalesce(bool_or(s.status='completed'),false) has_work,
   coalesce(bool_or(s.block_order=e.abandoned_block_order),false) stopped_here,
   count(s.id)>0 and bool_and(s.status='completed' and case when s.block_format='running' then
     (s.target_duration_seconds is null or coalesce(s.actual_duration_seconds,0)>=s.target_duration_seconds*(public.running_policy_v1()->>'completion_min')::numeric)
     and (s.target_distance_meters is null or coalesce(s.actual_distance_meters,0)>=s.target_distance_meters*(public.running_policy_v1()->>'completion_min')::numeric)
    when s.performance_prescription->>'measurement' in ('REPS','LOAD_REPS','DURATION','REPS_IN_TIME','DISTANCE','HEIGHT','MAX_LOAD') then
     coalesce((s.performance_result->>'value')::numeric,0)>=(s.performance_prescription->>'target_value')::numeric
     and (s.performance_prescription->>'measurement'<>'REPS_IN_TIME' or coalesce((s.performance_result->>'actual_duration_seconds')::numeric,0)>=(s.performance_prescription->>'fixed_duration_seconds')::numeric)
    else true end) dose_completed
 from public.workout_executions e left join public.workout_execution_sets s on s.execution_id=e.id
   and (case when p_block is null then s.block_format='running'
     -- Los tramos de preparación/cierre no acreditan tolerancia del trabajo.
     and (s.target_rpe is not null or not exists(select 1 from public.workout_execution_sets w
       where w.execution_id=e.id and w.block_format='running' and w.target_rpe is not null))
     else s.block_order=p_block end)
 where e.id=p_execution group by e.id
 )
 select jsonb_build_object('status',case
   when abandonment_reason='discomfort' then status
   when all_recorded then 'completed'
   when abandonment_reason='lack_of_time' and has_work and not dose_completed then 'abandoned'
   when status='abandoned' and not stopped_here
     then 'in_progress'
   else status end,
   'abandonment_reason',case
     when abandonment_reason='discomfort' then abandonment_reason
     -- Registrar una serie como resuelta no prueba haber completado su dosis.
     -- Si fue parcial por tiempo, conservar ese motivo evita fabricar fatiga.
     when abandonment_reason='lack_of_time' and has_work and not dose_completed then abandonment_reason
     when all_recorded then null
     when stopped_here then abandonment_reason
     -- Antes de este contrato solo se conoce el motivo global. No localizarlo
     -- por adivinación: la dosis y el esfuerzo registrados siguen disponibles.
     else null end)
 from outcome
$$;

create function public.set_workout_performed_clock_v1(p_execution uuid,p_at timestamptz,p_offset integer)
returns void language plpgsql security definer set search_path='' as $$
declare e public.workout_executions%rowtype;
begin
 select * into e from public.workout_executions where id=p_execution and user_id=auth.uid() for update;
 if not found or e.status<>'in_progress' then raise exception 'Active workout execution not found'; end if;
 if p_at is null or not isfinite(p_at) or p_offset is null or p_offset not between -840 and 840
   or p_at>now()+interval '5 minutes' or p_at<e.started_at-interval '5 minutes' then
   raise exception 'La fecha de realización no es válida. Revisa el reloj del dispositivo.' using errcode='22023'; end if;
 update public.workout_executions set performed_at=p_at,performed_utc_offset_minutes=p_offset where id=e.id;
end $$;

-- El bloqueo precede al recibo: dos reintentos concurrentes de la misma
-- operación no cierran ni publican dos veces. El reloj viaja en la cola offline.
create function public.finish_workout_observed_idempotent(
 p_operation_id uuid,p_execution_id uuid,p_final_rpe integer,p_performed_at timestamptz,
 p_utc_offset_minutes integer,p_notes text default null,p_average_heart_rate_bpm integer default null,
 p_max_heart_rate_bpm integer default null,p_result_source text default 'manual')
returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.workout_executions where id=p_execution_id and user_id=auth.uid() for update;
 if not found then raise exception 'Active workout execution not found'; end if;
 if exists(select 1 from public.workout_mutation_receipts where id=p_operation_id and user_id=auth.uid()
   and mutation_kind='finish' and resource_id=p_execution_id) then return; end if;
 perform public.set_workout_performed_clock_v1(p_execution_id,p_performed_at,p_utc_offset_minutes);
 perform public.finish_workout_execution_idempotent(p_operation_id,p_execution_id,p_final_rpe,p_notes,
   p_average_heart_rate_bpm,p_max_heart_rate_bpm,p_result_source);
end $$;

create function public.abandon_workout_observed_idempotent(
 p_operation_id uuid,p_execution_id uuid,p_reason text,p_performed_at timestamptz,p_utc_offset_minutes integer)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.workout_executions where id=p_execution_id and user_id=auth.uid() for update;
 if not found then raise exception 'Active workout execution not found'; end if;
 if exists(select 1 from public.workout_mutation_receipts where id=p_operation_id and user_id=auth.uid()
   and mutation_kind='abandon' and resource_id=p_execution_id) then return; end if;
 perform public.set_workout_performed_clock_v1(p_execution_id,p_performed_at,p_utc_offset_minutes);
 perform public.abandon_workout_execution_idempotent(p_operation_id,p_execution_id,p_reason);
end $$;

-- Cota de búsqueda: como máximo se comparten cuatro minutos de activación
-- general y tres de cierre. El coste exacto se comprueba antes de puntuar.
create function public.preparation_running_budget_v1(candidate jsonb,availability jsonb,p_credit integer default 7) returns jsonb
language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(a.key,greatest(0,(a.value::text)::int
   -coalesce((candidate->'days'->a.key->>'minutes')::int,0)
   +case when coalesce((candidate->'days'->a.key->>'minutes')::int,0)>0 then least(7,greatest(0,p_credit)) else 0 end)),'{}')
 from jsonb_each(availability) a
$$;

-- La búsqueda conoce los mismos criterios de orden que la materialización.
-- Una carrera fácil sin segmentos de preparación no aporta siete minutos.
create or replace function public.preparation_shared_minutes_v2(force_session jsonb,run_session jsonb) returns integer
language sql immutable set search_path='' as $$
 select coalesce((force_session->>'standalone_minutes')::int,(force_session->>'minutes')::int)+(run_session->>'minutes')::int
 -case when coalesce(force_session->>'session_order',case when exists(select 1 from jsonb_array_elements(coalesce(force_session->'work','[]')) w
    where w->>'model' in ('power','course','reactive_agility','rope')) then 'performance_first' else 'running_first' end)='running_first'
   or exists(select 1 from jsonb_array_elements(run_session->'segments') s where s->>'role'='warmup') then 4 else 0 end
 -case when exists(select 1 from jsonb_array_elements(run_session->'segments') s where s->>'role'='cooldown') then 3 else 0 end
$$;

revoke all on function public.workout_performed_on_v1(public.workout_executions),
 public.workout_load_on_v1(public.scheduled_workouts),
 public.workout_block_outcome_v1(uuid,integer),public.set_workout_performed_clock_v1(uuid,timestamptz,integer),
 public.preparation_running_budget_v1(jsonb,jsonb,integer),
 public.finish_workout_observed_idempotent(uuid,uuid,integer,timestamptz,integer,text,integer,integer,text),
 public.abandon_workout_observed_idempotent(uuid,uuid,text,timestamptz,integer) from public,anon,authenticated;
grant execute on function public.finish_workout_observed_idempotent(uuid,uuid,integer,timestamptz,integer,text,integer,integer,text),
 public.abandon_workout_observed_idempotent(uuid,uuid,text,timestamptz,integer) to authenticated;
