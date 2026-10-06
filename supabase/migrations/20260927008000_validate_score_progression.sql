-- La tabla publicada debe poder alcanzar su máximo y premiar la marca mejor.
begin;

create function public.admin_program_assessment_issues_v3(p_program_id text)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_issues jsonb;
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_test public.program_assessment_tests%rowtype;
  v_band public.program_assessment_score_bands%rowtype;
  v_category text;
  v_age integer;
  v_max numeric;
  v_previous numeric;
begin
  v_issues := public.admin_program_assessment_issues_v2(p_program_id);
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
        if v_max is not null and v_max <> v_rule.max_points then
          v_issues := v_issues || jsonb_build_array(format(
            '%s · %s · %s años: la tabla no alcanza el máximo configurado.',
            v_test.name,v_category,v_age));
        end if;
        v_previous := null;
        for v_band in select * from public.program_assessment_score_bands
            where test_id = v_test.id and category = v_category
              and v_age between min_age and max_age
            order by min_mark nulls first loop
          if v_previous is not null and (
              v_test.better_direction = 'higher' and v_band.points < v_previous or
              v_test.better_direction = 'lower' and v_band.points > v_previous) then
            v_issues := v_issues || jsonb_build_array(format(
              '%s · %s · %s años: una marca peor obtiene más puntos.',
              v_test.name,v_category,v_age));
            exit;
          end if;
          v_previous := v_band.points;
        end loop;
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
  v_issues := public.admin_program_assessment_issues_v3(p_program_id);
  if jsonb_array_length(v_issues) > 0 then
    raise exception 'Baremo incompleto: %', v_issues->>0 using errcode = '22023';
  end if;
  update public.preparation_programs set enabled = true
    where id = p_program_id;
end;
$$;

revoke all on function public.admin_program_assessment_issues_v3(text)
from public,anon;
grant execute on function public.admin_program_assessment_issues_v3(text)
to authenticated;

commit;
