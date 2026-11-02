begin;

-- El único motor que crea snapshots valida Pro después de comprobar acceso y
-- devolver una ejecución abierta. Conservarla permite finalizar lo ya iniciado;
-- cualquier inicio posterior, incluida una plantilla directa, exige Pro actual.
-- Se modifica la función existente sin crear una variante interna sin guarda.
do $migration$
declare
  definition text;
  anchor text := '  insert into public.workout_executions (';
begin
  definition := pg_get_functiondef('trainer_private.start_workout_execution(uuid)'::regprocedure);
  if strpos(definition, anchor) = 0
    or strpos(substr(definition, strpos(definition, anchor) + length(anchor)), anchor) > 0 then
    raise exception 'Revisar el punto único de creación de ejecuciones.';
  end if;
  definition := replace(definition, anchor,
    E'  if exists (select 1 from public.workout_templates t\n'
    || E'    where t.id = p_template_id and t.origin = ''algorithm'') then\n'
    || E'    perform public.require_pro_access();\n'
    || E'  end if;\n\n' || anchor);
  execute definition;
end
$migration$;

-- El permiso comercial no participa en la revisión de la prescripción: retirar
-- Pro obliga a contratar para empezar otra sesión, no a releer una dosis falsa.
do $migration$
declare
  definition text;
  anchor text := '  return payload || jsonb_build_object(';
begin
  definition := pg_get_functiondef('trainer_private.get_scheduled_workout_preview(uuid,uuid)'::regprocedure);
  if strpos(definition, anchor) = 0 then
    raise exception 'Revisar el contrato de consulta de la pauta.';
  end if;
  definition := replace(definition, anchor,
    E'  return jsonb_build_object(''pro_required'',\n'
    || E'    template.origin = ''algorithm'' and scheduled.status in (''planned'', ''in_progress'')\n'
    || E'    and not public.has_pro_access(p_expected_owner)\n'
    || E'    and not exists (select 1 from public.workout_executions e\n'
    || E'      where e.user_id = p_expected_owner and e.template_id = template.id\n'
    || E'        and e.status = ''in_progress'')) || payload || jsonb_build_object(');
  execute definition;
end
$migration$;

-- La pausa voluntaria y la intención automática se conservan en program_state;
-- la presentación recibe el permiso efectivo por separado, sin escribir estado.
do $migration$
declare definition text; anchor text := ' return setup;';
begin
  definition := pg_get_functiondef('public.get_preparation_training_setup(uuid)'::regprocedure);
  if strpos(definition, anchor) = 0 then
    raise exception 'Revisar el contrato de lectura de la preparación.';
  end if;
  definition := replace(definition, anchor,
    ' return setup || jsonb_build_object(''pro_required'', not public.has_pro_access(auth.uid()));');
  execute definition;
end
$migration$;

do $migration$
declare definition text; anchor text := 'result := public.refresh_adaptive_programs_pro_base();';
begin
  definition := pg_get_functiondef('public.refresh_adaptive_programs()'::regprocedure);
  if strpos(definition, anchor) = 0 then
    raise exception 'Revisar el contrato de resumen adaptativo.';
  end if;
  definition := replace(definition, anchor, anchor || E'\n'
    || E'  select coalesce(jsonb_agg(item || jsonb_build_object(''pro_required'',\n'
    || E'    not public.has_pro_access(auth.uid())) order by position), ''[]''::jsonb)\n'
    || E'    into result from jsonb_array_elements(result) with ordinality items(item, position);');
  execute definition;
end
$migration$;

-- Las funciones internas conservan sus ACL: ningún cliente obtiene una puerta
-- directa al motor o a require_pro_access mediante esta migración.
revoke all on function trainer_private.start_workout_execution(uuid),
  public.require_pro_access() from public, anon, authenticated;

commit;
