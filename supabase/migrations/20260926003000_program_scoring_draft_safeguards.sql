-- Un borrador puede corregir tramos sin tocar pruebas ya publicadas.
begin;

revoke execute on function public.create_admin_program_assessment_test(
  text,text,text,text,text,text) from authenticated;

create function public.validate_program_scoring_rule_update()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.aggregation = 'average' and
      new.min_aggregate_points > new.max_points then
    raise exception 'La media mínima supera el máximo por prueba.'
      using errcode = '22023';
  end if;
  if exists (select 1 from public.program_assessment_score_bands b
    join public.program_assessment_tests t on t.id = b.test_id
    where t.program_id = new.program_id and b.points > new.max_points) then
    raise exception 'El máximo nuevo es menor que un tramo existente.'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger validate_program_scoring_rule_before_write
before insert or update on public.program_assessment_scoring_rules
for each row execute function public.validate_program_scoring_rule_update();

create function public.delete_admin_program_score_band(p_band_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para corregir baremos.'
      using errcode = '42501';
  end if;
  delete from public.program_assessment_score_bands b
  using public.program_assessment_tests t,
        public.preparation_programs p
  where b.id = p_band_id and t.id = b.test_id
    and p.id = t.program_id and not p.enabled;
  if not found then
    raise exception 'Tramo no disponible en un borrador.'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.delete_admin_program_score_band(uuid)
from public, anon;
grant execute on function public.delete_admin_program_score_band(uuid)
to authenticated;

commit;
