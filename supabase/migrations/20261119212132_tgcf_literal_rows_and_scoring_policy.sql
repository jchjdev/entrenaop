-- La regla de puntuación se versiona aparte de la tabla publicada.
-- Las filas de baremo, vínculos de preparación y snapshots existentes se conservan.
alter function builtin_assessment_private.preview_definition(jsonb,text,text,text,integer,text,jsonb)
  rename to preview_definition_v1;

create function builtin_assessment_private.fas_score_literal(
  p_rows jsonb, p_column integer, p_higher_is_better boolean, p_mark bigint
) returns integer language sql immutable security invoker set search_path='' as $$
  with rows as materialized (
    select (x->>0)::bigint as mark, (x->1->>p_column)::integer as points
    from jsonb_array_elements(p_rows) x
  ), bounds as (
    select (select points from rows where mark=p_mark) as exact_points,
           (select points from rows where mark<p_mark order by mark desc limit 1) as below_points,
           (select points from rows where mark>p_mark order by mark asc limit 1) as above_points
  )
  select case
    when exact_points is not null then exact_points
    when p_higher_is_better and below_points>above_points then null
    when not p_higher_is_better and above_points>below_points then null
    when p_higher_is_better then coalesce(below_points,0)
    else coalesce(above_points,0)
  end from bounds
$$;

create function builtin_assessment_private.preview_definition(
  p_definition jsonb,p_catalog_version text,p_scoring_version text,
  p_category text,p_age integer,p_milestone text,p_marks jsonb
) returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare
  preview jsonb; band text; item jsonb; t jsonb; idx integer; col integer;
  points integer; maximum_mark bigint; higher_is_better boolean;
  results jsonb:='[]'; indeterminate boolean:=false; meets_all boolean:=true;
begin
  -- Reutilizar la validación de batería, umbrales y normalización de la marca.
  preview:=builtin_assessment_private.preview_definition_v1(
    p_definition,p_catalog_version,p_scoring_version,p_category,p_age,p_milestone,p_marks);
  if p_definition->>'programId' is distinct from 'fas_periodic_assessment' then
    return preview;
  end if;
  select value->>'id' into band from jsonb_array_elements(p_definition->'ageBands')
  where p_age >= (value->>'minAge')::integer
    and (value->>'maxAge' is null or p_age <= (value->>'maxAge')::integer);
  for item in select value from jsonb_array_elements(preview->'results') loop
    select value into strict t from jsonb_array_elements(p_definition->'tests')
      where value->>'id'=item->>'test_id';
    select ordinality::integer-1 into strict idx from jsonb_array_elements_text(
      coalesce(t->'ageBands',(select jsonb_agg(b->'id' order by n)
      from jsonb_array_elements(p_definition->'ageBands') with ordinality a(b,n))))
      with ordinality where value=band;
    col:=case when (t->>'categoriesPerAgeBand')::boolean
      then idx*2+case when p_category='men' then 0 else 1 end else idx end;
    higher_is_better:=t->>'betterDirection'='higher';
    points:=builtin_assessment_private.fas_score_literal(
      t->'rows',col,higher_is_better,(item->>'scored_mark')::bigint);
    select (x->>0)::bigint into strict maximum_mark from jsonb_array_elements(t->'rows') x
      order by (x->1->>col)::integer desc,
        case when higher_is_better then (x->>0)::bigint end asc,
        case when not higher_is_better then (x->>0)::bigint end desc limit 1;
    indeterminate:=indeterminate or points is null;
    meets_all:=meets_all and coalesce(points >= (p_definition->>'minimumPointsPerTest')::integer,false);
    results:=results||jsonb_build_array(item||jsonb_build_object(
      'points',points,'meets_minimum',points >= (p_definition->>'minimumPointsPerTest')::integer,
      'maximum_mark',maximum_mark));
  end loop;
  return preview||jsonb_build_object('results',results,'scoring_policy','literal_rows_v2',
    'meets_all_minimums',case when indeterminate then null else meets_all end);
end $$;

-- La escritura usa exactamente el mismo cálculo que la vista previa.
create or replace function builtin_assessment_private.record_assessment(p_revision_id uuid,p_goal_id uuid,p_category text,p_age integer,
  p_milestone text,p_marks jsonb,p_completed_at timestamptz) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.builtin_assessment_revisions; g public.preparation_goals; result jsonb; assessment_id uuid; age_band text;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para guardar una evaluación.' using errcode='42501'; end if;
  select * into r from public.builtin_assessment_revisions where id=p_revision_id and status in ('published','withdrawn') for share;
  if not found then raise exception 'Baremo publicado no disponible.' using errcode='22023'; end if;
  if p_completed_at is null or p_completed_at>now()+interval '5 minutes' or p_completed_at<date '2026-01-21' then
    raise exception 'Fecha de evaluación no válida.' using errcode='22023'; end if;
  if p_goal_id is not null then
    select * into g from public.preparation_goals where id=p_goal_id and user_id=auth.uid() and program_id=r.program_id and status='active' for share;
    if not found then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
    if not exists(select 1 from public.builtin_assessment_goal_revisions where goal_id=g.id and revision_id=r.id) then
      raise exception 'El baremo cambió. Vuelve a abrir la evaluación de tu preparación.' using errcode='22023'; end if;
    if r.program_id='armed_forces_troop_entry' and p_milestone is distinct from 'entry' then
      raise exception 'La preparación de ingreso utiliza su propio hito.' using errcode='22023'; end if;
  elsif r.status<>'published' or r.id is distinct from builtin_assessment_private.current_revision(r.program_id) then
    raise exception 'La calculadora tiene otra versión publicada. Recarga antes de guardar.'
      using errcode='22023',detail='builtin_reference_changed';
  end if;
  result:=builtin_assessment_private.preview_definition(r.definition,r.catalog_version,r.scoring_version,p_category,p_age,p_milestone,p_marks)
    ||jsonb_build_object('revision_id',r.id);
  if r.program_id='fas_periodic_assessment' then
    if result->>'meets_all_minimums' is null then
      raise exception 'La evaluación contiene una marca con puntuación indeterminada.'
        using errcode='22023',detail='fas_score_indeterminate';
    end if;
    select value->>'id' into age_band from jsonb_array_elements(r.definition->'ageBands') where
      p_age>=(value->>'minAge')::integer and (value->>'maxAge' is null or p_age<=(value->>'maxAge')::integer);
    insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,scoring_version,category,
      age_at_assessment,age_band,completed_at,is_pre_effective_reference,result_snapshot)
    values(auth.uid(),p_goal_id,r.catalog_version,r.scoring_version,p_category,p_age,age_band,p_completed_at,
      (p_completed_at at time zone 'Europe/Madrid')::date < (r.definition->>'effectiveFrom')::date,result)
    returning id into assessment_id;
    insert into public.fas_periodic_marks(assessment_id,test_id,value)
      select assessment_id,x->>'test_id',(x->>'value')::bigint from jsonb_array_elements(p_marks) x;
  else
    insert into public.physical_assessments(user_id,preparation_goal_id,catalog_version,category,milestone,completed_at)
      values(auth.uid(),p_goal_id,r.catalog_version,p_category,p_milestone,p_completed_at) returning id into assessment_id;
    insert into public.physical_assessment_marks(assessment_id,test_id,value)
      select assessment_id,x->>'test_id',(x->>'value')::bigint from jsonb_array_elements(p_marks) x;
  end if;
  return assessment_id;
end $$;

create function builtin_assessment_private.require_equivalent_fas_score(
  p_revision_id uuid,p_category text,p_age integer,p_milestone text,p_marks jsonb
) returns void language plpgsql stable security invoker set search_path='' as $$
declare r public.builtin_assessment_revisions; old_results jsonb; new_results jsonb;
begin
  select * into r from public.builtin_assessment_revisions
    where id=p_revision_id and program_id='fas_periodic_assessment' and status in ('published','withdrawn');
  if not found then return; end if;
  old_results:=builtin_assessment_private.preview_definition_v1(
    r.definition,r.catalog_version,r.scoring_version,p_category,p_age,p_milestone,p_marks)->'results';
  new_results:=builtin_assessment_private.preview_definition(
    r.definition,r.catalog_version,r.scoring_version,p_category,p_age,p_milestone,p_marks)->'results';
  if exists(select 1 from jsonb_array_elements(old_results) o
    join jsonb_array_elements(new_results) n on o->>'test_id'=n->>'test_id'
    where o->'points' is distinct from n->'points') then
    raise exception 'Actualiza EntrenaOP para guardar puntuaciones con la regla vigente.'
      using errcode='22023',detail='fas_scoring_policy_changed';
  end if;
end $$;

-- Los clientes antiguos conservan las operaciones que producen el mismo resultado.
create function builtin_assessment_private.record_compatible_assessment(
  p_revision_id uuid,p_goal_id uuid,p_category text,p_age integer,
  p_milestone text,p_marks jsonb,p_completed_at timestamptz
) returns uuid language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  perform builtin_assessment_private.require_equivalent_fas_score(p_revision_id,p_category,p_age,p_milestone,p_marks);
  return builtin_assessment_private.record_assessment(p_revision_id,p_goal_id,p_category,p_age,p_milestone,p_marks,p_completed_at);
end $$;

create or replace function public.record_builtin_assessment(p_revision_id uuid,p_goal_id uuid,p_category text,p_age integer,
  p_milestone text,p_marks jsonb,p_completed_at timestamptz default now()) returns uuid
language sql security invoker set search_path='' as $$
  select builtin_assessment_private.record_compatible_assessment(p_revision_id,p_goal_id,p_category,p_age,p_milestone,p_marks,p_completed_at)
$$;

create function public.record_builtin_assessment(p_revision_id uuid,p_goal_id uuid,p_category text,p_age integer,
  p_milestone text,p_marks jsonb,p_completed_at timestamptz,p_fas_scoring_policy text) returns uuid
language plpgsql security invoker set search_path='' as $$
begin
  if p_fas_scoring_policy is distinct from 'literal_rows_v2' then
    raise exception 'La regla TGCF del cliente no está disponible.' using errcode='22023',detail='fas_scoring_policy_changed';
  end if;
  return builtin_assessment_private.record_assessment(p_revision_id,p_goal_id,p_category,p_age,p_milestone,p_marks,p_completed_at);
end $$;

create or replace function builtin_assessment_private.record_legacy_fas(p_preparation_goal_id uuid,p_category text,p_age integer,p_marks jsonb,p_completed_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$
declare seed_id uuid;
begin
  perform builtin_assessment_private.require_legacy('fas_periodic_assessment',p_preparation_goal_id);
  select id into seed_id from public.builtin_assessment_revisions
    where program_id='fas_periodic_assessment' and revision=1;
  perform builtin_assessment_private.require_equivalent_fas_score(seed_id,p_category,p_age,null,p_marks);
  return builtin_assessment_private.record_fas_periodic_assessment(p_preparation_goal_id,p_category,p_age,p_marks,p_completed_at);
end $$;

revoke all on function builtin_assessment_private.preview_definition(jsonb,text,text,text,integer,text,jsonb),
  builtin_assessment_private.fas_score_literal(jsonb,integer,boolean,bigint),
  builtin_assessment_private.require_equivalent_fas_score(uuid,text,integer,text,jsonb),
  builtin_assessment_private.record_compatible_assessment(uuid,uuid,text,integer,text,jsonb,timestamptz),
  public.record_builtin_assessment(uuid,uuid,text,integer,text,jsonb,timestamptz,text) from public,anon,authenticated;
grant execute on function builtin_assessment_private.record_compatible_assessment(uuid,uuid,text,integer,text,jsonb,timestamptz),
  public.record_builtin_assessment(uuid,uuid,text,integer,text,jsonb,timestamptz,text) to authenticated;
notify pgrst,'reload schema';
