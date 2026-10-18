begin;

-- VID-002: margen para demostraciones que necesiten entre ocho y diez segundos.
-- Se amplía con otra migración para conservar el historial ya aplicado.
alter table public.exercise_video_assets
  drop constraint exercise_video_assets_duration_seconds_check;
alter table public.exercise_video_assets
  add constraint exercise_video_assets_duration_seconds_check
  check (duration_seconds > 0 and duration_seconds <= 10);

commit;
