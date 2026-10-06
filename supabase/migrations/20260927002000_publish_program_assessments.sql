-- Publicación solo con cobertura completa y registro inmutable por preparación.
begin;

alter table public.program_assessment_scoring_rules
  add column age_reference_on date,
  add constraint program_scoring_reference_date_check
    check (age_reference <> 'reference_date' or age_reference_on is not null);

create function public.save_admin_program_scoring_rule_v3(
  p_program_id text, p_scoring_version text, p_source_url text,
  p_source_label text, p_scoring_mode text, p_aggregation text,
  p_max_points numeric, p_min_each_points numeric,
  p_min_aggregate_points numeric, p_age_reference text,
  p_age_reference_on date, p_stage_label text,
  p_effective_on date, p_expires_on date
) returns void language plpgsql security definer set search_path = ''
as $$
begin
  if p_age_reference = 'reference_date' and p_age_reference_on is null then
    raise exception 'Indica la fecha oficial de corte para calcular la edad.'
      using errcode = '22023';
  end if;
  perform public.save_admin_program_scoring_rule_v2(
    p_program_id,p_scoring_version,p_source_url,p_source_label,
    p_scoring_mode,p_aggregation,p_max_points,p_min_each_points,
    p_min_aggregate_points,
    case when p_age_reference = 'reference_date' then 'assessment_date'
      else p_age_reference end,p_stage_label,
    p_effective_on,p_expires_on);
  update public.program_assessment_scoring_rules set
    age_reference = p_age_reference,
    age_reference_on = case when p_age_reference = 'reference_date'
      then p_age_reference_on else null end
  where program_id = p_program_id;
end;
$$;

create function public.admin_program_assessment_issues(p_program_id text)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_test public.program_assessment_tests%rowtype;
  v_category text;
  v_age integer;
  v_count integer;
  v_band public.program_assessment_score_bands%rowtype;
  v_first boolean;
  v_last_max numeric;
  v_issues jsonb := '[]'::jsonb;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede revisar programas.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.preparation_programs
      where id = p_program_id and not enabled) then
    raise exception 'El borrador no existe.' using errcode = '22023';
  end if;
  select * into v_rule from public.program_assessment_scoring_rules
  where program_id = p_program_id;
  if not found then
    return jsonb_build_array('Falta la regla de evaluación.');
  end if;
  if not exists (select 1 from public.program_assessment_tests
      where program_id = p_program_id) then
    return jsonb_build_array('Añade al menos una prueba.');
  end if;
  if v_rule.age_reference = 'reference_date' and v_rule.age_reference_on is null then
    v_issues := v_issues || jsonb_build_array(
      'La edad en fecha oficial requiere configurar una fecha de corte fija.');
  end if;
  for v_test in select * from public.program_assessment_tests
      where program_id = p_program_id order by display_order loop
    foreach v_category in array array['men','women'] loop
      if v_test.category not in ('both', v_category) then continue; end if;
      for v_age in v_test.min_age..v_test.max_age loop
        if v_rule.scoring_mode = 'pass_fail' then
          select count(*) into v_count
          from public.program_assessment_pass_standards s
          where s.test_id = v_test.id and s.category = v_category
            and v_age between s.min_age and s.max_age;
          if v_count <> 1 then
            v_issues := v_issues || jsonb_build_array(
              format('%s · %s · %s años: falta un mínimo único.',
                v_test.name, v_category, v_age));
          end if;
        else
          v_first := true;
          v_last_max := null;
          v_count := 0;
          for v_band in select b.* from public.program_assessment_score_bands b
              where b.test_id = v_test.id and b.category = v_category
                and v_age between b.min_age and b.max_age
              order by b.min_mark nulls first, b.max_mark nulls last loop
            v_count := v_count + 1;
            if v_first then
              if v_band.min_mark is not null and v_band.min_mark > 0 then
                v_issues := v_issues || jsonb_build_array(
                  format('%s · %s · %s años: faltan marcas bajas.',
                    v_test.name, v_category, v_age));
              end if;
              v_first := false;
            elsif v_last_max is null or v_band.min_mark is null or
                v_band.min_mark <> v_last_max + v_test.mark_step then
              v_issues := v_issues || jsonb_build_array(
                format('%s · %s · %s años: hay un hueco o solape de marcas.',
                  v_test.name, v_category, v_age));
            end if;
            v_last_max := v_band.max_mark;
          end loop;
          if v_count = 0 or v_last_max is not null then
            v_issues := v_issues || jsonb_build_array(
              format('%s · %s · %s años: el baremo no cubre todas las marcas.',
                v_test.name, v_category, v_age));
          end if;
        end if;
        if jsonb_array_length(v_issues) >= 30 then return v_issues; end if;
      end loop;
    end loop;
  end loop;
  return v_issues;
end;
$$;

create function public.publish_admin_program_assessment(p_program_id text)
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
  v_issues := public.admin_program_assessment_issues(p_program_id);
  if jsonb_array_length(v_issues) > 0 then
    raise exception 'Baremo incompleto: %', v_issues->>0 using errcode = '22023';
  end if;
  update public.preparation_programs set enabled = true
  where id = p_program_id;
end;
$$;

create table public.program_assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  preparation_goal_id uuid not null references public.preparation_goals(id)
    on delete restrict,
  program_id text not null references public.preparation_programs(id)
    on delete restrict,
  scoring_version text not null,
  category text not null check (category in ('men','women')),
  birth_date date not null,
  assessed_on date not null,
  reference_on date,
  marks jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);
create index program_assessment_attempts_goal_date_idx
on public.program_assessment_attempts(preparation_goal_id, assessed_on desc, created_at desc);

alter table public.program_assessment_attempts enable row level security;
revoke all on public.program_assessment_attempts from public, anon, authenticated;
grant select on public.program_assessment_attempts to authenticated;
create policy program_assessment_attempts_read_own
on public.program_assessment_attempts for select to authenticated
using (user_id = (select auth.uid()));

create function public.save_program_assessment_attempt(
  p_goal_id uuid, p_category text, p_birth_date date,
  p_assessed_on date, p_marks jsonb
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_goal public.preparation_goals%rowtype;
  v_result jsonb;
  v_profile_birth date;
  v_reference_on date;
  v_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Inicia sesión para registrar tus marcas.' using errcode = '42501';
  end if;
  select * into v_goal from public.preparation_goals
    where id = p_goal_id and user_id = (select auth.uid())
      and status = 'active';
  if not found then
    raise exception 'Preparación activa no disponible.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.preparation_programs
      where id = v_goal.program_id and enabled) then
    raise exception 'Programa no publicado.' using errcode = '22023';
  end if;
  select fecha_nacimiento into v_profile_birth from public.profiles
    where id = (select auth.uid());
  if v_profile_birth is null or v_profile_birth <> p_birth_date then
    raise exception 'Confirma primero tu fecha de nacimiento en el perfil.'
      using errcode = '22023';
  end if;
  if p_assessed_on is null or p_assessed_on > current_date then
    raise exception 'Fecha de prueba inválida.' using errcode = '22023';
  end if;
  select age_reference_on into v_reference_on
  from public.program_assessment_scoring_rules
  where program_id = v_goal.program_id;
  v_result := public.preview_program_assessment_attempt_v2(
    v_goal.program_id,p_category,p_birth_date,p_assessed_on,v_reference_on,p_marks);
  insert into public.program_assessment_attempts
    (user_id,preparation_goal_id,program_id,scoring_version,category,
     birth_date,assessed_on,reference_on,marks,result)
  values ((select auth.uid()),p_goal_id,v_goal.program_id,
    v_result->>'scoring_version',p_category,p_birth_date,p_assessed_on,v_reference_on,
    p_marks,v_result)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.admin_program_assessment_issues(text) from public, anon;
revoke all on function public.save_admin_program_scoring_rule_v3(
  text,text,text,text,text,text,numeric,numeric,numeric,text,date,text,date,date)
from public, anon;
grant execute on function public.save_admin_program_scoring_rule_v3(
  text,text,text,text,text,text,numeric,numeric,numeric,text,date,text,date,date)
to authenticated;
grant execute on function public.admin_program_assessment_issues(text) to authenticated;
revoke all on function public.publish_admin_program_assessment(text) from public, anon;
grant execute on function public.publish_admin_program_assessment(text) to authenticated;
revoke all on function public.save_program_assessment_attempt(uuid,text,date,date,jsonb)
from public, anon;
grant execute on function public.save_program_assessment_attempt(uuid,text,date,date,jsonb)
to authenticated;

commit;
