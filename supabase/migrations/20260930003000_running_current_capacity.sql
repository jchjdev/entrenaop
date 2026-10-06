-- Capacidad fácil declarada, separada de la carga de las últimas cuatro semanas.
-- Las filas v1 conservan NULL: desconocido no equivale a cero.
begin;

alter table public.running_intake_contexts
  add column comfortable_continuous_minutes integer,
  add constraint running_intake_comfortable_minutes_check
    check (comfortable_continuous_minutes between 0 and 180);

alter table public.running_intake_contexts
  drop constraint running_intake_context_version_check;

alter table public.running_intake_contexts
  add constraint running_intake_context_version_check check (
    context_version = 'running_initial_context_v1'
    or (context_version = 'running_initial_context_v2'
        and comfortable_continuous_minutes is not null)
  );

commit;
