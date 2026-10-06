-- La instantánea de tarea y el resultado explícito viajan juntos, sin convertir
-- cronometrajes, saltos o isometrías en repeticiones ni resultados de carrera.
begin;

create function public.valid_performance_prescription(p jsonb)
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
    'external_load_kg','body_mass_kg','target_rir','instructions'])) then return false; end if;
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
  if p->>'load_mode' <> 'bodyweight' and coalesce((p->>'external_load_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'load_mode' = 'bodyweight_plus_external' and coalesce((p->>'body_mass_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'target_rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (p->>'target_rir')::numeric > 10) then return false; end if;
  return true;
exception when others then return false;
end $$;

create function public.valid_performance_result(r jsonb, p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; m text := p->>'measurement'; v numeric;
begin
  if r is null then return true; end if;
  if p is null or jsonb_typeof(r) <> 'object' then return false; end if;
  if exists(select 1 from jsonb_object_keys(r) x where x <> all(array[
    'value','technique_valid','conditions_confirmed','tolerated','rir','load_kg',
    'body_mass_kg','penalty_seconds','correct_responses','total_responses','stop_reason'])) then return false; end if;
  foreach k in array array['value','rir','load_kg','body_mass_kg','penalty_seconds','correct_responses','total_responses'] loop
    if r->>k is not null and (jsonb_typeof(r->k) <> 'number'
      or (r->>k)::numeric < 0 or (r->>k)::numeric > 1000000) then return false; end if;
  end loop;
  foreach k in array array['technique_valid','conditions_confirmed','tolerated'] loop
    if r->>k is not null and jsonb_typeof(r->k) <> 'boolean' then return false; end if;
  end loop;
  v := (r->>'value')::numeric;
  if m in ('REPS','LOAD_REPS','REPS_IN_TIME','PASS_FAIL') and v <> trunc(v) then return false; end if;
  if m = 'PASS_FAIL' and v not in (0,1) then return false; end if;
  if r->>'rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (r->>'rir')::numeric > 10) then return false; end if;
  if r->>'body_mass_kg' is not null and (r->>'body_mass_kg')::numeric <= 0 then return false; end if;
  if r->>'penalty_seconds' is not null and m <> 'TIME_FOR_COURSE' then return false; end if;
  if r->>'correct_responses' is not null or r->>'total_responses' is not null then
    if m <> 'REACTIVE_METRICS' or r->>'correct_responses' is null or r->>'total_responses' is null then return false; end if;
    if (r->>'total_responses')::numeric < 1
      or (r->>'correct_responses')::numeric > (r->>'total_responses')::numeric
      or (r->>'correct_responses')::numeric <> trunc((r->>'correct_responses')::numeric)
      or (r->>'total_responses')::numeric <> trunc((r->>'total_responses')::numeric) then return false; end if;
  end if;
  return coalesce(r->>'stop_reason','unknown') in ('none','time','difficulty','discomfort','unknown');
exception when others then return false;
end $$;

alter table public.workout_sets add column performance_prescription jsonb,
  add constraint workout_sets_performance_valid check(public.valid_performance_prescription(performance_prescription));
alter table public.workout_sets drop constraint workout_sets_has_target;
alter table public.workout_sets add constraint workout_sets_has_target check (
  target_reps is not null or target_duration_seconds is not null
  or target_distance_meters is not null or performance_prescription is not null);
alter table public.workout_execution_sets add column performance_prescription jsonb,
  add column performance_result jsonb,
  add constraint execution_performance_prescription_valid check(public.valid_performance_prescription(performance_prescription)),
  add constraint execution_performance_result_valid check(public.valid_performance_result(performance_result,performance_prescription)),
  add constraint execution_performance_completed check(performance_prescription is null or status <> 'completed' or performance_result is not null);

create function public.snapshot_performance_set() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    select s.performance_prescription into new.performance_prescription
      from public.workout_sets s where s.id = new.source_set_id;
  elsif new.performance_prescription is distinct from old.performance_prescription then
    raise exception 'La tarea de una ejecución es inmutable.';
  end if;
  if tg_op = 'UPDATE' and new.performance_prescription is not null
    and new.performance_result is not distinct from old.performance_result
    and (new.actual_reps,new.actual_duration_seconds,new.actual_distance_meters,new.actual_load_kg,new.actual_rir)
      is distinct from (old.actual_reps,old.actual_duration_seconds,old.actual_distance_meters,old.actual_load_kg,old.actual_rir) then
    raise exception 'Usa el registro deportivo para corregir esta tarea.';
  end if;
  if new.performance_prescription is not null then
    -- Proyección para las vistas antiguas; el decimal exacto permanece en JSON.
    new.actual_reps := case when new.performance_prescription->>'measurement'
      in ('REPS','LOAD_REPS','REPS_IN_TIME') then (new.performance_result->>'value')::integer end;
    new.actual_duration_seconds := case when new.performance_prescription->>'measurement'
      in ('DURATION','TIME_FOR_DISTANCE','TIME_FOR_COURSE','REACTIVE_METRICS')
      then floor((new.performance_result->>'value')::numeric)::integer end;
    new.actual_distance_meters := case when new.performance_prescription->>'measurement'
      in ('DISTANCE','HEIGHT') then (new.performance_result->>'value')::numeric end;
    new.actual_load_kg := case when new.performance_prescription->>'measurement' = 'MAX_LOAD'
      then (new.performance_result->>'value')::numeric else (new.performance_result->>'load_kg')::numeric end;
    new.actual_rir := (new.performance_result->>'rir')::numeric;
  end if;
  return new;
end $$;
create trigger snapshot_performance_set before insert or update
on public.workout_execution_sets for each row execute function public.snapshot_performance_set();

create function public.complete_performance_set_idempotent(
  p_operation_id uuid, p_result_id uuid, p_performance_result jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare s public.workout_execution_sets%rowtype;
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  -- Serializar por resultado impide que dos pestañas apliquen el mismo registro.
  select x.* into s from public.workout_execution_sets x join public.workout_executions e on e.id=x.execution_id
    where x.id=p_result_id and e.user_id=auth.uid() for update of x,e;
  if not found then raise exception 'Serie no disponible.' using errcode='42501'; end if;
  if exists(select 1 from public.workout_mutation_receipts where id=p_operation_id
    and user_id=auth.uid() and resource_id=p_result_id and mutation_kind='complete_set') then return; end if;
  if s.status <> 'pending' or s.performance_prescription is null or p_performance_result is null
    or not exists(select 1 from public.workout_executions where id=s.execution_id and status='in_progress') then
    raise exception 'La serie no admite este registro.' using errcode='22023'; end if;
  update public.workout_execution_sets set performance_result=p_performance_result,
    status='completed',completed_at=now(),result_source='manual' where id=p_result_id;
  insert into public.workout_mutation_receipts(id,user_id,mutation_kind,resource_id)
    values(p_operation_id,auth.uid(),'complete_set',p_result_id);
end $$;

create function public.correct_performance_set_result(
  p_result_id uuid,p_reason text,p_performance_result jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare s public.workout_execution_sets%rowtype;
begin
  select x.* into s from public.workout_execution_sets x join public.workout_executions e on e.id=x.execution_id
    where x.id=p_result_id and e.user_id=auth.uid() for update of x;
  if not found or s.status <> 'completed' or s.performance_prescription is null then
    raise exception 'Resultado no disponible.' using errcode='42501'; end if;
  if s.completed_at < now()-interval '24 hours'
    or (select count(*) from public.workout_set_corrections where execution_set_id=p_result_id) >= 3 then
    raise exception 'Se ha agotado el plazo o el límite de correcciones.' using errcode='22023'; end if;
  if length(btrim(coalesce(p_reason,''))) not between 3 and 300 or p_performance_result is null then
    raise exception 'Explica la corrección e introduce el resultado.' using errcode='22023'; end if;
  insert into public.workout_set_corrections(execution_set_id,user_id,reason,previous_result,corrected_result)
    values(p_result_id,auth.uid(),btrim(p_reason),jsonb_build_object('performance_result',s.performance_result),
      jsonb_build_object('performance_result',p_performance_result));
  update public.workout_execution_sets set performance_result=p_performance_result where id=p_result_id;
end $$;

revoke all on function public.complete_performance_set_idempotent(uuid,uuid,jsonb),
  public.correct_performance_set_result(uuid,text,jsonb) from public,anon;
grant execute on function public.complete_performance_set_idempotent(uuid,uuid,jsonb),
  public.correct_performance_set_result(uuid,text,jsonb) to authenticated;
commit;
