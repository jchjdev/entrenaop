begin;

-- También protege cambios de medición si una llamada omite la confirmación
-- o envía NULL en el parámetro opcional del RPC.
create function public.guard_assessment_test_measurement_update()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if (old.unit, old.better_direction, old.category, old.mark_step)
      is distinct from
     (new.unit, new.better_direction, new.category, new.mark_step)
     and exists (select 1 from public.program_assessment_score_bands b
       where b.test_id = old.id) then
    raise exception 'Primero borra los tramos incompatibles.'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger guard_assessment_test_measurement_before_update
before update of unit, better_direction, category, mark_step
on public.program_assessment_tests
for each row execute function public.guard_assessment_test_measurement_update();

commit;
