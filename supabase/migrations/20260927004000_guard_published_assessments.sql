-- Un baremo publicado no cambia después de registrar evaluaciones.
begin;

create function public.guard_published_program_assessment_content()
returns trigger language plpgsql set search_path = ''
as $$
declare
  v_old_program text;
  v_new_program text;
  v_program text;
  v_enabled boolean;
begin
  if tg_table_name in ('program_assessment_scoring_rules','program_assessment_tests') then
    if tg_op <> 'INSERT' then v_old_program := old.program_id; end if;
    if tg_op <> 'DELETE' then v_new_program := new.program_id; end if;
  else
    if tg_op <> 'INSERT' then
      select program_id into v_old_program from public.program_assessment_tests
      where id = old.test_id;
    end if;
    if tg_op <> 'DELETE' then
      select program_id into v_new_program from public.program_assessment_tests
      where id = new.test_id;
    end if;
  end if;
  for v_program in select distinct x from unnest(
      array[v_old_program,v_new_program]) as x where x is not null loop
    select enabled into v_enabled from public.preparation_programs
      where id = v_program for share;
    if v_enabled then
      raise exception 'El baremo publicado es inmutable; crea una nueva versión.'
        using errcode = '22023';
    end if;
  end loop;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger guard_published_assessment_rule
before insert or update or delete on public.program_assessment_scoring_rules
for each row execute function public.guard_published_program_assessment_content();
create trigger guard_published_assessment_test
before insert or update or delete on public.program_assessment_tests
for each row execute function public.guard_published_program_assessment_content();
create trigger guard_published_assessment_band
before insert or update or delete on public.program_assessment_score_bands
for each row execute function public.guard_published_program_assessment_content();
create trigger guard_published_assessment_standard
before insert or update or delete on public.program_assessment_pass_standards
for each row execute function public.guard_published_program_assessment_content();

create function public.admin_program_assessment_issues_v2(p_program_id text)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_issues jsonb;
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_test public.program_assessment_tests%rowtype;
  v_category text;
  v_age integer;
  v_max numeric;
begin
  v_issues := public.admin_program_assessment_issues(p_program_id);
  select * into v_rule from public.program_assessment_scoring_rules
    where program_id = p_program_id;
  if not found or v_rule.scoring_mode <> 'points' then return v_issues; end if;
  for v_test in select * from public.program_assessment_tests
      where program_id = p_program_id loop
    foreach v_category in array array['men','women'] loop
      if v_test.category not in ('both',v_category) then continue; end if;
      for v_age in v_test.min_age..v_test.max_age loop
        select max(points) into v_max from public.program_assessment_score_bands
          where test_id = v_test.id and category = v_category
            and v_age between min_age and max_age;
        if v_max is not null and v_max < v_rule.min_each_points then
          v_issues := v_issues || jsonb_build_array(
            format('%s · %s · %s años: ningún tramo alcanza el mínimo de puntos.',
              v_test.name,v_category,v_age));
        end if;
        if jsonb_array_length(v_issues) >= 30 then return v_issues; end if;
      end loop;
    end loop;
  end loop;
  return v_issues;
end;
$$;

create or replace function public.publish_admin_program_assessment(p_program_id text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_issues jsonb;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede publicar programas.' using errcode = '42501';
  end if;
  perform 1 from public.preparation_programs where id = p_program_id
    and not enabled for update;
  if not found then
    raise exception 'Borrador no disponible.' using errcode = '22023';
  end if;
  v_issues := public.admin_program_assessment_issues_v2(p_program_id);
  if jsonb_array_length(v_issues) > 0 then
    raise exception 'Baremo incompleto: %', v_issues->>0 using errcode = '22023';
  end if;
  update public.preparation_programs set enabled = true
  where id = p_program_id;
end;
$$;

revoke all on function public.admin_program_assessment_issues_v2(text)
from public, anon;
grant execute on function public.admin_program_assessment_issues_v2(text)
to authenticated;

commit;
