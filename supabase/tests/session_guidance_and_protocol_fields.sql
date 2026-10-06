-- Capacidades explícitas del protocolo. Sin datos persistentes.
begin;
do $$
declare p jsonb := '{"schema_version":1,"exercise_code":"reactive_direction_drill","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"fixture","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","policy_version":"performance_v1_1","target_value":13.25,"intent":"practice"}';
  instructions text;
begin
  if not public.valid_performance_prescription(p)
    or not public.valid_performance_prescription(p||'{"records_stimulus_responses":true,"records_penalty_seconds":false}') then
    raise exception 'Rechaza un protocolo antiguo o sus capacidades explícitas'; end if;
  if public.valid_performance_prescription(p||'{"records_stimulus_responses":"true"}')
    or public.valid_performance_prescription(p||'{"measurement":"DURATION","records_stimulus_responses":true}')
    or public.valid_performance_prescription(p||'{"measurement":"DURATION","records_penalty_seconds":true}') then
    raise exception 'Acepta capacidades incompatibles'; end if;
  instructions:=public.performance_warm_up_instructions_v1('{"work":[{"name":"Flexiones","model":"repetitions","movement_patterns":["horizontal_push"]},{"name":"Plancha","model":"isometric","movement_patterns":["core_anti_extension"]},{"name":"Circuito","model":"course","movement_patterns":["change_of_direction"]}]}');
  if instructions not like '%Hombros, codos y muñecas%' or instructions not like '%Tobillos, rodillas y caderas%'
    or instructions not like '%sujeción breve%' or instructions not like '%giros y la frenada%'
    or instructions not like '%no una obligación ni garantía%' then
    raise exception 'El calentamiento no concreta el trabajo pautado'; end if;
  if has_function_privilege('authenticated','public.performance_warm_up_instructions_v1(jsonb)','execute')
    or has_function_privilege('anon','public.snapshot_workout_item_instructions()','execute') then
    raise exception 'Expone funciones internas'; end if;
end $$;
select 'Capacidades compatibles y calentamiento pertinente: OK' as result;
rollback;
