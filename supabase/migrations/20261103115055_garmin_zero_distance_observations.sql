begin;

-- Cero medido no es distancia ausente. Una grabación sin desplazamiento se
-- conserva; el dominio exige revisión antes de completar automáticamente.
alter table device_private.activity_observations drop constraint activity_observation_sport_shape;
alter table device_private.activity_observations add constraint activity_observation_sport_shape check ((
 (observation->>'schemaVersion'='1' and observation->>'sport' is null and jsonb_typeof(observation->'laps')='array'
  and jsonb_array_length(observation->'laps')<=2000 and (observation->>'distanceMeters')::numeric between 0 and 1000000
  and not observation?'sets') or
 (observation->>'schemaVersion'='2' and observation->>'sport'='strength' and observation->'distanceMeters'='null'::jsonb
  and jsonb_typeof(observation->'sets')='array' and jsonb_array_length(observation->'sets') between 1 and 2000
  and not observation?'laps')) is true);

alter table public.workout_executions drop constraint workout_observed_totals;
alter table public.workout_executions add constraint workout_observed_totals check (
 (observed_timer_seconds is null and observed_elapsed_seconds is null and observed_distance_meters is null) or
 (observed_timer_seconds>0 and observed_timer_seconds<=172800 and observed_timer_seconds is not null
  and observed_elapsed_seconds is not null and observed_elapsed_seconds>=observed_timer_seconds and observed_elapsed_seconds<=172800
  and (observed_distance_meters is null or observed_distance_meters between 0 and 1000000)));

commit;
