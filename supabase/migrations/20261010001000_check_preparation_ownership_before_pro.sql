-- Mantener el contrato de propiedad: Pro no autoriza preparaciones ajenas.
begin;
create function public.require_preparation_pro_access(p_goal_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.preparation_goals
    where id = p_goal_id and user_id = auth.uid() and status = 'active') then
    raise exception 'Preparación no disponible.' using errcode = '42501';
  end if;
  perform public.require_pro_access();
end $$;
revoke all on function public.require_preparation_pro_access(uuid) from public, anon, authenticated;

do $migration$
declare signature text; function_oid regprocedure; function_name text;
  arguments text; result_type text; call_arguments text;
begin
  foreach signature in array array[
    'calculate_preparation_week(uuid,date)', 'preview_preparation_week_revision(uuid,date)',
    'preview_adaptive_program_activation(uuid,date)', 'activate_adaptive_program(uuid,date,jsonb)',
    'publish_preparation_week(uuid,date,jsonb)', 'publish_preparation_week_revision(uuid,date,jsonb)',
    'calculate_running_week(uuid,date)', 'preview_running_initial_week(uuid,date)',
    'preview_running_next_week(uuid)', 'publish_running_week(uuid,date)',
    'calculate_fas_running_week(uuid,date)', 'preview_fas_running_initial_week(uuid,date)',
    'preview_fas_running_next_week(uuid)', 'publish_fas_running_week(uuid,date)'
  ] loop
    function_oid := ('public.' || signature)::regprocedure;
    select proname, pg_get_function_arguments(function_oid), pg_get_function_result(function_oid),
      (select string_agg(quote_ident(name), ', ' order by ord)
        from unnest(proargnames) with ordinality names(name, ord))
      into function_name, arguments, result_type, call_arguments from pg_proc where pg_proc.oid = function_oid;
    execute format('create or replace function public.%I(%s) returns %s language plpgsql security definer set search_path = '''' as $body$ begin perform public.require_preparation_pro_access(p_goal_id); return public.%I(%s); end $body$',
      function_name, arguments, result_type, function_name || '_pro_base', call_arguments);
  end loop;
end $migration$;
commit;
