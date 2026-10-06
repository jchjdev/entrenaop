-- Precisión de ventana, éxito booleano y métricas de salto instrumentadas.
begin;
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
  if p->>'load_mode' in ('external_load','bodyweight_plus_external') and coalesce((p->>'external_load_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'load_mode' = 'bodyweight_plus_external' and coalesce((p->>'body_mass_kg')::numeric,0) <= 0 then return false; end if;
  if p->>'target_rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (p->>'target_rir')::numeric > 10) then return false; end if;
  return true;
exception when others then return false;
end $$;

create or replace function public.valid_performance_result(r jsonb, p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; m text := p->>'measurement'; v numeric;
begin
  if r is null then return true; end if;
  if p is null or jsonb_typeof(r) <> 'object' then return false; end if;
  if exists(select 1 from jsonb_object_keys(r) x where x <> all(array[
    'value','technique_valid','conditions_confirmed','tolerated','rir','load_kg',
    'body_mass_kg','penalty_seconds','correct_responses','total_responses','stop_reason','succeeded','actual_duration_seconds','jump_height_meters','measurement_method'])) then return false; end if;
  foreach k in array array['value','rir','load_kg','body_mass_kg','penalty_seconds','correct_responses','total_responses','actual_duration_seconds','jump_height_meters'] loop
    if r->>k is not null and (jsonb_typeof(r->k) <> 'number'
      or (r->>k)::numeric < 0 or (r->>k)::numeric > 1000000) then return false; end if;
  end loop;
  foreach k in array array['technique_valid','conditions_confirmed','tolerated','succeeded'] loop
    if r->>k is not null and jsonb_typeof(r->k) <> 'boolean' then return false; end if;
  end loop;
  v := (r->>'value')::numeric;
  if m in ('REPS','LOAD_REPS','REPS_IN_TIME','PASS_FAIL') and v <> trunc(v) then return false; end if;
  if m = 'PASS_FAIL' and v is not null then return false; end if;
  if r->>'rir' is not null and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')
      or p->>'intent' <> 'work' or (r->>'rir')::numeric > 10) then return false; end if;
  if r->>'body_mass_kg' is not null and (r->>'body_mass_kg')::numeric <= 0 then return false; end if;
  if r->>'penalty_seconds' is not null and m <> 'TIME_FOR_COURSE' then return false; end if;
  if r->>'correct_responses' is not null or r->>'total_responses' is not null then
    if m not in ('TIME_FOR_COURSE','PASS_FAIL') or r->>'correct_responses' is null or r->>'total_responses' is null then return false; end if;
    if (r->>'total_responses')::numeric < 1
      or (r->>'correct_responses')::numeric > (r->>'total_responses')::numeric
      or (r->>'correct_responses')::numeric <> trunc((r->>'correct_responses')::numeric)
      or (r->>'total_responses')::numeric <> trunc((r->>'total_responses')::numeric) then return false; end if;
  end if;
  if r->>'succeeded' is not null and m <> 'PASS_FAIL' then return false; end if;
  if r->>'actual_duration_seconds' is not null and m <> 'REPS_IN_TIME' then return false; end if;
  if r->>'jump_height_meters' is not null and m <> 'REACTIVE_METRICS' then return false; end if;
  if m = 'REACTIVE_METRICS' and (v is not null or r->>'jump_height_meters' is not null)
    and (jsonb_typeof(r->'measurement_method') is distinct from 'string'
      or length(btrim(coalesce(r->>'measurement_method',''))) not between 3 and 200) then return false; end if;
  return coalesce(r->>'stop_reason','unknown') in ('none','time','difficulty','discomfort','unknown');
exception when others then return false;
end $$;


commit;

