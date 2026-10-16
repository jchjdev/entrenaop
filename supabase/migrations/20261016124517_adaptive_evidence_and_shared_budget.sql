-- Reparación de evidencias y encaje; conserva decisiones publicadas y motores v3/v5.
begin;

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


create or replace function public.abandon_workout_execution(
  p_execution_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_reason not in (
    'lack_of_time',
    'too_difficult',
    'discomfort',
    'other'
  ) then
    raise exception 'Invalid workout abandonment reason';
  end if;

  update public.workout_executions as execution
  set
    status = 'abandoned',
    completed_at = now(),
    abandonment_reason = p_reason,
    abandoned_block_order = (select s.block_order from public.workout_execution_sets s
      where s.execution_id=execution.id and s.status='pending'
        and s.block_format not in ('warm_up','cool_down')
      order by s.block_order,s.item_order,s.set_order limit 1)
  where execution.id = p_execution_id
    and execution.user_id = auth.uid()
    and execution.status = 'in_progress';

  if not found then
    raise exception 'Active workout execution not found';
  end if;
end;
$$;

create or replace function public.running_evaluate_v2(p_session jsonb, p_execution jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
 cfg jsonb:=public.running_policy_v1();
 family text := p_session->>'family'; seg jsonb; actual jsonb; idx integer := 0;
 expected integer := 0; complete integer := 0; missing integer := 0;
 off_pace integer := 0; slow integer := 0; recovery_bad integer := 0;
 total_seconds numeric := 0; total_meters numeric := 0;
 paces numeric[] := '{}'; variability numeric; midpoint numeric;
 first_pace numeric; last_pace numeric; pace numeric; fade numeric;
 effort numeric := (p_execution->>'rpe')::numeric;
 ceiling numeric := (public.running_policy_v1()->'rpe_ceiling'->>family)::numeric;
 status text := 'unknown'; reason text := 'missing_results';
begin
 if coalesce((p_execution->>'discomfort')::boolean,false) then
   return jsonb_build_object('status','pain','reason','reported_discomfort');
 end if;
 if p_execution->>'status' = 'skipped' then
   return jsonb_build_object('status','missing','reason','not_performed');
 end if;
 if p_execution->>'status' in ('planned','in_progress','cancelled') then
   return jsonb_build_object('status','unknown','reason','unconfirmed_execution');
 end if;
 for seg in select value from jsonb_array_elements(coalesce(p_session->'segments','[]')) loop
   actual := p_execution->'sets'->idx; idx := idx+1;
   if seg->>'role' <> 'work' then continue; end if;
   effort := greatest(effort,(actual->>'rpe')::numeric);
   expected := expected+1;
   if actual is null or actual->>'status' is null then missing := missing+1; continue; end if;
   if actual->>'status' <> 'completed' then continue; end if;
   if (actual->>'seconds')::numeric is null or (actual->>'seconds')::numeric <= 0
     or ((seg ? 'meters' or seg ? 'pace_min') and coalesce((actual->>'meters')::numeric,0)<=0) then
     missing := missing+1; continue;
   end if;
   -- La carga realizada cuenta aunque no complete la dosis prescrita.
   total_seconds := total_seconds+(actual->>'seconds')::numeric;
   total_meters := total_meters+coalesce((actual->>'meters')::numeric,0);
   if (seg ? 'meters' and (actual->>'meters')::numeric < (seg->>'meters')::numeric*(cfg->>'completion_min')::numeric)
     or (seg ? 'seconds' and (actual->>'seconds')::numeric < (seg->>'seconds')::numeric*(cfg->>'completion_min')::numeric) then
     continue;
   end if;
   complete := complete+1;
   pace := (actual->>'seconds')::numeric*1000/nullif((actual->>'meters')::numeric,0);
   if pace is not null then paces:=array_append(paces,pace); end if;
   first_pace := coalesce(first_pace,pace); last_pace := pace;
   if pace < (seg->>'pace_min')::numeric*(1-(cfg->>'fast_tolerance')::numeric) then off_pace := off_pace+1; end if;
   if pace > (seg->>'pace_max')::numeric*(1+(cfg->>'pace_tolerance')::numeric) then slow := slow+1; end if;
   if seg ? 'recovery_seconds' then
     if actual->>'recovery_seconds' is null then missing := missing+1;
     elsif (actual->>'recovery_seconds')::numeric > (seg->>'recovery_seconds')::numeric*(1+(cfg->>'recovery_extension')::numeric) then
       recovery_bad := recovery_bad+1;
     end if;
   end if;
 end loop;
 select percentile_cont(0.5) within group(order by x) into midpoint from unnest(paces) x;
 -- Regularidad de todos los tramos, no solo primero y último.
 select max(abs(x-midpoint))/nullif(midpoint,0) into variability from unnest(paces) x;
 fade := case when expected>1 and first_pace>0 then last_pace/first_pace-1 end;
 if p_execution->>'abandonment_reason' = 'lack_of_time' then
   status := 'time'; reason := 'interrupted_lack_of_time';
 elsif p_execution->>'abandonment_reason' = 'too_difficult' then
   status := 'struggle'; reason := 'abandoned_too_difficult';
 elsif expected=0 or missing>0 or effort is null then
   status := 'unknown'; reason := 'incomplete_evidence';
 elsif off_pace>0 then
   status := 'off_intent'; reason := 'faster_than_prescribed';
 elsif family in ('T','V','S') and cardinality(paces)>=3 and variability>0.08 then
   status := 'struggle'; reason := 'irregular_work_intervals';
 elsif complete < expected*(cfg->>'completion_min')::numeric or effort>ceiling or slow>expected/2.0
   or coalesce(fade,0)>(cfg->>'fade_max')::numeric or recovery_bad>0 then
   status := 'struggle'; reason := 'dose_or_effort_not_tolerated';
 elsif p_execution->>'status' = 'completed' then
   status := 'tolerated'; reason := 'work_pace_effort_tolerated';
 end if;
 return jsonb_build_object('status',status,'reason',reason,'family',family,
   'objective_difficulty',status<>'time' and (complete<expected*(cfg->>'completion_min')::numeric or slow>expected/2.0 or recovery_bad>0 or coalesce(fade,0)>(cfg->>'fade_max')::numeric or (family in ('T','V','S') and coalesce(variability,0)>0.08)),
   'effort_review',status='struggle' and effort>ceiling,
   'completed_work',complete,'expected_work',expected,'missing',missing,
   'pace_seconds_per_km',case when total_meters>0 then total_seconds*1000/total_meters end,
   'fade',fade,'max_deviation_from_median',variability,'rpe',effort,'work_seconds',total_seconds,
   'confidence',case when missing=0 and effort is not null and expected>0 then 'observed' else 'insufficient' end);
end $$;

create or replace function public.valid_performance_prescription(p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; m text;
begin
  if p is null then return true; end if;
  if jsonb_typeof(p) <> 'object' or not p ?& array[
    'schema_version','exercise_code','exercise_version','protocol_key',
    'protocol_version','setup_key','measurement','load_mode','policy_version',
    'target_value','intent'] then return false; end if;
  if exists(select 1 from jsonb_object_keys(p) x where x <> all(array[
    'schema_version','exercise_code','exercise_version','protocol_key',
    'protocol_version','setup_key','measurement','load_mode','policy_version',
    'target_value','intent','fixed_duration_seconds','fixed_distance_meters',
    'external_load_kg','body_mass_kg','target_rir','instructions',
    'records_stimulus_responses','records_penalty_seconds','effort_mode','target_rpe','stimulus_code'])) then return false; end if;
  if p->>'schema_version' <> '1' then return false; end if;
  foreach k in array array['schema_version','measurement','load_mode','intent','target_value'] loop
    if p->>k is null then return false; end if;
  end loop;
  foreach k in array array['exercise_code','protocol_key','setup_key','policy_version'] loop
    if jsonb_typeof(p->k) <> 'string' or length(btrim(p->>k)) not between 1 and 500 then return false; end if;
  end loop;
  foreach k in array array['exercise_version','protocol_version'] loop
    if jsonb_typeof(p->k) <> 'number' or (p->>k)::numeric < 1
      or (p->>k)::numeric <> trunc((p->>k)::numeric) then return false; end if;
  end loop;
  foreach k in array array['target_value','fixed_duration_seconds','fixed_distance_meters',
      'external_load_kg','body_mass_kg','target_rir'] loop
    if p->>k is not null and (jsonb_typeof(p->k) <> 'number'
        or (p->>k)::numeric < 0 or (p->>k)::numeric > 1000000) then return false; end if;
  end loop;
  if coalesce((p->>'target_value')::numeric,0) <= 0 then return false; end if;
  m := p->>'measurement';
  if m <> all(array['REPS','LOAD_REPS','DURATION','REPS_IN_TIME','MAX_LOAD',
    'TIME_FOR_DISTANCE','TIME_FOR_COURSE','DISTANCE','HEIGHT','PASS_FAIL','REACTIVE_METRICS']) then return false; end if;
  if p->>'load_mode' <> all(array['bodyweight','external_load','bodyweight_plus_external','assisted'])
    or p->>'intent' <> all(array['work','control','practice']) then return false; end if;
  if m in ('REPS','LOAD_REPS','REPS_IN_TIME','PASS_FAIL')
      and (p->>'target_value')::numeric <> trunc((p->>'target_value')::numeric) then return false; end if;
  if m = 'PASS_FAIL' and (p->>'target_value')::numeric <> 1 then return false; end if;
  if m = 'REPS_IN_TIME' and coalesce((p->>'fixed_duration_seconds')::numeric,0) <= 0 then return false; end if;
  if m = 'TIME_FOR_DISTANCE' and coalesce((p->>'fixed_distance_meters')::numeric,0) <= 0 then return false; end if;
  if p->>'load_mode' in ('external_load','bodyweight_plus_external') and coalesce((p->>'external_load_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'load_mode' = 'bodyweight_plus_external' and coalesce((p->>'body_mass_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'target_rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (p->>'target_rir')::numeric > 10) then return false; end if;
  foreach k in array array['records_stimulus_responses','records_penalty_seconds'] loop
    if p ? k and jsonb_typeof(p->k)<>'boolean' then return false; end if;
  end loop;
  if p->>'records_stimulus_responses'='true' and m not in ('TIME_FOR_COURSE','PASS_FAIL') then return false; end if;
  if p->>'records_penalty_seconds'='true' and m<>'TIME_FOR_COURSE' then return false; end if;
  if p ? 'effort_mode' and coalesce(p->>'effort_mode','') not in ('none','rir','rpe') then return false; end if;
  if p->>'effort_mode'='rir' and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME') or p->>'intent'<>'work') then return false; end if;
  if p->>'target_rpe' is not null and (jsonb_typeof(p->'target_rpe')<>'number'
    or (p->>'target_rpe')::numeric not between 1 and 10 or p->>'effort_mode' is distinct from 'rpe') then return false; end if;
  if p ? 'stimulus_code' and (jsonb_typeof(p->'stimulus_code')<>'string' or length(p->>'stimulus_code') not between 1 and 80) then return false; end if;
  return true;
exception when others then return false;
end $$;

create or replace function public.performance_task_v3_core(reference jsonb,profile jsonb,history jsonb,wk date,target_date date,
 previous jsonb default '{}'::jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare cfg jsonb:=public.performance_bank_v2(); task jsonb:=reference->'task'; source_task jsonb:=reference->'task';
 kind text:=coalesce(reference->>'reference_kind','legacy_unknown'); code text:=profile->>'code';
 m text:=task->>'measurement'; model text; block_code text; block jsonb; phase text; dose jsonb; baseline jsonb;
 targets jsonb; evidence jsonb:='[]'; e jsonb; signal text; good int:=0; bad int:=0; counted int:=0;
 last_dates date[]:='{}'; last_on date; first_on date; observed date:=(reference->>'observed_on')::date;
 days_left int:=target_date-wk; series_count int:=jsonb_array_length(reference->'targets'); sets int; rest int;
 capacity numeric; total numeric; v numeric; idx int; budget numeric; minimum int; maximum int; step numeric; load numeric;
 work_seconds int; outcome text:='initial'; reason text; selection_reason text; instructions text;
 new_code text; new_name text; regions jsonb:=profile->'body_regions'; patterns jsonb:=profile->'movement_patterns';
 freq int:=least(2,greatest(1,coalesce((reference->>'frequency')::int,1))); history_dose jsonb;
 rpe numeric:=(reference->>'reported_rpe')::numeric; rir numeric:=(reference->>'reported_rir')::numeric;
 dynamic boolean; power boolean:=profile->'movement_modes' ? 'plyometric' or code in ('kettlebell_swing','medicine_ball_chest_throw');
begin
 if wk is null or extract(isodow from wk)<>1 then raise exception 'Semana no válida.'; end if;
 if target_date is null or target_date<wk then return jsonb_build_object('status','blocked','reason','Actualiza la fecha objetivo.'); end if;
 if kind in ('legacy_work','legacy_unknown') then return jsonb_build_object('status','needs_calibration',
  'reason','Aclara esta referencia: ¿era tu máximo, una serie con margen o varias series de entrenamiento? No necesitas repetirla si sigue siendo actual.'); end if;
 if reference->>'current_capacity_confirmed' is distinct from 'true' or observed is null or observed>wk+6 then
  return jsonb_build_object('status','needs_calibration','reason','Confirma qué hiciste y cuándo; usa datos actuales y reales.'); end if;
 select max((x->>'completed_on')::date),min((x->>'completed_on')::date) into last_on,first_on
  from jsonb_array_elements(coalesce(history,'[]')) x where (x->>'completed_on')::date<wk;
 if observed<wk-14 and (last_on is null or last_on<wk-21) then return jsonb_build_object('status','needs_calibration',
   'reason','Tras la interrupción necesitamos una práctica reciente. Una sola serie con buena técnica es suficiente.'); end if;
 select min(value::numeric),sum(value::numeric) into capacity,total from jsonb_array_elements_text(reference->'targets');
 if capacity is null or capacity<=0 then return jsonb_build_object('status','needs_calibration','reason','Elige una variante accesible y registra una práctica válida.'); end if;
 phase:=coalesce(reference->>'strategy_phase',case when days_left<=7 then 'taper' when days_left<=28 then 'specific'
   when first_on is null or wk-first_on<14 then 'base' else 'development' end);
 model:=case when profile->'movement_patterns' ? 'carry' then 'carry' when power then 'power'
   when profile->'movement_patterns' ? 'rope_climb' then 'rope'
   when profile->'movement_patterns' ? 'reactive_agility' then 'reactive_agility'
   when m='TIME_FOR_COURSE' then 'course' when m='LOAD_REPS' then 'load_repetitions'
   when m='REPS' then 'repetitions' when m='REPS_IN_TIME' then 'timed_repetitions'
   when m='DURATION' then 'isometric' else 'skill' end;
 if m='MAX_LOAD' then return jsonb_build_object('status','needs_calibration','reason','Tu máximo queda como control. Registra una serie con carga y repeticiones para elegir el trabajo.'); end if;
 if (model='rope' or power) and kind in ('official_test','capacity_test') then return jsonb_build_object('status','needs_calibration',
  'reason','La marca máxima no acredita intentos repetibles de calidad. Registra una práctica de esta variante sin buscar un récord.'); end if;
 dynamic:=model in ('repetitions','load_repetitions');
 sets:=case when kind='repeated_work' then least(series_count,4) else 2 end;
 budget:=total;
 task:=task-'target_rir'-'target_rpe'-'effort_mode'-'stimulus_code';
 task:=task||jsonb_build_object('policy_version','performance_v3','intent','work');

 if dynamic then
  block_code:=case when model='load_repetitions' then 'LOAD-S01' when capacity<5 then 'REP-T01' else 'REP-E01' end;
  if capacity<2 and model='repetitions' then return jsonb_build_object('status','needs_calibration',
   'reason','Esta variante deja poco margen. Elige una inclinación o asistencia accesible y registra una serie; no hace falta un máximo.'); end if;
  v:=greatest(1,floor(capacity*case when kind='repeated_work' then 0.70 else 0.50 end));
  if kind='repeated_work' and rir>=3 then v:=greatest(1,floor(capacity*0.85)); end if;
  if model='load_repetitions' then
   if capacity<3 or (kind in ('capacity_test','official_test') and capacity-v<3) then return jsonb_build_object('status','needs_calibration','reason','Registra una serie con una carga menor que permita varias repeticiones con margen.'); end if;
   v:=least(v,coalesce((reference->>'rep_max')::int,6));
  end if;
  select jsonb_agg(v) into targets from generate_series(1,sets);
  selection_reason:='Series submáximas desde una práctica real; la cifra de referencia no se trata como un máximo estimado.';
  instructions:=coalesce(task->>'instructions','')||E'\nHaz hasta las repeticiones pautadas con buena técnica. Conserva al menos tres repeticiones de margen; si llegas a ese esfuerzo antes, para y registra las que hiciste. Puedes terminar con más margen: no añadas repeticiones para agotarte.';
 elsif model='isometric' then
  if capacity<6 then return jsonb_build_object('status','needs_calibration','reason','Usa una posición más accesible que puedas mantener unos segundos con buena técnica y registra esa variante.'); end if;
  block_code:=case when phase='taper' and previous->'dose'->'task'->>'stimulus_code' like 'ISO-%' then previous->'dose'->'task'->>'stimulus_code'
   when capacity<20 then 'ISO-T01' when phase='specific' and kind='repeated_work' and rpe<=7 then 'ISO-E02' else 'ISO-E01' end;
  v:=greatest(3,floor(capacity*case when kind='repeated_work' and rpe<=7 then 0.80 else 0.50 end));
  select jsonb_agg(v) into targets from generate_series(1,sets);
  selection_reason:='Trabajo de postura submáximo. La referencia conserva su tipo; sus segundos no se copian como series al límite.';
  instructions:='Mantén hasta el tiempo indicado, respirando. Termina antes si pierdes la postura o el esfuerzo supera '||case when block_code='ISO-T01' then '5' else '7' end||'/10. Cuenta solo tiempo válido; hoy no medimos tu máximo. 5 es moderado, 7 es difícil pero controlado; 10 sería tu límite.';
 elsif model='timed_repetitions' then
  block_code:=case when phase='specific' then 'TIME-SP02' when phase='taper' then coalesce(previous->'dose'->'task'->>'stimulus_code','TIME-SP01') else 'TIME-SP01' end;
  -- Ritmo de práctica derivado de una medición temporal compatible; no estima RIR ni capacidad de serie libre.
  v:=least(case when block_code='TIME-SP02' then 40 else 20 end,(task->>'fixed_duration_seconds')::numeric/3);
  task:=task||jsonb_build_object('fixed_duration_seconds',v,'protocol_key',task->>'protocol_key'||':fragment:'||v::text);
  v:=greatest(1,floor(capacity*v/(source_task->>'fixed_duration_seconds')::numeric*0.80));
  sets:=case when kind='repeated_work' then least(4,series_count) else 2 end;
  select jsonb_agg(v) into targets from generate_series(1,sets);
  selection_reason:='Fragmentos a ritmo practicable desde tu resultado temporal. No se convierte la marca en RIR ni en una serie máxima libre.';
  instructions:=coalesce(task->>'instructions','')||E'\nDistribuye las repeticiones de forma regular durante el fragmento. Mantén la técnica y no aceleres para recuperar repeticiones perdidas. Registra repeticiones válidas y el tiempo real; no es una marca del examen completo.';
 elsif model='course' and code in ('slalom_ball_course_16m','shuttle_5_10_5') then
  -- La marca del recorrido no permite inventar tiempos de sus sectores.
  block_code:=case when phase='base' then 'COD-T01' when phase='development' then 'COD-SP01' else 'COD-SP02' end;
  -- Consolidar la tarea técnica antes de cambiarla; el calendario no demuestra dominio.
  if phase='development' and (select count(*) from jsonb_array_elements(coalesce(history,'[]')) h
    where h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') and public.performance_exposure_signal_v2(h,h->'dose')='tolerated')<2 then block_code:='COD-T01'; end if;
  -- Familiarización periódica del recorrido ya medido, sin convertirla en un máximo.

  if phase='specific' and (select count(distinct (h->>'completed_on')::date) from jsonb_array_elements(coalesce(history,'[]')) h where (h->>'completed_on')::date between wk-21 and wk-1 and h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') and public.performance_exposure_signal_v2(h,h->'dose')='tolerated')<2 then block_code:='COD-T01'; end if;
  if phase='taper' then block_code:=coalesce(previous->'dose'->'task'->>'stimulus_code','COD-SP02'); end if;
  if block_code<>'COD-SP02' then
   new_code:=case when block_code='COD-T01' then 'cod_braking_10m' when code='slalom_ball_course_16m' then 'slalom_ball_course_sector' else 'cod_turn_180_5m' end;
   new_name:=case new_code when 'cod_braking_10m' then 'Aceleración suave y frenada en 10 m' when 'slalom_ball_course_sector' then 'Sector de eslalon y recogida de pelota' else 'Ida y vuelta técnica de 5 metros' end;
   instructions:=case new_code
    when 'cod_braking_10m' then 'Marca 10 metros y deja espacio libre para frenar. Acelera a velocidad cómoda; acorta los pasos para detenerte estable. Vuelve andando. No busques velocidad máxima. Cada serie es un intento.'
    when 'slalom_ball_course_sector' then 'En el circuito medido, practica los últimos tres conos, la recogida de pelota y los primeros pasos de retorno. Velocidad cómoda; termina sin desplazar conos ni perder la pelota. Cada serie es un intento.'
    else 'Marca dos líneas a 5 metros. Avanza a velocidad cómoda, frena antes de la línea, gira y vuelve. Alterna el lado de giro entre intentos. Cada serie es un intento.' end;
   task:=task-'fixed_duration_seconds'-'fixed_distance_meters';
   task:=task||jsonb_build_object('exercise_code',new_code,'exercise_version',1,'measurement','PASS_FAIL','intent','practice',
     'protocol_key',new_code||'_v1','protocol_version',1,'setup_key','standard:'||new_code||'_v1',
     'records_stimulus_responses',false,'records_penalty_seconds',false);
   targets:='[1,1,1,1]';
  else
   targets:=jsonb_build_array(capacity,capacity);
   task:=task||'{"intent":"practice"}'::jsonb;
   instructions:=coalesce(task->>'instructions','')||E'\nIntentos completos de calidad, con recuperación. El tiempo indicado es tu referencia, no una obligación de batirla. Detén los intentos si empeoran claramente la técnica o el control; registra el tiempo real.';
  end if;
  selection_reason:=case block_code when 'COD-T01' then 'Practicar y consolidar aproximación y frenada; tu marca del circuito no se convierte en tiempo de este ejercicio.' when 'COD-SP01' then 'Desarrollo del recorrido por sectores; medir calidad antes de exigir velocidad.' else 'Integrar o familiarizar el recorrido conocido, con descansos y sin imponer un récord. La integración se decide por la fase y la calidad reciente, sin un contador de tests.' end;
 elsif model='course' then
  return jsonb_build_object('status','needs_strategy','reason','Este recorrido necesita definir sus componentes técnicos antes de planificarlo automáticamente.');
 else
  block_code:=case when model='power' then 'POWER-P01' when model='rope' then 'ROPE-T01' when model='carry' then 'CARRY-E01' else 'SKILL-T01' end;
  sets:=least(series_count,3);
  if model='carry' then v:=greatest(1,floor(capacity*0.70));
  elsif power and m in ('REPS','LOAD_REPS') then v:=least(3,capacity);
  else v:=capacity; end if;
  select jsonb_agg(v) into targets from generate_series(1,sets);
  task:=task||jsonb_build_object('intent',case when model='carry' then 'work' else 'practice' end);
  selection_reason:='Práctica con variante, carga y condiciones conocidas; el resultado no se interpreta como permiso para añadir intentos.';
  instructions:=coalesce(task->>'instructions','')||E'\nConserva la calidad del gesto y descansa lo indicado. La marca es una referencia, no un récord obligatorio. Si se pierde la técnica o la intención del movimiento, detén la práctica.';
 end if;
 select value into block from jsonb_array_elements(cfg->'blocks') where value->>'code'=block_code;
 rest:=(block->>'rest_seconds')::int;
 task:=task||jsonb_build_object('stimulus_code',block_code,'effort_mode',block->>'effort_mode','instructions',instructions,'target_value',targets->0);
 if block->>'effort_mode'='rir' then task:=task||'{"target_rir":3}'::jsonb; end if;
 if block->>'effort_mode'='rpe' then task:=task||jsonb_build_object('target_rpe',case when block_code='ISO-T01' then 5 else 7 end); end if;
 dose:=jsonb_build_object('task',task,'targets',targets,'rest_seconds',rest,'model',model,'stimulus_code',block_code);
 -- Recuperar la dosis publicada de ESTE estímulo, nunca trasladar adaptación entre protocolos.
 select h->'dose' into history_dose from jsonb_array_elements(coalesce(history,'[]')) h
  where h->'dose'->'task'->>'stimulus_code'=block_code and (h->>'completed_on')::date<wk
  order by h->>'completed_on' desc limit 1;
 if previous->'dose'->'task'->>'stimulus_code'=block_code and previous->>'reference_id'=reference->>'id' then dose:=previous->'dose';
 elsif history_dose is not null then dose:=history_dose; end if;
 baseline:=dose; targets:=dose->'targets'; task:=dose->'task';
 reason:=selection_reason;
 for e in select value from jsonb_array_elements(coalesce(history,'[]'))
  where (value->>'completed_on')::date between greatest(observed,wk-21) and wk-1 order by value->>'completed_on' desc loop
  if (e->>'completed_on')::date=any(last_dates) then continue; end if;
  signal:=public.performance_exposure_signal_v2(e,dose);
  evidence:=evidence||jsonb_build_array(jsonb_build_object('execution_id',e->'execution_id','date',e->'completed_on','signal',signal,'exposure',e));
  if signal='pain' then return jsonb_build_object('status','blocked','reason','Actualiza tu situación después de las molestias registradas.','evidence',evidence); end if;
  if signal='different_dose' then continue; end if;
  last_dates:=array_append(last_dates,(e->>'completed_on')::date);
  if signal='tolerated' then good:=good+1; elsif signal='difficulty' then bad:=bad+1; end if;
  counted:=counted+1; exit when counted=2;
 end loop;
 if previous->'dose' is not null or history_dose is not null then outcome:='maintain'; end if;
 if bad>=1 then
  -- Una dificultad reduce prudentemente; no esperar otra exposición al mismo fallo.
  outcome:='reduce'; reason:=reason||' La última respuesta comparable indica dificultad: reducimos trabajo y comprobamos cómo respondes.';
  if model in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') then
   select jsonb_agg(greatest(1,floor(value::numeric*0.85)) order by ordinality) into targets from jsonb_array_elements_text(targets) with ordinality;
   if targets=baseline->'targets' then return jsonb_build_object('status','needs_calibration','reason','La dosis mínima no se tolera: registra una variante o carga más accesible.','evidence',evidence); end if;
  elsif jsonb_array_length(targets)>1 then targets:=targets-(jsonb_array_length(targets)-1);
  else return jsonb_build_object('status','needs_calibration','reason','Revisa la variante y las condiciones antes de repetir ese intento difícil.','evidence',evidence); end if;
 elsif good=2 and phase<>'taper' then
  if model in ('repetitions','load_repetitions','isometric','timed_repetitions','carry') then
   select ordinality::int-1,value::numeric into idx,v from jsonb_array_elements_text(targets) with ordinality order by value::numeric,ordinality limit 1;
   maximum:=coalesce((reference->>'rep_max')::int,6); minimum:=coalesce((reference->>'rep_min')::int,4);
   load:=(task->>'external_load_kg')::numeric; step:=(reference->>'load_step_kg')::numeric;
   if model='load_repetitions' and v>=maximum then
    if step>0 and step<=load*0.10 then
     task:=task||jsonb_build_object('external_load_kg',load+step);
     select jsonb_agg(minimum) into targets from generate_series(1,jsonb_array_length(targets)); outcome:='progress';
    else reason:=reason||' Horquilla consolidada: confirma el siguiente escalón disponible antes de subir carga.'; end if;
   else
    targets:=jsonb_set(targets,array[idx::text],to_jsonb(v+case when model='isometric' then 2 else 1 end)); outcome:='progress';
   end if;
   if outcome='progress' then reason:=reason||' Dos exposiciones comparables con calidad y margen permiten subir una sola demanda.'; end if;
  else reason:=reason||' Calidad consolidada: mantener intentos, sin inventar velocidad ni añadir volumen.'; end if;
 elsif counted>0 then reason:=reason||' Mantenemos hasta disponer de respuesta comparable suficiente; no se completa información desconocida.';
 else reason:=reason||' Primera dosis de este estímulo: registra lo realizado para individualizar la siguiente.'; end if;
 if phase='taper' then
  select jsonb_agg(value order by ordinality) into targets from jsonb_array_elements(targets) with ordinality
   where ordinality<=greatest(1,ceil(jsonb_array_length(targets)/2.0));
  outcome:='maintain'; freq:=1; reason:=reason||' Puesta a punto: menos series, conservar el gesto conocido y evitar máximos.';
 end if;
 -- La práctica técnica de capacidad baja no exige un RIR incompatible con esa capacidad.
 -- Se aplica después de comparar la dosis histórica para conservar sus señales reales.
 if block_code='REP-T01' then
  task:=task||jsonb_build_object('instructions',coalesce(source_task->>'instructions','')||E'\nPractica las repeticiones indicadas de forma controlada. No busques el fallo: detente si pierdes la postura o el gesto deja de ser fluido. No necesitas estimar repeticiones restantes. Si no consigues una repetición limpia, registra una variante con apoyo o ayuda.');
 end if;
 task:=jsonb_set(task,'{target_value}',targets->0);
 dose:=dose||jsonb_build_object('task',task,'targets',targets);
 work_seconds:=public.performance_work_seconds_v2(dose);
 if code in ('front_plank_forearms','front_plank_high','side_plank') and not regions ? 'upper_body' then regions:=regions||'"upper_body"'::jsonb; end if;
 return jsonb_build_object('status','ready','policy_version','performance_v3','reference_id',reference->>'id','reference_kind',kind,
  'model',model,'phase',phase,'outcome',outcome,'reason',reason,'stimulus',block,'selection_reason',selection_reason,
  'name',coalesce(new_name,profile->>'name'),'comparison_dose',baseline,'dose',dose,'frequency',freq,
  'work_seconds',work_seconds,'work_minutes',ceil(work_seconds/60.0),'body_regions',regions,'movement_patterns',patterns,
  'running_leg_load',regions ? 'lower_body' and block_code not in ('COD-T01','COD-SP01'),
  'evidence',evidence,'review_due',bad>0 or (previous->>'phase' is not null and previous->>'phase'<>phase),
  'review_reason',case when bad>0 then 'La respuesta reciente requiere revisar recuperación y dosis. No añadir un test máximo.'
    when previous->>'phase' is not null and previous->>'phase'<>phase then 'Cambia el énfasis del programa: revisa la respuesta y si falta información relevante. No exige un test.' end,
  'review_policy','need_based_v1',
  'weeks_since_review',case when coalesce((previous->>'weeks_since_review')::int,0)>=3 then 0 else coalesce((previous->>'weeks_since_review')::int,0)+1 end,
  'parameter_status',cfg->>'parameter_status');
end $$;

create or replace function public.calculate_running_week_constrained(
 p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean,p_constraints jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 ctx public.running_intake_contexts%rowtype; ref record; age integer;
 revise boolean:=coalesce((p_constraints->>'revise_week')::boolean,false);
 excluded uuid[]:=array(select value::uuid from jsonb_array_elements_text(coalesce(p_constraints->'excluded_session_ids','[]')));
 last_sunday date:=current_date-extract(isodow from current_date)::integer;
 prev public.running_week_decisions%rowtype; existing public.running_week_decisions%rowtype;
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<last_sunday-6 or p_week_start>current_date+28 then
   raise exception 'Choose a current or upcoming complete week'; end if;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 if not p_replay_initial then
   select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
   if found and not revise then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
   select * into prev from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null order by week_start desc limit 1;
 end if;
 if prev.id is not null and current_date<p_week_start-1 and not p_preview_future then
   raise exception 'Close the previous week before adapting'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=p_goal_id;
 if not found or ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
   or (prev.id is null and ctx.recent_weeks_end_on<>last_sunday) then
   raise exception 'Update the current running context'; end if;
 if ctx.reports_pain or ctx.requires_professional_review then raise exception 'Health flag pauses the automatic proposal'; end if;
 select * into ref from jsonb_to_record(public.resolve_program_running_reference(p_goal_id))
   as x(reference_source text,reference_record_id text,continuity_confirmed_at timestamptz,completed_at timestamptz,value numeric,standard jsonb,controls jsonb);
 standard:=ref.standard; controls:=ref.controls;
 age:=current_date-ref.completed_at::date;
 if age<0 or ref.completed_at>now() then raise exception 'The selected 2 km mark is outside the reuse window'; end if;
 if age>30 and age<=45 and (ref.continuity_confirmed_at is null
   or ctx.recent_weeks_end_on<>last_sunday or 0=any(ctx.running_days_last_four_weeks)) then
   raise exception 'Confirm uninterrupted running before reuse'; end if;
 -- Fuera de ventana no se derivan ritmos. La semana fácil de mantenimiento
 -- solicita un control nuevo; no inventa una mejora ni perpetúa un ancla vieja.
 select coalesce(jsonb_agg(extract(isodow from public.workout_load_on_v1(scheduled_workouts))::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(excluded)
   and (not revise or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)))
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),'scheduled_date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',coalesce(public.workout_block_outcome_v1(e.id)->>'status',sw.status),'rpe',case when exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id)
   then (select max(r.actual_rpe) from public.workout_execution_sets r where r.execution_id=e.id and r.block_format='running') else e.final_rpe end,'abandonment_reason',public.workout_block_outcome_v1(e.id)->>'abandonment_reason',
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),e.id),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id and es.block_format='running') sets on true
 where sw.user_id=u and sw.status not in ('cancelled') and wd.policy_version in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56
   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(public.workout_load_on_v1(sw)-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(excluded)
   and (not revise or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and exists(select 1 from public.workout_blocks b
     where b.template_id=sw.template_id and b.format not in ('running','warm_up','cool_down')
       and exists(select 1 from public.workout_items wi join public.exercises ex on ex.id=wi.exercise_id
         left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
         where wi.block_id=b.id and (ep.code is null or ep.definition->'body_regions' ? 'lower_body')));
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5') then
   previous:=previous||jsonb_build_object('normal_budget',
     (select sum(planned_minutes) from public.running_week_sessions where decision_id=prev.id),
     'load_weeks',0,'rotation',0);
 end if;
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,'capacity_minutes',ctx.comfortable_continuous_minutes,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 -- El coordinador puede solicitar otra propuesta con el tiempo restante.
 -- La selección deportiva sigue en v5; la evidencia usa la realización real.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 result:=public.running_plan_v5(input);
 return result||jsonb_build_object('evidence_policy_version','adaptive_evidence_v1','goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

create or replace function public.calculate_preparation_week_for_scope(p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype; ctx public.performance_training_contexts%rowtype;
  existing public.preparation_week_decisions%rowtype; previous public.preparation_week_decisions%rowtype;
  ref record; history jsonb; prior jsonb; proposal jsonb; proposals jsonb:='[]'; pending jsonb:='[]';
  occupied jsonb; loads jsonb; candidate jsonb; best jsonb; running jsonb; best_running jsonb;
  started_on date; include_support boolean; frequency_limit int; candidates jsonb; expected_running jsonb; minimum_runs int:=1; expected_runs int:=0; actual_runs int:=0;
  shared_credit int; rotation int; score int; best_score int:=-2147483647; d int; session jsonb; blocked boolean; has_running boolean;
  running_cache jsonb:='{}'; running_constraints jsonb; cache_key text; running_error text; best_error text; coordinated jsonb; sessions jsonb:='[]'; required_missing boolean; selected_category text;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u and status='active';
 if not found then raise exception 'Preparación activa no disponible.' using errcode='42501'; end if;
 select * into existing from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
 if found and not p_revision then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<current_date-extract(isodow from current_date)::int+1
   or p_week_start>current_date+28 then raise exception 'Elige una semana actual o próxima.' using errcode='22023'; end if;
 select * into previous from public.preparation_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null order by week_start desc limit 1;
 select * into ctx from public.performance_training_contexts where user_id=u;
 if not found or ctx.observed_at<now()-interval '30 days' or not ctx.capacity_confirmed or ctx.reports_pain then
   return jsonb_build_object('status','needs_context','reason','Actualiza disponibilidad, material y capacidad actual antes de planificar.','sessions','[]'::jsonb); end if;
 if exists(select 1 from public.workout_executions e left join public.workout_execution_sets es on es.execution_id=e.id
   where e.user_id=u and coalesce(es.completed_at,e.completed_at,e.started_at)>ctx.observed_at
     and (e.abandonment_reason='discomfort' or es.performance_result->>'stop_reason'='discomfort' or es.performance_result->>'tolerated'='false')) then
   return jsonb_build_object('status','needs_context','reason','Has registrado molestias después de confirmar el contexto. Revisa tu situación actual antes de planificar.','sessions','[]'::jsonb); end if;
 if g.target_date<current_date then return jsonb_build_object('status','blocked','reason','Actualiza la fecha objetivo.','sessions','[]'::jsonb); end if;
 select coalesce(min(week_start),p_week_start) into started_on from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;
 for ref in select r.*,ep.definition from public.performance_training_references r
   join public.exercise_training_profiles ep on ep.code=r.reference->'task'->>'exercise_code'
     and ep.definition_version=(r.reference->'task'->>'exercise_version')::int
   where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and public.performance_reference_applies(g.id,r.test_id,r.objective_key) order by r.created_at desc loop
   select coalesce(jsonb_agg(jsonb_build_object('execution_id',e.id,'completed_on',public.workout_performed_on_v1(e),'scheduled_date',sw.scheduled_date,
     'status',public.workout_block_outcome_v1(e.id,pw.block_order)->>'status',
     'abandonment_reason',public.workout_block_outcome_v1(e.id,pw.block_order)->>'abandonment_reason','dose',pw.dose,'sets',sets.items) order by coalesce(e.performed_at,e.completed_at),e.id),'[]') into history
   from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
   join public.workout_executions e on e.id=sw.execution_id
   join lateral(select jsonb_agg(jsonb_build_object('status',es.status,'prescription',es.performance_prescription,
     'result',es.performance_result) order by es.set_order) items from public.workout_execution_sets es
     where es.execution_id=e.id and es.block_order=pw.block_order) sets on true
   where pw.reference_id=ref.id and public.workout_performed_on_v1(e)<p_week_start and public.workout_performed_on_v1(e)>=p_week_start-56;
   select value into prior from jsonb_array_elements(coalesce(previous.decision->'proposals','[]'))
     where value->>'reference_id'=ref.id::text or value->'covered_reference_ids' ? ref.id::text limit 1;
   if exists(select 1 from jsonb_array_elements_text(ref.definition->'required_equipment') eq
     where not eq=any(ctx.equipment)) then
     proposal:=jsonb_build_object('status','needs_equipment','reason','Falta material para esta variante; usa una alternativa calibrada compatible.');
   else proposal:=public.performance_task_v3(ref.reference,ref.definition,history,p_week_start,g.target_date,case when prior is null then '{}'::jsonb else prior||jsonb_build_object('reference_id',ref.id) end,started_on); end if;
   -- Cualquier molestia posterior al contexto pausa, aunque haya resultados buenos después.
   if exists(select 1 from jsonb_array_elements(history) h
     where (h->>'completed_on')::date>=ctx.observed_at::date and
       (h->>'abandonment_reason'='discomfort' or exists(select 1 from jsonb_array_elements(h->'sets') rs
         where rs->'result'->>'stop_reason'='discomfort' or rs->'result'->>'tolerated'='false'))) then
     proposal:=jsonb_build_object('status','blocked','reason','Actualiza el contexto después de las molestias registradas.'); end if;
   proposal:=proposal||jsonb_build_object('reference_id',ref.id,'objective_key',ref.objective_key,
     'name',coalesce(proposal->>'name',ref.definition->>'name'),'role',ref.reference->>'role','exercise_code',coalesce(proposal->'dose'->'task'->>'exercise_code',ref.definition->>'code'));
   proposals:=proposals||jsonb_build_array(proposal);
 end loop;

 proposals:=public.performance_select_v3(proposals);
 -- Seleccionar específico accesible; la regresión conserva visible la práctica
 -- específica pendiente. No pautar dos regresiones para el mismo objetivo.
 select coalesce(jsonb_agg(p),'[]') into proposals from jsonb_array_elements(proposals) p
 where p->>'role'<>'regression' or not exists(select 1 from jsonb_array_elements(proposals) q
   where q->>'objective_key'=p->>'objective_key' and q->>'status'='ready'
     and (q->>'role'='specific' or (q->>'role'='regression' and q->>'reference_id'<p->>'reference_id')));
 select coalesce(jsonb_agg(case when exists(select 1 from jsonb_array_elements(proposals) q
   where q->>'objective_key'=p->>'objective_key' and q->>'status'='ready' and q->>'role' in ('specific','regression'))
   then p||'{"role":"support"}'::jsonb else p end),'[]') into pending
   from jsonb_array_elements(proposals) p where p->>'status'<>'ready';
 -- Una misma tarea calibrada sirve a varios objetivos sin duplicar su volumen.
 select coalesce(jsonb_agg(x.proposal),'[]') into proposals from (
   select (jsonb_agg(p order by case when p->>'role'='specific' then 0 when p->>'role'='regression' then 1 else 2 end,p->>'reference_id')->0)
     ||jsonb_build_object('covered_reference_ids',jsonb_agg(p->'reference_id'),'frequency',max((p->>'frequency')::int)) proposal
   from jsonb_array_elements(proposals) p where p->>'status'='ready' group by p->'dose'
   union all select p from jsonb_array_elements(proposals) p where p->>'status'<>'ready'
 ) x;
 if p_scope<>'running' then
 select a.category into selected_category from public.program_assessment_attempts a where a.preparation_goal_id=p_goal_id order by a.assessed_on desc,a.created_at desc limit 1;
 if selected_category is null and exists(select 1 from public.program_assessment_tests where program_id=g.program_id and (category<>'both' or min_age<>0 or max_age<>120)) then
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_assessment','name','Categoría de las pruebas',
     'reason','Completa la evaluación de esta preparación para identificar las pruebas que te corresponden.')); end if;
 for ref in select b.test_id,t.name from public.program_test_training_bindings b
   join public.program_assessment_tests t on t.id=b.test_id
   where b.program_id=g.program_id and public.performance_test_applies(g.id,t.id) and (t.category='both' or t.category=selected_category)
     and not exists(select 1 from public.performance_training_references r where p_scope<>'running' and r.preparation_goal_id=p_goal_id and r.active and r.test_id=b.test_id) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_calibration','objective_key',ref.test_id,
     'name',ref.name,'reason','Esta prueba del programa aún no tiene referencia de trabajo.'));
 end loop;
 for ref in select o.* from public.performance_legacy_objectives o where o.program_id=g.program_id
   and (o.max_age_exclusive is null or coalesce((select extract(year from age(coalesce(g.target_date,current_date),fecha_nacimiento)) from public.profiles where id=u),0)<o.max_age_exclusive)
   and not exists(select 1 from public.performance_training_references r where r.preparation_goal_id=g.id and r.active and r.objective_key=o.objective_key) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_calibration','name',ref.name,'objective_key',ref.objective_key,'reason','Falta la referencia de trabajo de esta prueba del programa.'));
 end loop;
 for ref in select t.name from public.program_assessment_tests t where t.program_id=g.program_id and public.performance_test_applies(g.id,t.id)
   and t.category in ('both',selected_category)
   and not exists(select 1 from public.program_test_training_bindings b where b.test_id=t.id)
   and not exists(select 1 from public.program_training_modules m where m.test_id=t.id) loop
   pending:=pending||jsonb_build_array(jsonb_build_object('status','needs_strategy','name',ref.name,'reason','ADMIN debe configurar una estrategia compatible para esta prueba.'));
 end loop;
 end if;
 select coalesce(jsonb_agg(extract(isodow from public.workout_load_on_v1(scheduled_workouts))::int),'[]') into occupied
   from public.scheduled_workouts where user_id=u and public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6 and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(p_excluded)
   and (not p_revision or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)));
 select coalesce(jsonb_agg(jsonb_build_object('day',public.workout_load_on_v1(sw)-p_week_start+1,
   'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'))),'[]') into loads
   from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
   join public.workout_items wi on wi.block_id=b.id join public.exercises ex on ex.id=wi.exercise_id
   left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
   where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
     and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and b.format not in ('warm_up','cool_down','running');
 -- También protege calidad de carrera ya publicada, que no se recalcula.
 select loads||coalesce(jsonb_agg(jsonb_build_object('day',public.workout_load_on_v1(sw)-p_week_start+1,'body_regions','["lower_body"]'::jsonb)),'[]') into loads
 from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
 where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(p_excluded)
     and (not p_revision or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and coalesce(rs.prescription->>'family','legacy')<>'E';
 has_running:=p_scope<>'performance' and (exists(select 1 from public.running_intake_contexts where preparation_goal_id=p_goal_id)
   or exists(select 1 from public.program_training_modules where program_id=g.program_id)
   or g.program_id in ('fas_periodic_assessment','armed_forces_troop_entry'));
 -- Cubrir cada objetivo antes de añadir apoyos o una segunda exposición.
 select coalesce(jsonb_agg(p||jsonb_build_object('required_for_objective',not exists(
  select 1 from jsonb_array_elements(proposals) q where q->>'status'='ready' and q->>'objective_key'=p->>'objective_key'
   and (case q->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,
        coalesce((q->>'selection_rank')::int,1),q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,coalesce((p->>'selection_rank')::int,1),p->>'reference_id')))),'[]') into proposals
 from jsonb_array_elements(proposals) p;
 if has_running then
  begin
   expected_running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,
    jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),'availability',ctx.availability,'strength_days','[]'::jsonb,'leg_load_days','[]'::jsonb));
   expected_runs:=jsonb_array_length(coalesce(expected_running->'sessions','[]')); minimum_runs:=least(2,greatest(1,expected_runs));
  exception when others then expected_running:=null; end;
 end if;
 for include_support in select unnest(array[true,false]) loop
 for frequency_limit in reverse 2..0 loop
 select coalesce(jsonb_agg((case when frequency_limit=0 then public.performance_compact_proposal_v2(p) else p end)||jsonb_build_object('requested_frequency',p->'frequency','frequency',least(greatest(1,frequency_limit),(p->>'frequency')::int))),'[]') into candidates from jsonb_array_elements(proposals) p where include_support or p->>'optional' is distinct from 'true';
 for rotation in 0..6 loop
   candidate:=public.performance_place_v3(candidates,ctx.availability,occupied,loads,rotation,p_week_start,g.target_date);
   -- Ensayar reservas sin ahorro, con activación compartida y con cierre.
   -- Cada alternativa pasa el coste exacto antes de puntuar.
   for shared_credit in select unnest(array[0,4,7]) loop
   running:=null; running_error:=null;
   if has_running then
     begin
       running_constraints:=jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),
         'availability',public.preparation_running_budget_v1(candidate,ctx.availability,shared_credit),'strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days');
       cache_key:=running_constraints::text;
       -- Las alternativas repetidas no vuelven a leer y evaluar el historial.
       -- Caché local a esta llamada; el coste conjunto se valida siempre abajo.
       if running_cache ? cache_key then running:=running_cache->cache_key;
       else
        running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,running_constraints);
        running_cache:=running_cache||jsonb_build_object(cache_key,running);
       end if;
     if jsonb_array_length(coalesce(running->'sessions','[]'))=0 then
         running_error:='No cabe una sesión de carrera compatible. Revisa disponibilidad y referencias.'; running:=null;
       elsif exists(select 1 from jsonb_array_elements(running->'sessions') rs where
         (case when coalesce((candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text->>'minutes')::int,0)>0
           then public.preparation_shared_minutes_v2(candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text,rs)
           else (rs->>'minutes')::int end)>coalesce((ctx.availability->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)) then
         running_error:='La carrera ya publicada supera la disponibilidad actual. Revisa la agenda antes de añadir fuerza.'; running:=null;
       end if;
     exception when others then
       running_error:=case
         when sqlerrm like '%current running context%' then 'Actualiza el cuestionario de carrera y sus cuatro semanas recientes.'
         when sqlerrm like '%Health flag%' then 'Has indicado molestias en carrera. Actualiza tu situación antes de planificar.'
         when sqlerrm like '%compatible 2 km mark%' or sqlerrm like '%reuse window%' then 'Elige una marca vigente de 2 km para esta preparación.'
         when sqlerrm like '%Confirm uninterrupted%' then 'Confirma la continuidad de carrera para reutilizar esta marca.'
         when sqlerrm like '%standard or margin%' then 'Falta un mínimo oficial aplicable; elige una meta concreta o mejorar sin cifra.'
         else 'No se ha podido proponer carrera. Revisa la referencia, el cuestionario y los días disponibles.' end;
     end;
   end if;
   score:=(candidate->>'score')::int;
   -- Cobertura antes que minutos: evita premiar accesorios por desplazar carrera.
   score:=score - 10000*(select count(*) from jsonb_array_elements(candidate->'missing') q where q->>'required_for_objective'='true' and (q->>'scheduled')::int=0);
   if running is not null then score:=score+1000+300*jsonb_array_length(running->'sessions')
     +100*(select count(*) from jsonb_array_elements(running->'sessions') q where q->>'kind'<>'easy'); end if;
   if frequency_limit=0 then score:=score-50; end if;
   if has_running and jsonb_array_length(coalesce(running->'sessions','[]'))<minimum_runs then score:=score-10000; end if;
   if score>best_score then best:=candidate; best_running:=running; best_score:=score; best_error:=running_error; end if;
 end loop;
 end loop;
 end loop;
 end loop;
 -- El trabajo descartado no consume el permiso de progresar de lo publicado.
 select coalesce(jsonb_agg(w),'[]') into coordinated from (select distinct w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w) chosen;
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
 select coordinated||coalesce(jsonb_agg(p||jsonb_build_object('allocation_status','not_scheduled','allocation_reason','Se conserva la referencia, pero esta semana tiene prioridad la cobertura específica, carrera y recuperación.')),'[]') into coordinated from jsonb_array_elements(proposals) p
 where not exists(select 1 from jsonb_array_elements(coordinated) c where c->>'reference_id'=p->>'reference_id');
 -- Mantener una dosis solo reduce el coste ya reservado; nunca rellena ese margen.
 for d in 1..7 loop
   select coalesce(jsonb_agg(c order by w.ordinality),'[]') into session from jsonb_array_elements(best->'days'->d::text->'work') with ordinality w(value,ordinality)
     join lateral(select value c from jsonb_array_elements(coordinated) c where c->>'reference_id'=w.value->>'reference_id') q on true;
   best:=jsonb_set(best,array['days',d::text,'work'],session);
 end loop;
 proposals:=coordinated;
 pending:=pending||coalesce(best->'missing','[]');
 if best_error is not null then pending:=pending||jsonb_build_array(jsonb_build_object('status','running_pending','name','Carrera','reason',best_error)); end if;
 for d in 1..7 loop
   session:=best->'days'->d::text;
   if (session->>'minutes')::int>0 then sessions:=sessions||jsonb_build_array(session||jsonb_build_object(
     'date',p_week_start+d-1,'kind','performance','name','Fuerza y rendimiento','session_order',case when exists(select 1 from jsonb_array_elements(session->'work') w where w->>'model' in ('power','course','reactive_agility','rope')) then 'performance_first' else 'running_first' end,'warm_up_seconds',420,'cool_down_seconds',180,'warm_up_instructions',public.performance_warm_up_instructions_v1(session),'warm_up_protocol_version','warm_up_v1_1')); end if;
 end loop;
 sessions:=public.performance_controls_v3(sessions,coalesce(previous.decision,'{}'));
 -- Una misma sesión física comparte preparación general y vuelta a la calma.
 select coalesce(jsonb_agg(case when r.item is null then f else f||jsonb_build_object(
   'combined',true,'standalone_minutes',f->'minutes',
   'minutes',public.preparation_shared_minutes_v2(f,r.item)-(r.item->>'minutes')::int,
   'shared_total_minutes',public.preparation_shared_minutes_v2(f,r.item),
   'warm_up_instructions',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup')
    then 'La activación general se comparte con carrera. Después: 1:00 de movilidad de las articulaciones que usarás y 2:00 de ensayo fácil de los movimientos pautados. Sin máximos.' else f->>'warm_up_instructions' end,
   'warm_up_seconds',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup') then 180 else 420 end
 ) end),'[]') into sessions from jsonb_array_elements(sessions) f
 left join lateral(select value item from jsonb_array_elements(coalesce(best_running->'sessions','[]')) q where q->>'date'=f->>'date') r on true;
 -- Un apoyo puede ser la única entrada de un objetivo; no debe desaparecer sin aviso.
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
 required_missing:=(has_running and actual_runs<minimum_runs) or (jsonb_array_length(sessions)=0 and best_running is null) or exists(select 1 from jsonb_array_elements(pending) p
   where coalesce(p->>'role','specific')<>'support' and coalesce((p->>'scheduled')::int,0)=0);
 return jsonb_build_object('status',case when required_missing then 'needs_attention' else 'ready' end,
   'policy_version','preparation_coordinator_v3','evidence_policy_version','adaptive_evidence_v1','training_scope',p_scope,'week_start',p_week_start,'goal_id',p_goal_id,
   'reason','Semana coordinada según objetivos, referencias, respuesta y disponibilidad total.',
   'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,'running',best_running,'pending',pending,
   'coverage',jsonb_build_object('running_expected',expected_runs,'running_scheduled',actual_runs,'minimum_running_sessions',minimum_runs),'context_observed_at',ctx.observed_at,'availability',ctx.availability,
   'already_published',false);
end $$;

commit;
